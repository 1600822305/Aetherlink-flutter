import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_manual_compaction.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

import 'agent_engine_test.dart' show InMemoryAgentEventStore;
import 'fakes/fake_agent_llm_client.dart';

/// 记录摘要调用收到的自定义指令（升级计划 ⑦）。
class _InstructionCapturingLlmClient extends FakeAgentLlmClient {
  _InstructionCapturingLlmClient();

  String? capturedInstructions;

  @override
  Future<String> summarizeForCompaction(
    AgentTask task,
    List<AgentEvent> events, {
    String? customInstructions,
  }) async {
    capturedInstructions = customInstructions;
    return super.summarizeForCompaction(
      task,
      events,
      customInstructions: customInstructions,
    );
  }
}

AgentTask _task() => AgentTask(
      id: 't-1',
      profileId: 'p-1',
      title: '测试',
      workspaceId: 'w-1',
      workspaceName: '工作区',
      status: AgentTaskStatus.paused,
      mode: AgentSessionMode.code,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  test('内容超出 keep 上限时强制压缩并落 CompactionEvent', () async {
    final store = InMemoryAgentEventStore();
    final task = _task();
    for (var i = 0; i < 12; i++) {
      await store.appendUserMessage(task.id, '消息$i：${'长' * 500}');
    }
    final outcome = await runManualCompaction(
      task: task,
      events: await store.getEvents(task.id),
      llm: const FakeAgentLlmClient(),
      store: store,
      keepChars: 1000,
    );
    expect(outcome, isA<ManualCompactionDone>());
    expect((outcome as ManualCompactionDone).coveredCount, greaterThan(0));
    final events = await store.getEvents(task.id);
    expect(events.whereType<CompactionEvent>(), hasLength(1));
  });

  test('内容太少（keep 规则下无可覆盖前缀）时返回 NothingToCover', () async {
    final store = InMemoryAgentEventStore();
    final task = _task();
    await store.appendUserMessage(task.id, '很短的消息');
    final outcome = await runManualCompaction(
      task: task,
      events: await store.getEvents(task.id),
      llm: const FakeAgentLlmClient(),
      store: store,
      keepChars: 40000,
    );
    expect(outcome, isA<ManualCompactionNothingToCover>());
    final events = await store.getEvents(task.id);
    expect(events.whereType<CompactionEvent>(), isEmpty);
  });

  test('自定义指令透传到摘要调用（升级计划 ⑦）', () async {
    final store = InMemoryAgentEventStore();
    final task = _task();
    for (var i = 0; i < 12; i++) {
      await store.appendUserMessage(task.id, '消息$i：${'长' * 500}');
    }
    final llm = _InstructionCapturingLlmClient();
    final outcome = await runManualCompaction(
      task: task,
      events: await store.getEvents(task.id),
      llm: llm,
      store: store,
      keepChars: 1000,
      customInstructions: '重点保留报错细节',
    );
    expect(outcome, isA<ManualCompactionDone>());
    expect(llm.capturedInstructions, '重点保留报错细节');
  });

  test('取消后返回 Cancelled 且不落 CompactionEvent', () async {
    final store = InMemoryAgentEventStore();
    final task = _task();
    for (var i = 0; i < 12; i++) {
      await store.appendUserMessage(task.id, '消息$i：${'长' * 500}');
    }
    final outcome = await runManualCompaction(
      task: task,
      events: await store.getEvents(task.id),
      llm: const FakeAgentLlmClient(),
      store: store,
      keepChars: 1000,
      isCancelled: () => true,
    );
    expect(outcome, isA<ManualCompactionCancelled>());
    final events = await store.getEvents(task.id);
    expect(events.whereType<CompactionEvent>(), isEmpty);
  });
}
