import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_budget.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_executor.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/approval_gate.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/fakes/fake_agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/fakes/fake_agent_tool_executor.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 内存事件仓：不依赖 drift，验证引擎「每步落库」的调用序列。
class InMemoryAgentEventStore implements AgentEventStore {
  final Map<String, List<AgentEvent>> _events = {};
  int _idCounter = 0;

  List<AgentEvent> eventsOf(String taskId) => _events[taskId] ?? const [];

  String _newId() => 'e-${_idCounter++}';

  int _nextSeq(String taskId) {
    final list = _events[taskId];
    if (list == null || list.isEmpty) return 1;
    return list.map((e) => e.seq).reduce((a, b) => a > b ? a : b) + 1;
  }

  void _upsert(String taskId, AgentEvent event) {
    final list = _events.putIfAbsent(taskId, () => []);
    final index = list.indexWhere((e) => e.id == event.id);
    if (index >= 0) {
      list[index] = event;
    } else {
      list.add(event);
    }
  }

  @override
  Future<List<AgentEvent>> getEvents(String taskId) async =>
      List.of(eventsOf(taskId))..sort((a, b) => a.seq.compareTo(b.seq));

  @override
  Future<UserMessageEvent> appendUserMessage(
    String taskId,
    String text, {
    bool queued = false,
  }) async {
    final event = UserMessageEvent(
      id: _newId(),
      seq: _nextSeq(taskId),
      at: DateTime.now(),
      text: text,
      queued: queued,
    );
    _upsert(taskId, event);
    return event;
  }

  @override
  Future<void> consumeQueuedUserMessages(String taskId) async {
    final list = _events[taskId];
    if (list == null) return;
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      if (e is UserMessageEvent && e.queued) {
        list[i] =
            UserMessageEvent(id: e.id, seq: e.seq, at: e.at, text: e.text);
      }
    }
  }

  @override
  Future<AssistantTextEvent> appendAssistantText(
    String taskId,
    String text, {
    required bool streaming,
  }) async {
    final event = AssistantTextEvent(
      id: _newId(),
      seq: _nextSeq(taskId),
      at: DateTime.now(),
      text: text,
      streaming: streaming,
    );
    _upsert(taskId, event);
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
    _upsert(taskId, updated);
    return updated;
  }

  @override
  Future<ReasoningEvent> appendReasoning(
    String taskId,
    String text, {
    required bool streaming,
  }) async {
    final event = ReasoningEvent(
      id: _newId(),
      seq: _nextSeq(taskId),
      at: DateTime.now(),
      text: text,
      streaming: streaming,
    );
    _upsert(taskId, event);
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
    _upsert(taskId, updated);
    return updated;
  }

  @override
  Future<ToolCallEvent> appendToolCall(
    String taskId,
    AgentToolCallRequest call,
    AgentToolCallState state,
  ) async {
    final event = ToolCallEvent(
      id: _newId(),
      seq: _nextSeq(taskId),
      at: DateTime.now(),
      toolName: call.name,
      argSummary: call.argSummary,
      state: state,
      argsDetail: call.argsJson,
    );
    _upsert(taskId, event);
    return event;
  }

  @override
  Future<ToolCallEvent> updateToolCall(
    String taskId,
    ToolCallEvent event, {
    required AgentToolCallState state,
    String? resultSummary,
    String? resultDetail,
    Duration? elapsed,
  }) async {
    final updated = ToolCallEvent(
      id: event.id,
      seq: event.seq,
      at: event.at,
      toolName: event.toolName,
      argSummary: event.argSummary,
      state: state,
      resultSummary: resultSummary ?? event.resultSummary,
      elapsed: elapsed ?? event.elapsed,
      argsDetail: event.argsDetail,
      resultDetail: resultDetail ?? event.resultDetail,
    );
    _upsert(taskId, updated);
    return updated;
  }

  @override
  Future<PlanUpdateEvent> appendPlanUpdate(
    String taskId,
    List<AgentPlanItem> items,
  ) async {
    final event = PlanUpdateEvent(
      id: _newId(),
      seq: _nextSeq(taskId),
      at: DateTime.now(),
      items: items,
    );
    _upsert(taskId, event);
    return event;
  }

  @override
  Future<StatusChangeEvent> appendStatusChange(
    String taskId,
    String description,
  ) async {
    final event = StatusChangeEvent(
      id: _newId(),
      seq: _nextSeq(taskId),
      at: DateTime.now(),
      description: description,
    );
    _upsert(taskId, event);
    return event;
  }
}

class RecordingTaskGateway implements AgentTaskGateway {
  final List<AgentTask> saves = [];

  AgentTask get last => saves.last;

  @override
  Future<void> save(AgentTask task) async => saves.add(task);
}

/// 每轮只发一个失败工具调用的 LLM（测预算护栏）。
class AlwaysFailingToolLlm implements AgentLlmClient {
  @override
  Future<AgentLlmTurn> completeTurn(
    AgentLlmContext context, {
    void Function(String textSoFar)? onTextDelta,
    void Function(String reasoningSoFar)? onReasoningDelta,
    AgentCancellationToken? cancel,
  }) async {
    return AgentLlmTurn(
      toolCalls: [
        AgentToolCallRequest(
          id: 'call-x',
          name: 'run_command',
          argsJson: jsonEncode({'command': 'false'}),
          argSummary: 'false',
        ),
      ],
    );
  }
}

class FailingToolExecutor implements AgentToolExecutor {
  @override
  Future<AgentToolResult> execute(
    AgentToolCallRequest call,
    AgentCancellationToken cancel,
  ) async =>
      const AgentToolResult(ok: false, summary: '失败 ✗');
}

AgentTask newTask() {
  final now = DateTime.now();
  return AgentTask(
    id: 'task-1',
    profileId: 'agent-1',
    title: '测试任务',
    workspaceId: 'ws-1',
    workspaceName: '测试工作区',
    status: AgentTaskStatus.running,
    mode: AgentSessionMode.code,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('假 LLM/假工具：完整状态机跑通并以 done 收尾', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    final engine = AgentEngine(
      llm: const FakeAgentLlmClient(chunkDelay: Duration.zero),
      tools: const FakeAgentToolExecutor(delay: Duration(milliseconds: 10)),
      approval: const AutoApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(),
    );
    final task = newTask();
    await store.appendUserMessage(task.id, '帮我看看项目结构');

    await engine.run(task, AgentCancellationToken());

    expect(gateway.last.status, AgentTaskStatus.done);
    expect(gateway.last.rounds, 2);

    final events = await store.getEvents(task.id);
    // 计划事件两次（in_progress → completed）。
    expect(events.whereType<PlanUpdateEvent>().length, 2);
    // 工具调用成功且有耗时/结果。
    final tool = events.whereType<ToolCallEvent>().single;
    expect(tool.state, AgentToolCallState.success);
    expect(tool.resultSummary, isNotEmpty);
    expect(tool.elapsed, isNotNull);
    // 助手文本已收尾（非流式中）。
    expect(
      events.whereType<AssistantTextEvent>().every((e) => !e.streaming),
      isTrue,
    );
    // 思考事件已流式原位落库并定格（非流式 + 有耗时）。
    final reasoning = events.whereType<ReasoningEvent>();
    expect(reasoning, isNotEmpty);
    expect(reasoning.every((e) => !e.streaming), isTrue);
    expect(reasoning.every((e) => e.elapsed != null), isTrue);
    expect(reasoning.first.text, isNotEmpty);
    // seq 严格递增无重复。
    final seqs = [for (final e in events) e.seq];
    expect(seqs.toSet().length, seqs.length);
  });

  test('连续失败达到预算上限 → paused 而非 failed', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    final engine = AgentEngine(
      llm: AlwaysFailingToolLlm(),
      tools: FailingToolExecutor(),
      approval: const AutoApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(maxConsecutiveFailures: 3),
    );
    final task = newTask();
    await store.appendUserMessage(task.id, '跑一下');

    await engine.run(task, AgentCancellationToken());

    expect(gateway.last.status, AgentTaskStatus.paused);
    final events = await store.getEvents(task.id);
    expect(
      events.whereType<ToolCallEvent>().length,
      3,
      reason: '3 次连续失败后停在安全点',
    );
  });

  test('取消在安全点生效 → cancelled', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    final engine = AgentEngine(
      llm: AlwaysFailingToolLlm(),
      tools: FailingToolExecutor(),
      approval: const AutoApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(),
    );
    final task = newTask();
    await store.appendUserMessage(task.id, '跑一下');
    final token = AgentCancellationToken()..requestCancel();

    await engine.run(task, token);

    expect(gateway.last.status, AgentTaskStatus.cancelled);
    // 没有执行任何工具（安全点先于工具执行）。
    final events = await store.getEvents(task.id);
    expect(events.whereType<ToolCallEvent>(), isEmpty);
  });

  test('暂停在安全点生效 → paused，续跑可完成', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    AgentEngine buildEngine() => AgentEngine(
          llm: const FakeAgentLlmClient(chunkDelay: Duration.zero),
          tools:
              const FakeAgentToolExecutor(delay: Duration(milliseconds: 10)),
          approval: const AutoApprovalGate(),
          store: store,
          gateway: gateway,
          budget: AgentBudget(),
        );
    final task = newTask();
    await store.appendUserMessage(task.id, '帮我看看项目结构');

    final token = AgentCancellationToken()..requestPause();
    await buildEngine().run(task, token);
    expect(gateway.last.status, AgentTaskStatus.paused);

    // 恢复（L7）：重放事件流续跑到 done。
    await buildEngine().run(gateway.last, AgentCancellationToken());
    expect(gateway.last.status, AgentTaskStatus.done);
  });

  test('排队消息在安全点被消费（queued → false）', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    final engine = AgentEngine(
      llm: const FakeAgentLlmClient(chunkDelay: Duration.zero),
      tools: const FakeAgentToolExecutor(delay: Duration(milliseconds: 10)),
      approval: const AutoApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(),
    );
    final task = newTask();
    await store.appendUserMessage(task.id, '帮我看看项目结构');
    await store.appendUserMessage(task.id, '顺便注意测试', queued: true);

    await engine.run(task, AgentCancellationToken());

    final events = await store.getEvents(task.id);
    expect(
      events.whereType<UserMessageEvent>().every((e) => !e.queued),
      isTrue,
    );
  });
}
