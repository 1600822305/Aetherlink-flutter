import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_budget.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_compaction.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_executor.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/approval_gate.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

import 'fakes/fake_agent_llm_client.dart';
import 'fakes/fake_agent_tool_executor.dart';

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
    List<AgentUserAttachment> attachments = const [],
    String? replyToQuestionId,
  }) async {
    final event = UserMessageEvent(
      id: _newId(),
      seq: _nextSeq(taskId),
      at: DateTime.now(),
      text: text,
      queued: queued,
      attachments: attachments,
      replyToQuestionId: replyToQuestionId,
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
        list[i] = UserMessageEvent(
          id: e.id,
          seq: e.seq,
          at: e.at,
          text: e.text,
          attachments: e.attachments,
          replyToQuestionId: e.replyToQuestionId,
        );
      }
    }
  }

  @override
  Future<UserQuestionEvent> appendUserQuestion(
    String taskId,
    String question, {
    List<String> suggestions = const [],
    String? toolCallId,
    String? argsJson,
  }) async {
    final event = UserQuestionEvent(
      id: _newId(),
      seq: _nextSeq(taskId),
      at: DateTime.now(),
      question: question,
      suggestions: suggestions,
      toolCallId: toolCallId,
      argsJson: argsJson,
    );
    _upsert(taskId, event);
    return event;
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
    String? argSummary,
    String? argsDetail,
    String? resultSummary,
    String? resultDetail,
    String? resultOverflowPath,
    Duration? elapsed,
  }) async {
    final updated = ToolCallEvent(
      id: event.id,
      seq: event.seq,
      at: event.at,
      toolName: event.toolName,
      argSummary: argSummary ?? event.argSummary,
      state: state,
      resultSummary: resultSummary ?? event.resultSummary,
      elapsed: elapsed ?? event.elapsed,
      argsDetail: argsDetail ?? event.argsDetail,
      resultDetail: resultDetail ?? event.resultDetail,
      resultOverflowPath: resultOverflowPath ?? event.resultOverflowPath,
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

  @override
  Future<CheckpointEvent> appendCheckpoint(
    String taskId, {
    required String commit,
    String label = '',
  }) async {
    final event = CheckpointEvent(
      id: _newId(),
      seq: _nextSeq(taskId),
      at: DateTime.now(),
      commit: commit,
      label: label,
    );
    _upsert(taskId, event);
    return event;
  }

  @override
  Future<void> truncateEventsAfter(String taskId, int seq) async {
    _events[taskId]?.removeWhere((e) => e.seq > seq);
  }

  @override
  Future<CompactionEvent> appendCompaction(
    String taskId, {
    required int coveredCount,
    required String summary,
  }) async {
    final event = CompactionEvent(
      id: _newId(),
      seq: _nextSeq(taskId),
      at: DateTime.now(),
      coveredCount: coveredCount,
      summary: summary,
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
    Future<void> Function(
      String streamKey,
      String? toolName,
      String argsTextSoFar,
    )? onToolCallDelta,
    Future<void> Function(AgentToolCallRequest call, String? streamKey)?
        onToolCall,
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

  @override
  Future<String> summarizeForCompaction(
    AgentTask task,
    List<AgentEvent> events,
  ) async =>
      '摘要：覆盖 ${events.length} 条';
}

/// 每轮产出一个大输出工具调用，直到某轮后 finish（测 compaction）。
class BigOutputLlm implements AgentLlmClient {
  BigOutputLlm({required this.roundsBeforeFinish});

  final int roundsBeforeFinish;
  int _round = 0;

  @override
  Future<AgentLlmTurn> completeTurn(
    AgentLlmContext context, {
    void Function(String textSoFar)? onTextDelta,
    void Function(String reasoningSoFar)? onReasoningDelta,
    Future<void> Function(
      String streamKey,
      String? toolName,
      String argsTextSoFar,
    )? onToolCallDelta,
    Future<void> Function(AgentToolCallRequest call, String? streamKey)?
        onToolCall,
    AgentCancellationToken? cancel,
  }) async {
    _round++;
    if (_round > roundsBeforeFinish) {
      return AgentLlmTurn(
        toolCalls: [
          AgentToolCallRequest(
            id: 'call-finish',
            name: kToolFinishTask,
            argsJson: jsonEncode({'summary': '完成'}),
            argSummary: '收尾',
          ),
        ],
      );
    }
    return AgentLlmTurn(
      toolCalls: [
        AgentToolCallRequest(
          id: 'call-big-$_round',
          name: 'read_file',
          argsJson: jsonEncode({'path': 'big-$_round.txt'}),
          argSummary: 'big-$_round.txt',
        ),
      ],
    );
  }

  @override
  Future<String> summarizeForCompaction(
    AgentTask task,
    List<AgentEvent> events,
  ) async =>
      '摘要：覆盖 ${events.length} 条';
}

class BigOutputToolExecutor implements AgentToolExecutor {
  @override
  Future<AgentToolResult> execute(
    AgentToolCallRequest call,
    AgentCancellationToken cancel,
  ) async =>
      AgentToolResult(ok: true, summary: 'ok', detail: 'x' * 500);
}

class FailingToolExecutor implements AgentToolExecutor {
  @override
  Future<AgentToolResult> execute(
    AgentToolCallRequest call,
    AgentCancellationToken cancel,
  ) async =>
      const AgentToolResult(ok: false, summary: '失败 ✗');
}

class StructuredAskUserLlm implements AgentLlmClient {
  @override
  Future<AgentLlmTurn> completeTurn(
    AgentLlmContext context, {
    void Function(String textSoFar)? onTextDelta,
    void Function(String reasoningSoFar)? onReasoningDelta,
    Future<void> Function(
      String streamKey,
      String? toolName,
      String argsTextSoFar,
    )? onToolCallDelta,
    Future<void> Function(AgentToolCallRequest call, String? streamKey)?
        onToolCall,
    AgentCancellationToken? cancel,
  }) async {
    final answered = context.events.whereType<UserMessageEvent>().any(
          (event) => event.replyToQuestionId != null,
        );
    if (answered) {
      return AgentLlmTurn(
        toolCalls: [
          AgentToolCallRequest(
            id: 'finish-1',
            name: kToolFinishTask,
            argsJson: jsonEncode({'summary': '已收到回答'}),
            argSummary: '完成',
          ),
        ],
      );
    }
    return AgentLlmTurn(
      toolCalls: [
        AgentToolCallRequest(
          id: 'ask-1',
          name: kToolAskUser,
          argsJson: jsonEncode({
            'question': '选择发布环境',
            'follow_up': ['测试', '生产'],
          }),
          argSummary: '询问发布配置',
        ),
      ],
    );
  }

  @override
  Future<String> summarizeForCompaction(
    AgentTask task,
    List<AgentEvent> events,
  ) async =>
      '摘要';
}

/// 发一次工具调用，下一轮 finish_task 收尾。
class OneToolThenFinishLlm implements AgentLlmClient {
  var _round = 0;

  @override
  Future<AgentLlmTurn> completeTurn(
    AgentLlmContext context, {
    void Function(String textSoFar)? onTextDelta,
    void Function(String reasoningSoFar)? onReasoningDelta,
    Future<void> Function(
      String streamKey,
      String? toolName,
      String argsTextSoFar,
    )? onToolCallDelta,
    Future<void> Function(AgentToolCallRequest call, String? streamKey)?
        onToolCall,
    AgentCancellationToken? cancel,
  }) async {
    _round++;
    if (_round > 1) {
      return AgentLlmTurn(
        toolCalls: [
          AgentToolCallRequest(
            id: 'finish-1',
            name: kToolFinishTask,
            argsJson: jsonEncode({'summary': '完成'}),
            argSummary: '完成',
          ),
        ],
      );
    }
    return AgentLlmTurn(
      toolCalls: [
        AgentToolCallRequest(
          id: 'call-1',
          name: 'terminal_execute',
          argsJson: jsonEncode({'command': 'git push'}),
          argSummary: 'git push',
        ),
      ],
    );
  }

  @override
  Future<String> summarizeForCompaction(
    AgentTask task,
    List<AgentEvent> events,
  ) async =>
      '摘要';
}

/// 需要审批的门：模拟审批等待期间有陈旧的工具打断标记（如用户
/// 打断发送与点击批准几乎同时），最终裁决为批准。
class InterruptDuringWaitApprovalGate implements ApprovalGate {
  var _asked = false;

  @override
  Future<ApprovalRequirement> evaluate(
    AgentToolCallRequest call,
    AgentTask task,
  ) async {
    if (call.name != 'terminal_execute' || _asked) {
      return ApprovalRequirement.allow;
    }
    _asked = true;
    return ApprovalRequirement.needsUser;
  }

  @override
  Future<ApprovalVerdict> waitForVerdict(
    AgentToolCallRequest call,
    AgentTask task,
    AgentCancellationToken cancel,
  ) async {
    cancel.requestToolInterrupt();
    return const ApprovalVerdict.approved();
  }
}

/// 记录执行时刻的打断标记状态（真实执行器会据此瞬间中断命令）。
class InterruptFlagRecordingExecutor implements AgentToolExecutor {
  final List<bool> interruptFlagsAtExecute = [];

  @override
  Future<AgentToolResult> execute(
    AgentToolCallRequest call,
    AgentCancellationToken cancel,
  ) async {
    interruptFlagsAtExecute.add(cancel.toolInterruptRequested);
    return const AgentToolResult(ok: true, summary: 'ok ✓');
  }
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
  test('审批通过后当前工具真正执行：审批等待期间的陈旧打断标记不生效', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    final executor = InterruptFlagRecordingExecutor();
    final engine = AgentEngine(
      llm: OneToolThenFinishLlm(),
      tools: executor,
      approval: InterruptDuringWaitApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(),
    );
    final task = newTask();
    await store.appendUserMessage(task.id, '推送代码');

    await engine.run(task, AgentCancellationToken());

    expect(gateway.last.status, AgentTaskStatus.done);
    // 批准后的这一次调用必须执行，且执行时刻打断标记已被消费。
    expect(executor.interruptFlagsAtExecute, [false]);
    final toolEvent = (await store.getEvents(task.id))
        .whereType<ToolCallEvent>()
        .single;
    expect(toolEvent.state, AgentToolCallState.success);
  });

  test('ask_user 提问落库、等待回答并可恢复完成', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    final engine = AgentEngine(
      llm: StructuredAskUserLlm(),
      tools: const FakeAgentToolExecutor(delay: Duration.zero),
      approval: const AutoApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(),
    );
    final task = newTask();
    await store.appendUserMessage(task.id, '部署应用');

    await engine.run(task, AgentCancellationToken());

    expect(gateway.last.status, AgentTaskStatus.waitingInput);
    final question =
        (await store.getEvents(task.id)).whereType<UserQuestionEvent>().single;
    expect(question.toolCallId, 'ask-1');
    expect(question.question, '选择发布环境');
    expect(question.suggestions, ['测试', '生产']);

    await store.appendUserMessage(
      task.id,
      '测试',
      replyToQuestionId: question.id,
    );
    await engine.run(gateway.last, AgentCancellationToken());

    expect(gateway.last.status, AgentTaskStatus.done);
    expect(gateway.last.lastEventSummary, '已收到回答');
  });

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

  test('stop hook 阻止收尾：原因回填继续跑，放行后 done（最多阻一次）', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    var guardCalls = 0;
    final engine = AgentEngine(
      llm: const FakeAgentLlmClient(chunkDelay: Duration.zero),
      tools: const FakeAgentToolExecutor(delay: Duration.zero),
      approval: const AutoApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(),
      stopGuard: () async {
        guardCalls++;
        return '还有测试没跑';
      },
    );
    final task = newTask();
    await store.appendUserMessage(task.id, '帮我看看项目结构');

    await engine.run(task, AgentCancellationToken());

    expect(gateway.last.status, AgentTaskStatus.done);
    // 每次运行最多阻一次：第二次收尾不再调 guard，直接放行（防死循环）。
    expect(guardCalls, 1);
    final messages =
        (await store.getEvents(task.id)).whereType<UserMessageEvent>();
    expect(messages.any((m) => m.text.contains('还有测试没跑')), isTrue);
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

  test('续跑时半途工具调用（running/waitingApproval）按失败回填', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    final engine = AgentEngine(
      llm: const FakeAgentLlmClient(chunkDelay: Duration.zero),
      tools: const FakeAgentToolExecutor(delay: Duration.zero),
      approval: const AutoApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(),
    );
    final task = newTask();
    await store.appendUserMessage(task.id, '帮我看看项目结构');
    // 模拟上次进程死亡时半途的两个工具调用。
    final stale1 = await store.appendToolCall(
      task.id,
      AgentToolCallRequest(
        id: 'call-stale-1',
        name: 'run_command',
        argsJson: jsonEncode({'command': 'ls'}),
        argSummary: 'ls',
      ),
      AgentToolCallState.running,
    );
    final stale2 = await store.appendToolCall(
      task.id,
      AgentToolCallRequest(
        id: 'call-stale-2',
        name: 'run_command',
        argsJson: jsonEncode({'command': 'rm x'}),
        argSummary: 'rm x',
      ),
      AgentToolCallState.waitingApproval,
    );

    await engine.run(
      task.copyWith(status: AgentTaskStatus.paused),
      AgentCancellationToken(),
    );

    final events = await store.getEvents(task.id);
    for (final id in [stale1.id, stale2.id]) {
      final e = events.whereType<ToolCallEvent>().firstWhere(
            (t) => t.id == id,
          );
      expect(e.state, AgentToolCallState.failure);
      expect(e.resultSummary, contains('进程中断'));
    }
    expect(gateway.last.status, AgentTaskStatus.done);
  });

  test('token 预算超限 → paused（可继续），续跑新预算可完成', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    AgentEngine buildEngine(AgentBudget budget) => AgentEngine(
          llm: const FakeAgentLlmClient(chunkDelay: Duration.zero),
          tools: const FakeAgentToolExecutor(delay: Duration.zero),
          approval: const AutoApprovalGate(),
          store: store,
          gateway: gateway,
          budget: budget,
        );
    final task = newTask();
    await store.appendUserMessage(task.id, '帮我看看项目结构');

    // 第 1 轮用掉 120 tokens 即超预算 → 安全点 paused。
    await buildEngine(
      AgentBudget(maxTokens: 100),
    ).run(task, AgentCancellationToken());
    expect(gateway.last.status, AgentTaskStatus.paused);
    expect(gateway.last.lastEventSummary, contains('token'));

    // 续跑发新预算，任务可完成。
    await buildEngine(
      AgentBudget(),
    ).run(gateway.last, AgentCancellationToken());
    expect(gateway.last.status, AgentTaskStatus.done);
  });

  test('上下文超阈值 → 自动 compaction（摘要落库且折叠视图变小）', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    final engine = AgentEngine(
      llm: BigOutputLlm(roundsBeforeFinish: 12),
      tools: BigOutputToolExecutor(),
      approval: const AutoApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(
        compactionTriggerChars: 1200,
        compactionKeepChars: 600,
      ),
    );
    final task = newTask();
    await store.appendUserMessage(task.id, '连续读大文件');

    await engine.run(task, AgentCancellationToken());

    expect(gateway.last.status, AgentTaskStatus.done);
    final events = await store.getEvents(task.id);
    final compactions = events.whereType<CompactionEvent>().toList();
    expect(compactions, isNotEmpty);
    expect(compactions.first.coveredCount, greaterThan(0));
    expect(compactions.first.summary, isNotEmpty);
    // 原始事件不丢（审计），折叠视图被摘要替代且不超预算太多。
    final folded = foldCompactedEvents(events);
    expect(
      folded.length,
      lessThan(
        events.whereType<ToolCallEvent>().length +
            events.whereType<UserMessageEvent>().length +
            compactions.length,
      ),
    );
    expect(events.whereType<ToolCallEvent>().length, greaterThanOrEqualTo(12));
  });

  test('foldCompactedEvents：覆盖最早条目并把摘要插到队首', () async {
    final store = InMemoryAgentEventStore();
    const taskId = 'task-f';
    await store.appendUserMessage(taskId, '第一条');
    await store.appendAssistantText(taskId, '回应一', streaming: false);
    await store.appendAssistantText(taskId, '回应二', streaming: false);
    await store.appendCompaction(taskId, coveredCount: 2, summary: '早期摘要');
    await store.appendUserMessage(taskId, '第二条');

    final folded = foldCompactedEvents(await store.getEvents(taskId));
    expect(folded.length, 3);
    expect(folded[0], isA<CompactionEvent>());
    expect((folded[1] as AssistantTextEvent).text, '回应二');
    expect((folded[2] as UserMessageEvent).text, '第二条');
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
