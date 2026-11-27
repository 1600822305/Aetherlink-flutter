import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/error/failure.dart';
import 'package:aetherlink_flutter/shared/services/llm_auto_retry.dart';

DioException _dio(DioExceptionType type, {int? status, String? message}) =>
    DioException(
      requestOptions: RequestOptions(path: '/v1/chat/completions'),
      type: type,
      message: message,
      response: status == null
          ? null
          : Response(
              requestOptions: RequestOptions(path: '/'),
              statusCode: status,
            ),
    );

void main() {
  group('shouldRetryLlmError', () {
    test('传输层失败重试（截图里的 Network error: null / receive timeout）', () {
      expect(
        shouldRetryLlmError(
          const NetworkFailure(
            'Network error calling https://rapidapi.cc/v1/chat/completions: null',
          ),
        ),
        isTrue,
      );
      expect(shouldRetryLlmError(_dio(DioExceptionType.receiveTimeout)), isTrue);
      expect(shouldRetryLlmError(_dio(DioExceptionType.connectionError)), isTrue);
      expect(shouldRetryLlmError(const SocketException('reset')), isTrue);
      expect(shouldRetryLlmError(TimeoutException('t')), isTrue);
    });

    test('可重试状态码重试，其余 4xx 不重试', () {
      for (final s in [429, 500, 502, 503, 504, 529]) {
        expect(
          shouldRetryLlmError(NetworkFailure('HTTP $s', statusCode: s)),
          isTrue,
          reason: '$s',
        );
      }
      expect(
        shouldRetryLlmError(const NetworkFailure('HTTP 400', statusCode: 400)),
        isFalse,
      );
      expect(
        shouldRetryLlmError(_dio(DioExceptionType.badResponse, status: 404)),
        isFalse,
      );
    });

    test('余额 / Key 无效等错误不重试（即便状态码可重试）', () {
      expect(
        shouldRetryLlmError(
          const NetworkFailure('HTTP 429 — 余额不足', statusCode: 429),
        ),
        isFalse,
      );
      expect(
        shouldRetryLlmError(
          const NetworkFailure('HTTP 401 — invalid api key', statusCode: 401),
        ),
        isFalse,
      );
    });

    test('繁忙 / 限流关键词重试；用户取消不重试', () {
      expect(shouldRetryLlmError(Exception('服务繁忙，请稍后')), isTrue);
      expect(shouldRetryLlmError(_dio(DioExceptionType.cancel)), isFalse);
      expect(
        shouldRetryLlmError(
          const NetworkFailure('Request to https://x was cancelled'),
        ),
        isFalse,
      );
    });
  });

  test('llmRetryDelay：1s → 2s → 4s（±20%），封顶 30s', () {
    final r = Random(1);
    for (final (i, base) in [(0, 1000), (1, 2000), (2, 4000)]) {
      final ms = llmRetryDelay(i, random: r).inMilliseconds;
      expect(ms, inInclusiveRange(base * 0.8, base * 1.2), reason: '$i');
    }
    expect(llmRetryDelay(20, random: r).inMilliseconds, lessThanOrEqualTo(30000));
  });

  test('llmRetryWait：取消时立即返回', () async {
    final cancel = Completer<void>();
    final sw = Stopwatch()..start();
    final wait = llmRetryWait(
      const Duration(seconds: 10),
      cancelled: cancel.future,
    );
    cancel.complete();
    await wait;
    expect(sw.elapsed, lessThan(const Duration(seconds: 1)));
  });
  test('llmRetryStatusProvider：begin 记第几次与重试时刻，clear 清除', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(llmRetryStatusProvider.notifier);
    final before = DateTime.now();
    n.begin(agentLlmRetryKey('t1'), 0, const Duration(seconds: 2), Exception('boom'));
    final s = c.read(llmRetryStatusProvider)['agent:t1']!;
    expect(s.attempt, 1);
    expect(s.maxRetries, kLlmMaxRetries);
    expect(s.retryAt.isAfter(before.add(const Duration(milliseconds: 1500))), isTrue);
    expect(s.error, contains('boom'));
    n.clear('agent:t1');
    expect(c.read(llmRetryStatusProvider), isEmpty);
    n.clear('agent:t1'); // 幂等
  });
}
