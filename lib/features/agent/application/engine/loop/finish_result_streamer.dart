import 'dart:async';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_stream.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// attempt_completion 的流式渲染（对标 Roo completion_result partial）：
/// 控制工具不走 [TurnStreamBinder] 预建事件，这里在参数增量阶段就建一条
/// toolName = attempt_completion 的 [ToolCallEvent]（running），把半截参数
/// 原位写进 argsDetail；UI 按工具名渲染成「任务完成」卡片，从 argsDetail
/// 实时抠出 result 显示。引擎处理该调用时复用这条事件定稿（success /
/// failure），不再另落助手正文，避免与正文混在一起看起来像重复。
///
/// 传入 [live]（工具参数实时通道）时每个增量直接推内存，完成卡片从实时
/// 通道取 result 显示，落库降为 500ms 一次；不传时维持 50ms 落库。
class FinishResultStreamer {
  FinishResultStreamer(
    this._store,
    this._taskId,
    this._toolName, {
    AgentToolStreamSink? live,
  }) : _live = live;

  static const Duration _kMinWriteIntervalNoLive = Duration(milliseconds: 50);
  static const Duration _kMinWriteIntervalWithLive = Duration(
    milliseconds: 500,
  );

  final AgentEventStore _store;
  final String _taskId;
  final String _toolName;
  final AgentToolStreamSink? _live;

  Duration get _kMinWriteInterval =>
      _live == null ? _kMinWriteIntervalNoLive : _kMinWriteIntervalWithLive;

  void _pushLive(String key) {
    final event = _events[key];
    final args = _latestArgs[key];
    if (event == null || args == null) return;
    _live?.update(event.id, _toolName, args);
  }

  void _clearLive() {
    final live = _live;
    if (live == null) return;
    for (final e in _events.values) {
      live.clear(e.id);
    }
  }

  final Map<String, ToolCallEvent> _events = {};
  final Map<String, String> _latestArgs = {};
  final Map<String, DateTime> _lastWrite = {};
  Timer? _timer;

  Future<void> _chain = Future<void>.value();

  Future<void> _enqueue(Future<void> Function() op) {
    final next = _chain.then((_) => op());
    _chain = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  Future<void> onToolCallDelta(
    String streamKey,
    String? toolName,
    String argsTextSoFar,
  ) {
    if (toolName != _toolName) return Future.value();
    _latestArgs[streamKey] = argsTextSoFar;
    _pushLive(streamKey);
    if (!_events.containsKey(streamKey)) {
      // 首个增量立即建事件锁定 seq（与 StreamingEventWriter 同一契约）。
      return _enqueue(() async {
        if (_events.containsKey(streamKey)) return;
        await _create(streamKey);
      });
    }
    final last = _lastWrite[streamKey];
    if (last != null &&
        DateTime.now().difference(last) < _kMinWriteInterval) {
      _timer ??= Timer(_kMinWriteInterval, () {
        _timer = null;
        _enqueue(_flushAll);
      });
      return Future.value();
    }
    return _enqueue(() => _flush(streamKey));
  }

  /// 参数流完：写入完整参数（仍为 running，由引擎定稿）。
  Future<void> onToolCall(AgentToolCallRequest call, String? streamKey) {
    if (call.name != _toolName) return Future.value();
    final key = streamKey ??
        (_latestArgs.length == 1 ? _latestArgs.keys.first : null);
    if (key == null) return Future.value();
    _latestArgs[key] = call.argsJson;
    return _enqueue(() async {
      if (!_events.containsKey(key)) {
        await _create(key);
      } else {
        await _flush(key);
      }
    });
  }

  /// 本轮结束：落最后一次增量。仍 running 的卡片由引擎定稿；
  /// 本轮被中止时由 [abort] 回填中断。
  Future<void> finish() {
    _timer?.cancel();
    _timer = null;
    return _enqueue(() async {
      await _flushAll();
      // 最终参数已落库，卡片改从事件读取。
      _clearLive();
    });
  }

  /// 本轮中止（流中断/上下文超限/出错）：未定稿的卡片按中断回填。
  Future<void> abort() {
    _timer?.cancel();
    _timer = null;
    return _enqueue(() async {
      for (final key in _events.keys.toList()) {
        final event = _events[key]!;
        if (event.state != AgentToolCallState.running) continue;
        _events[key] = await _store.updateToolCall(
          _taskId,
          event,
          state: AgentToolCallState.failure,
          resultSummary: '已中断 ✗',
        );
      }
      _clearLive();
    });
  }

  Future<void> _create(String key) async {
    final args = _latestArgs[key] ?? '';
    final created = await _store.appendToolCall(
      _taskId,
      AgentToolCallRequest(
        id: key,
        name: _toolName,
        argsJson: args,
        argSummary: '提交完成结果',
      ),
      AgentToolCallState.running,
    );
    _events[key] = await _store.updateToolCall(
      _taskId,
      created,
      state: AgentToolCallState.running,
      argsDetail: args,
    );
    _lastWrite[key] = DateTime.now();
    _pushLive(key);
  }

  Future<void> _flushAll() async {
    for (final key in _events.keys.toList()) {
      await _flush(key);
    }
  }

  Future<void> _flush(String key) async {
    final event = _events[key];
    final args = _latestArgs[key];
    if (event == null || args == null) return;
    if (event.state != AgentToolCallState.running) return;
    if (event.argsDetail == args) return;
    _events[key] = await _store.updateToolCall(
      _taskId,
      event,
      state: AgentToolCallState.running,
      argsDetail: args,
    );
    _lastWrite[key] = DateTime.now();
  }
}

/// 从可能不完整的 JSON 文本里取某个字符串字段的当前值：
/// 字段还没出现返回 null；字符串未闭合时返回已流出的部分；
/// 末尾半截转义（如 `\` 或 `\u4f`）先丢弃，等后续增量补齐。
String? extractPartialStringField(String json, String field) {
  final key = RegExp('"${RegExp.escape(field)}"\\s*:\\s*"');
  final m = key.firstMatch(json);
  if (m == null) return null;
  final buf = StringBuffer();
  var i = m.end;
  while (i < json.length) {
    final c = json[i];
    if (c == '"') return buf.toString();
    if (c != r'\') {
      buf.write(c);
      i++;
      continue;
    }
    if (i + 1 >= json.length) break;
    final e = json[i + 1];
    switch (e) {
      case 'n':
        buf.write('\n');
      case 't':
        buf.write('\t');
      case 'r':
        buf.write('\r');
      case 'b':
        buf.write('\b');
      case 'f':
        buf.write('\f');
      case 'u':
        if (i + 6 > json.length) return buf.toString();
        final code = int.tryParse(json.substring(i + 2, i + 6), radix: 16);
        if (code == null) return buf.toString();
        buf.writeCharCode(code);
        i += 6;
        continue;
      default:
        buf.write(e);
    }
    i += 2;
  }
  return buf.toString();
}

/// 完成卡片 / 子代理结论读取 result 的统一入口。
String completionResultOf(ToolCallEvent event) =>
    extractPartialStringField(event.argsDetail ?? '', 'result')?.trim() ?? '';
