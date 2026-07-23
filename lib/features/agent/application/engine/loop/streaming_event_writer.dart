import 'dart:async';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 流式思考/正文的分段落库（L6 原位 upsert 之上的写入编排）。
///
/// 排序契约：事件流的顺序 = seq = 首次落库顺序，因此**首个增量必须
/// 立即建事件**（不等节流窗口），否则同轮内紧随其后的工具块会先拿到
/// seq，正文/思考被排到工具块后面。节流只作用于后续的原位 update
/// （latest-wins，防 SSE 增量逐条写库把 UI watch 打满）。
///
/// 分段：一轮内 text/reasoning 与工具调用可能交错（模型先说一句、
/// 调工具、再说一句）。[sealSegments] 在工具块建事件前把当前段定稿
/// 收尾；之后的增量另起新事件，保持与模型输出一致的交错顺序，
/// 而不是把整轮文本合并回首段位置。
class StreamingEventWriter {
  StreamingEventWriter(this._store, this._taskId);

  static const Duration _kMinWriteInterval = Duration(milliseconds: 200);

  final AgentEventStore _store;
  final String _taskId;

  AssistantTextEvent? _textEvent;
  ReasoningEvent? _reasoningEvent;
  DateTime? _reasoningStart;

  /// 回调给的是整轮累计全文；当前段内容 = 全文去掉已定稿段的前缀。
  String _text = '';
  String _reasoning = '';
  int _textOffset = 0;
  int _reasoningOffset = 0;
  bool _textDirty = false;
  bool _reasoningDirty = false;

  bool _finished = false;
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _timer;

  /// 全部落库操作的串行尾链：建段/更新/定稿按调用顺序执行，
  /// seq 分配顺序即事件顺序。
  Future<void> _chain = Future<void>.value();

  Future<void> _enqueue(Future<void> Function() op) {
    final next = _chain.then((_) => op());
    _chain = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  String _textSegment() =>
      _textOffset >= _text.length ? '' : _text.substring(_textOffset);

  String _reasoningSegment() => _reasoningOffset >= _reasoning.length
      ? ''
      : _reasoning.substring(_reasoningOffset);

  void onReasoningDelta(String reasoningSoFar) {
    if (_finished) return;
    _reasoningStart ??= DateTime.now();
    _reasoning = reasoningSoFar;
    _reasoningDirty = true;
    // 首个增量：立即建事件锁定 seq；后续增量走节流 update。
    if (_reasoningEvent == null) {
      _enqueue(_flush);
    } else {
      _schedule();
    }
  }

  void onTextDelta(String textSoFar) {
    if (_finished) return;
    _text = textSoFar;
    _textDirty = true;
    if (_textEvent == null) {
      _enqueue(_flush);
    } else {
      _schedule();
    }
  }

  /// 段收尾：当前思考/正文段定稿（streaming=false），之后的增量另起
  /// 新事件。工具块建事件前调用（await 返回后再落工具事件），保证
  /// 「正文 → 工具」的 seq 顺序与模型输出一致。空段是 no-op。
  Future<void> sealSegments() {
    if (_reasoningEvent == null &&
        _textEvent == null &&
        !_reasoningDirty &&
        !_textDirty) {
      return _chain;
    }
    return _enqueue(() async {
      await _flushDirty();
      await _sealReasoning();
      await _sealText();
    });
  }

  /// 收尾：停节流定时器，把思考定格、正文以终值（非流式）落库。
  /// [finalText] 为整轮全文；比累计增量长时以它为准补齐最后一段。
  Future<void> finish(String finalText) {
    _finished = true;
    _timer?.cancel();
    _timer = null;
    return _enqueue(() async {
      if (finalText.length > _text.length) {
        _text = finalText;
        _textDirty = true;
      }
      await _flushDirty();
      await _sealReasoning();
      await _sealText();
    });
  }

  Duration? _reasoningElapsed() => _reasoningStart == null
      ? null
      : DateTime.now().difference(_reasoningStart!);

  Future<void> _sealReasoning() async {
    final event = _reasoningEvent;
    if (event == null) return;
    final segment = _reasoningSegment();
    _reasoningEvent = null;
    _reasoningOffset = _reasoning.length;
    _reasoningDirty = false;
    final elapsed = _reasoningElapsed();
    _reasoningStart = null;
    await _store.updateReasoning(
      _taskId,
      event,
      segment.isEmpty ? event.text : segment,
      streaming: false,
      elapsed: elapsed,
    );
  }

  Future<void> _sealText() async {
    final event = _textEvent;
    if (event == null) return;
    final segment = _textSegment();
    _textEvent = null;
    _textOffset = _text.length;
    _textDirty = false;
    await _store.updateAssistantText(
      _taskId,
      event,
      segment.isEmpty ? event.text : segment,
      streaming: false,
    );
  }

  void _schedule() {
    if (_finished || _timer != null) return;
    final wait = _kMinWriteInterval - DateTime.now().difference(_lastWrite);
    if (wait <= Duration.zero) {
      _enqueue(_flush);
    } else {
      _timer = Timer(wait, () {
        _timer = null;
        if (!_finished) _enqueue(_flush);
      });
    }
  }

  Future<void> _flush() async {
    await _flushDirty();
    _lastWrite = DateTime.now();
  }

  Future<void> _flushDirty() async {
    if (_reasoningDirty) {
      _reasoningDirty = false;
      final segment = _reasoningSegment();
      if (segment.isNotEmpty || _reasoningEvent != null) {
        _reasoningEvent = _reasoningEvent == null
            ? await _store.appendReasoning(_taskId, segment, streaming: true)
            : await _store.updateReasoning(
                _taskId, _reasoningEvent!, segment,
                streaming: true);
      }
    }
    if (_textDirty) {
      _textDirty = false;
      // 正文开始 → 当前思考段定格（收起为"思考了 Xs"）。
      await _sealReasoning();
      final segment = _textSegment();
      if (segment.isNotEmpty || _textEvent != null) {
        _textEvent = _textEvent == null
            ? await _store.appendAssistantText(_taskId, segment,
                streaming: true)
            : await _store.updateAssistantText(_taskId, _textEvent!, segment,
                streaming: true);
      }
    }
  }
}
