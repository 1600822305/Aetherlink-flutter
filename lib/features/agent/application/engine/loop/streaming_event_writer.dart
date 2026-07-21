import 'dart:async';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 流式增量的合并限流落库（L6 原位 upsert 之上的写入节流）。
///
/// LLM 每个 SSE 增量都会回调一次；逐条 upsert 会让写库频率跟着网络包走
/// （每秒几十次），而每次写库都触发 UI watch 对整条事件流的全量重解码——
/// 长任务（几十轮、几百 KB 工具输出）下 UI isolate 被解码洪流打满，
/// 表现为整页冻结甚至 ANR。这里按 latest-wins 合并：增量只更新内存态，
/// 每 [_kMinWriteInterval] 至多落库一次，收尾时 [finish] 强制写终值。
class StreamingEventWriter {
  StreamingEventWriter(this._store, this._taskId);

  static const Duration _kMinWriteInterval = Duration(milliseconds: 200);

  final AgentEventStore _store;
  final String _taskId;

  AssistantTextEvent? _textEvent;
  ReasoningEvent? _reasoningEvent;
  DateTime? _reasoningStart;

  String _text = '';
  String _reasoning = '';
  bool _textDirty = false;
  bool _reasoningDirty = false;

  bool _writing = false;
  bool _finished = false;
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _timer;
  Future<void> _drainFuture = Future<void>.value();

  void onReasoningDelta(String reasoningSoFar) {
    _reasoningStart ??= DateTime.now();
    _reasoning = reasoningSoFar;
    _reasoningDirty = true;
    _schedule();
  }

  void onTextDelta(String textSoFar) {
    _text = textSoFar;
    _textDirty = true;
    _schedule();
  }

  /// 收尾：停掉节流定时器，等在途写入结束，把思考定格、正文以终值
  /// （非流式）落库。[finalText] 为空时以最后一次增量的全文为准。
  Future<void> finish(String finalText) async {
    _finished = true;
    _timer?.cancel();
    _timer = null;
    await _drainFuture;
    if (_reasoningEvent != null && _reasoningEvent!.streaming) {
      _reasoningEvent = await _store.updateReasoning(
        _taskId, _reasoningEvent!, _reasoningEvent!.text,
        streaming: false,
        elapsed: _reasoningElapsed(),
      );
    }
    final text = finalText.isEmpty ? _text : finalText;
    if (_textEvent != null || text.isNotEmpty) {
      _textEvent = _textEvent == null
          ? await _store.appendAssistantText(_taskId, text, streaming: false)
          : await _store.updateAssistantText(_taskId, _textEvent!, text,
              streaming: false);
    }
  }

  Duration? _reasoningElapsed() => _reasoningStart == null
      ? null
      : DateTime.now().difference(_reasoningStart!);

  void _schedule() {
    if (_writing || _finished || _timer != null) return;
    final wait = _kMinWriteInterval - DateTime.now().difference(_lastWrite);
    if (wait <= Duration.zero) {
      _drainFuture = _drain();
    } else {
      _timer = Timer(wait, () {
        _timer = null;
        if (!_writing && !_finished) _drainFuture = _drain();
      });
    }
  }

  Future<void> _drain() async {
    _writing = true;
    try {
      if (_reasoningDirty) {
        _reasoningDirty = false;
        final reasoning = _reasoning;
        _reasoningEvent = _reasoningEvent == null
            ? await _store.appendReasoning(_taskId, reasoning,
                streaming: true)
            : await _store.updateReasoning(
                _taskId, _reasoningEvent!, reasoning,
                streaming: true);
      }
      if (_textDirty) {
        _textDirty = false;
        // 文本开始 → 思考定格（收起为"思考了 Xs"）。
        if (_reasoningEvent != null && _reasoningEvent!.streaming) {
          _reasoningEvent = await _store.updateReasoning(
            _taskId, _reasoningEvent!, _reasoningEvent!.text,
            streaming: false,
            elapsed: _reasoningElapsed(),
          );
        }
        final text = _text;
        _textEvent = _textEvent == null
            ? await _store.appendAssistantText(_taskId, text, streaming: true)
            : await _store.updateAssistantText(_taskId, _textEvent!, text,
                streaming: true);
      }
    } finally {
      _lastWrite = DateTime.now();
      _writing = false;
    }
    if (!_finished && (_reasoningDirty || _textDirty)) _schedule();
  }
}
