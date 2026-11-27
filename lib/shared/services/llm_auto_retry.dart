// 模型请求自动重试（对齐 kelivo `retry_policy.dart` / `retrying_stream.dart`）。
//
// 规则：
// · 只在**还没收到任何数据**时重试（已流出内容再重发会重复输出 / 重复
//   执行工具），已收到数据后的错误原样抛出；
// · 网络层错误（连接断开 / 重置 / 超时 / 无状态码的传输失败）重试；
// · HTTP 408 / 425 / 429 / 500 / 502 / 503 / 504 / 529 重试；
// · 错误文本含「繁忙 / 限流 / 稍后 / rate limit / overloaded…」重试；
// · 含「余额 / 额度 / 欠费 / invalid api key / unauthorized…」绝不重试；
// · 指数退避 1s → 2s → 4s（±20% 抖动，封顶 30s），最多重试 3 次。

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/core/error/failure.dart';

/// 首次请求之后最多再重试的次数（3 = 总共 4 次）。
const int kLlmMaxRetries = 3;

const int _kInitialDelayMs = 1000;
const double _kMultiplier = 2;
const int _kMaxDelayMs = 30000;

const Set<int> kLlmRetryStatusCodes = {408, 425, 429, 500, 502, 503, 504, 529};

const List<String> _kRetryKeywords = [
  '并发',
  '稍后',
  '重试',
  '访问量过大',
  '繁忙',
  '限流',
  'rate limit',
  'too many requests',
  'overloaded',
  'try again',
  'timeout',
  'timed out',
  '超时',
];

const List<String> _kStopKeywords = [
  '余额',
  '不足',
  '额度',
  '欠费',
  'balance',
  'insufficient',
  'quota',
  'invalid api key',
  'unauthorized',
  'permission',
  '未实名',
];

bool _contains(String text, List<String> keywords) {
  final lower = text.toLowerCase();
  return keywords.any((k) => lower.contains(k.toLowerCase()));
}

/// 这个错误是否值得重试（调用方另需保证本次尚未收到任何数据）。
bool shouldRetryLlmError(Object error) {
  final text = error.toString();
  if (_contains(text, _kStopKeywords)) return false;
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return false;
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        return (status != null && kLlmRetryStatusCodes.contains(status)) ||
            _contains(text, _kRetryKeywords);
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return true;
    }
  }
  if (error is NetworkFailure) {
    final status = error.statusCode;
    if (status == null) {
      // 无状态码 = 传输层失败（断开 / 重置 / 超时 / DNS），被取消的除外。
      return !text.contains('was cancelled');
    }
    return kLlmRetryStatusCodes.contains(status) ||
        _contains(text, _kRetryKeywords);
  }
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is HandshakeException) {
    return true;
  }
  return _contains(text, _kRetryKeywords);
}

/// 第 [attemptIndex] 次重试前的等待（0 = 第一次重试）。
Duration llmRetryDelay(int attemptIndex, {Random? random}) {
  var ms =
      _kInitialDelayMs *
      (attemptIndex <= 0 ? 1.0 : pow(_kMultiplier, attemptIndex).toDouble());
  if (ms > _kMaxDelayMs) ms = _kMaxDelayMs.toDouble();
  ms *= 0.8 + (random ?? Random()).nextDouble() * 0.4; // ±20%
  if (ms > _kMaxDelayMs) ms = _kMaxDelayMs.toDouble();
  return Duration(milliseconds: ms.round());
}

/// 可被取消打断的等待：[cancelled] 完成时立即返回。
Future<void> llmRetryWait(Duration delay, {Future<void>? cancelled}) {
  if (delay <= Duration.zero) return Future.value();
  final timer = Future<void>.delayed(delay);
  return cancelled == null ? timer : Future.any([timer, cancelled]);
}

/// 一次进行中的重试等待（UI 显示「网络中断，N 秒后重试（1/3）」）。
class LlmRetryStatus {
  const LlmRetryStatus({
    required this.attempt,
    required this.maxRetries,
    required this.retryAt,
    required this.error,
  });

  /// 第几次重试（从 1 开始）。
  final int attempt;
  final int maxRetries;

  /// 预计重发时刻（绝对时间，倒计时据此算）。
  final DateTime retryAt;

  /// 触发重试的错误（简短原文）。
  final String error;
}

/// 重试状态登记：key → 状态。智能体用 `agent:<taskId>`，普通聊天用助手
/// 消息 id。重试开始等待时写入，重发出去（或放弃 / 取消）时清除。
class LlmRetryStatusNotifier extends Notifier<Map<String, LlmRetryStatus>> {
  @override
  Map<String, LlmRetryStatus> build() => const {};

  void begin(String key, int attemptIndex, Duration delay, Object error) {
    var text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > 120) text = '${text.substring(0, 120)}…';
    state = {
      ...state,
      key: LlmRetryStatus(
        attempt: attemptIndex + 1,
        maxRetries: kLlmMaxRetries,
        retryAt: DateTime.now().add(delay),
        error: text,
      ),
    };
  }

  void clear(String key) {
    if (!state.containsKey(key)) return;
    state = Map.of(state)..remove(key);
  }
}

final llmRetryStatusProvider =
    NotifierProvider<LlmRetryStatusNotifier, Map<String, LlmRetryStatus>>(
      LlmRetryStatusNotifier.new,
    );

/// 智能体任务的重试状态 key。
String agentLlmRetryKey(String taskId) => 'agent:$taskId';
