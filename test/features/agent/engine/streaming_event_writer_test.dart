import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/loop/streaming_event_writer.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 只实现 writer/工具块用到的落库方法的内存仓：验证 seq 分配顺序
/// （事件流排序契约）与分段定稿内容。
class _SeqRecordingStore implements AgentEventStore {
  final List<AgentEvent> events = [];
  int _seq = 0;
  int _id = 0;

  List<AgentEvent> get ordered =>
      List.of(events)..sort((a, b) => a.seq.compareTo(b.seq));

  void _upsert(AgentEvent event) {
    final index = events.indexWhere((e) => e.id == event.id);
    if (index >= 0) {
      events[index] = event;
    } else {
      events.add(event);
    }
  }

  @override
  Future<AssistantTextEvent> appendAssistantText(
    String taskId,
    String text, {
    required bool streaming,
  }) async {
    final event = AssistantTextEvent(
      id: 'e-${_id++}',
      seq: ++_seq,
      at: DateTime.now(),
      text: text,
      streaming: streaming,
    );
    _upsert(event);
    return event;
  }

  @override
  Future<AssistantTextEvent> updateAssistantText(
    String taskId,
    AssistantTextEvent event,
    String text, {
    required bool streaming,
  }) async {
    final updated = AssistantTextEvent(
      id: event.id,
      seq: event.seq,
      at: event.at,
      text: text,
      streaming: streaming,
    );
    _upsert(updated);
    return updated;
  }

  @override
  Future<ReasoningEvent> appendReasoning(
    String taskId,
    String text, {
    required bool streaming,
  }) async {
    final event = ReasoningEvent(
      id: 'e-${_id++}',
      seq: ++_seq,
      at: DateTime.now(),
      text: text,
      streaming: streaming,
    );
    _upsert(event);
    return event;
  }

  @override
  Future<ReasoningEvent> updateReasoning(
    String taskId,
    ReasoningEvent event,
    String text, {
    required bool streaming,
    Duration? elapsed,
  }) async {
    final updated = ReasoningEvent(
      id: event.id,
      seq: event.seq,
      at: event.at,
      text: text,
      streaming: streaming,
      elapsed: elapsed ?? event.elapsed,
    );
    _upsert(updated);
    return updated;
  }

  @override
  Future<ToolCallEvent> appendToolCall(
    String taskId,
    AgentToolCallRequest call,
    AgentToolCallState state,
  ) async {
    final event = ToolCallEvent(
      id: 'e-${_id++}',
      seq: ++_seq,
      at: DateTime.now(),
      toolName: call.name,
      argSummary: call.argSummary,
      state: state,
      argsDetail: call.argsJson,
    );
    _upsert(event);
    return event;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  const taskId = 't1';

  AgentToolCallRequest call(String name) => AgentToolCallRequest(
        id: name,
        name: name,
        argsJson: '{}',
        argSummary: name,
      );

  test('首个正文增量立即建事件：seal 后落的工具块排在正文之后', () async {
    final store = _SeqRecordingStore();
    final writer = StreamingEventWriter(store, taskId);

    writer.onTextDelta('我先看看这个文件。');
    // 模拟引擎在工具块建事件前 seal 当前段。
    await writer.sealSegments();
    await store.appendToolCall(
      taskId, call('read_file'), AgentToolCallState.running);
    await writer.finish('我先看看这个文件。');

    final ordered = store.ordered;
    expect(ordered, hasLength(2));
    expect(ordered[0], isA<AssistantTextEvent>());
    expect((ordered[0] as AssistantTextEvent).text, '我先看看这个文件。');
    expect((ordered[0] as AssistantTextEvent).streaming, isFalse);
    expect(ordered[1], isA<ToolCallEvent>());
  });

  test('节流窗口内的正文也不会被工具块抢先（回归：200ms 竞态）', () async {
    final store = _SeqRecordingStore();
    final writer = StreamingEventWriter(store, taskId);

    // 先有思考增量（触发一次落库，推进节流时钟）。
    writer.onReasoningDelta('想一想。');
    await writer.sealSegments();
    // 紧接着正文首增量 + 工具块（同一节流窗口内）。
    writer.onTextDelta('好的，开始。');
    await writer.sealSegments();
    await store.appendToolCall(
      taskId, call('terminal_execute'), AgentToolCallState.running);
    await writer.finish('好的，开始。');

    final kinds = [for (final e in store.ordered) e.runtimeType.toString()];
    expect(kinds, ['ReasoningEvent', 'AssistantTextEvent', 'ToolCallEvent']);
  });

  test('工具块前后的正文分成两段事件，保持交错顺序', () async {
    final store = _SeqRecordingStore();
    final writer = StreamingEventWriter(store, taskId);

    writer.onTextDelta('第一段。');
    await writer.sealSegments();
    await store.appendToolCall(
      taskId, call('read_file'), AgentToolCallState.running);
    // 回调给的是整轮累计全文。
    writer.onTextDelta('第一段。第二段。');
    await writer.finish('第一段。第二段。');

    final ordered = store.ordered;
    expect(ordered, hasLength(3));
    expect((ordered[0] as AssistantTextEvent).text, '第一段。');
    expect(ordered[1], isA<ToolCallEvent>());
    expect((ordered[2] as AssistantTextEvent).text, '第二段。');
    expect((ordered[2] as AssistantTextEvent).streaming, isFalse);
  });

  test('正文开始时思考段定格（elapsed 落库、streaming=false）', () async {
    final store = _SeqRecordingStore();
    final writer = StreamingEventWriter(store, taskId);

    writer.onReasoningDelta('先分析问题');
    writer.onTextDelta('结论如下。');
    await writer.finish('结论如下。');

    final ordered = store.ordered;
    expect(ordered, hasLength(2));
    final reasoning = ordered[0] as ReasoningEvent;
    expect(reasoning.streaming, isFalse);
    expect(reasoning.elapsed, isNotNull);
    expect(reasoning.text, '先分析问题');
    final text = ordered[1] as AssistantTextEvent;
    expect(text.text, '结论如下。');
  });

  test('非流式路径：没有增量时 finish 以终值补落正文', () async {
    final store = _SeqRecordingStore();
    final writer = StreamingEventWriter(store, taskId);

    await writer.finish('完整回复。');

    final ordered = store.ordered;
    expect(ordered, hasLength(1));
    final text = ordered[0] as AssistantTextEvent;
    expect(text.text, '完整回复。');
    expect(text.streaming, isFalse);
  });

  test('空段 seal 是 no-op，不产生空事件', () async {
    final store = _SeqRecordingStore();
    final writer = StreamingEventWriter(store, taskId);

    await writer.sealSegments();
    await writer.finish('');

    expect(store.events, isEmpty);
  });
}
