import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_budget.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_compaction.dart';
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
  Future<StatusChangeEvent> updateStatusChange(
    String taskId,
    StatusChangeEvent event,
    String description,
  ) async {
    final updated = StatusChangeEvent(
      id: event.id,
      seq: event.seq,
      at: event.at,
      description: description,
    );
    _upsert(taskId, updated);
    return updated;
  }

  @override
  Future<CheckpointEvent> appendCheckpoint(
    String taskId, {
    required Map<String, String> commits,
    String label = '',
  }) async {
    final event = CheckpointEvent(
      id: _newId(),
      seq: _nextSeq(taskId),
      at: DateTime.now(),
      commits: commits,
      label: label,
    );
    _upsert(taskId, event);
    return event;
  }

  @override
  Future<CheckpointEvent> updateCheckpoint(
    String taskId,
    CheckpointEvent event, {
    required Map<String, String> commits,
  }) async {
    final updated = CheckpointEvent(
      id: event.id,
      seq: event.seq,
      at: event.at,
      commits: commits,
      label: event.label,
    );
    _upsert(taskId, updated);
    return updated;
  }

  @override
  Future<StatusChangeEvent> replaceCheckpointWithStatus(
    String taskId,
    CheckpointEvent event,
    String description,
  ) async {
    final updated = StatusChangeEvent(
      id: event.id,
      seq: event.seq,
      at: event.at,
      description: description,
    );
    _upsert(taskId, updated);
    return updated;
  }

  @override
  Future<void> removeEvent(String taskId, AgentEvent event) async {
    _events[taskId]?.removeWhere((e) => e.id == event.id);
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
    List<CompactionRestoredFile> restoredFiles = const [],
  }) async {
    final event = CompactionEvent(
      id: _newId(),
      seq: _nextSeq(taskId),
      at: DateTime.now(),
      coveredCount: coveredCount,
      summary: summary,
      restoredFiles: restoredFiles,
    );
    _upsert(taskId, event);
    return event;
  }

  @override
  Future<CompactionEvent> updateCompaction(
    String taskId,
    CompactionEvent event, {
    required bool revoked,
  }) async {
    final updated = CompactionEvent(
      id: event.id,
      seq: event.seq,
      at: event.at,
      coveredCount: event.coveredCount,
      summary: event.summary,
      revoked: revoked,
      restoredFiles: event.restoredFiles,
    );
    _upsert(taskId, updated);
    return updated;
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
    List<AgentEvent> events, {
    String? customInstructions,
  }) async =>
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
    List<AgentEvent> events, {
    String? customInstructions,
  }) async =>
      '摘要：覆盖 ${events.length} 条';
}

/// 记录每轮 AgentLlmContext 的 microcompact 生效值后直接 finish
/// （测 budget → 重放侧的一致性接线）。
class ContextCapturingLlm implements AgentLlmClient {
  final capturedMicroEnabled = <bool>[];
  final capturedMicroTriggerChars = <int>[];

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
    capturedMicroEnabled.add(context.microCompactEnabled);
    capturedMicroTriggerChars.add(context.microCompactTriggerChars);
    return AgentLlmTurn(
      toolCalls: [
        AgentToolCallRequest(
          id: 'finish-1',
          name: kToolFinishTask,
          argsJson: jsonEncode({'summary': '完成'}),
          argSummary: '收尾',
        ),
      ],
    );
  }

  @override
  Future<String> summarizeForCompaction(
    AgentTask task,
    List<AgentEvent> events, {
    String? customInstructions,
  }) async =>
      '摘要';
}

class BigOutputToolExecutor implements AgentToolExecutor {
  @override
  bool isConcurrencySafe(AgentToolCallRequest call) => false;

  @override
  Future<AgentToolResult> execute(
    AgentToolCallRequest call,
    AgentCancellationToken cancel,
  ) async =>
      AgentToolResult(ok: true, summary: 'ok', detail: 'x' * 500);
}

class FailingToolExecutor implements AgentToolExecutor {
  @override
  bool isConcurrencySafe(AgentToolCallRequest call) => false;

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
    List<AgentEvent> events, {
    String? customInstructions,
  }) async =>
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
        text: '已推送完成。',
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
    List<AgentEvent> events, {
    String? customInstructions,
  }) async =>
      '摘要';
}

/// 同一轮先 finish_task 再跟一个普通工具，且普通工具经 onToolCall
/// 预建事件（测收尾时剩余预建事件的回填）。
class FinishWithTrailingToolLlm implements AgentLlmClient {
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
    final trailing = AgentToolCallRequest(
      id: 'call-after-finish',
      name: 'read_file',
      argsJson: jsonEncode({'path': 'a.txt'}),
      argSummary: 'a.txt',
    );
    await onToolCall?.call(trailing, null);
    return AgentLlmTurn(
      text: '已完成。',
      toolCalls: [
        AgentToolCallRequest(
          id: 'finish-1',
          name: kToolFinishTask,
          argsJson: jsonEncode({'summary': '完成'}),
          argSummary: '完成',
        ),
        trailing,
      ],
    );
  }

  @override
  Future<String> summarizeForCompaction(
    AgentTask task,
    List<AgentEvent> events, {
    String? customInstructions,
  }) async =>
      '摘要';
}

/// 一轮发两个只读工具调用，下一轮 finish_task 收尾（测只读并发段）。
class TwoReadToolsThenFinishLlm implements AgentLlmClient {
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
        text: '两个文件已读完。',
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
          id: 'read-1',
          name: 'read_file',
          argsJson: jsonEncode({'path': 'a.txt'}),
          argSummary: 'a.txt',
        ),
        AgentToolCallRequest(
          id: 'read-2',
          name: 'read_file',
          argsJson: jsonEncode({'path': 'b.txt'}),
          argSummary: 'b.txt',
        ),
      ],
    );
  }

  @override
  Future<String> summarizeForCompaction(
    AgentTask task,
    List<AgentEvent> events, {
    String? customInstructions,
  }) async =>
      '摘要';
}

/// 记录并发度的只读执行器：两个调用都开始后才放行
/// （验证只读段真正 Future.wait 并行）。
class ConcurrencyRecordingExecutor implements AgentToolExecutor {
  final _bothStarted = Completer<void>();
  var _running = 0;
  var maxConcurrent = 0;

  @override
  bool isConcurrencySafe(AgentToolCallRequest call) => true;

  @override
  Future<AgentToolResult> execute(
    AgentToolCallRequest call,
    AgentCancellationToken cancel,
  ) async {
    _running++;
    if (_running > maxConcurrent) maxConcurrent = _running;
    if (_running >= 2 && !_bothStarted.isCompleted) {
      _bothStarted.complete();
    }
    await _bothStarted.future.timeout(const Duration(seconds: 5));
    _running--;
    return const AgentToolResult(ok: true, summary: 'ok ✓');
  }
}

/// 摘要始终返回空（压缩必失败）的大输出 LLM（测压缩失败回调）。
class EmptySummaryBigOutputLlm extends BigOutputLlm {
  EmptySummaryBigOutputLlm({required super.roundsBeforeFinish});

  @override
  Future<String> summarizeForCompaction(
    AgentTask task,
    List<AgentEvent> events, {
    String? customInstructions,
  }) async =>
      '';
}

/// 前 [overflowTurns] 轮抛「上下文超限」错误，之后 finish
/// （测反应式压缩，升级计划 ⑧）。
class OverflowThenFinishLlm implements AgentLlmClient {
  OverflowThenFinishLlm({this.overflowTurns = 1});

  final int overflowTurns;
  int _turn = 0;

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
    _turn++;
    if (_turn <= overflowTurns) {
      throw Exception('prompt is too long: 137500 tokens > 135000 maximum');
    }
    return AgentLlmTurn(
      toolCalls: [
        AgentToolCallRequest(
          id: 'finish-1',
          name: kToolFinishTask,
          argsJson: jsonEncode({'summary': '完成'}),
          argSummary: '收尾',
        ),
      ],
    );
  }

  @override
  Future<String> summarizeForCompaction(
    AgentTask task,
    List<AgentEvent> events, {
    String? customInstructions,
  }) async =>
      '摘要：覆盖 ${events.length} 条';
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
  bool isConcurrencySafe(AgentToolCallRequest call) => false;

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

  test('同轮连续只读调用并发执行并全部落库成功', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    final executor = ConcurrencyRecordingExecutor();
    final engine = AgentEngine(
      llm: TwoReadToolsThenFinishLlm(),
      tools: executor,
      approval: const AutoApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(),
    );
    final task = newTask();
    await store.appendUserMessage(task.id, '读两个文件');

    await engine.run(task, AgentCancellationToken());

    expect(gateway.last.status, AgentTaskStatus.done);
    expect(executor.maxConcurrent, 2);
    final toolEvents =
        (await store.getEvents(task.id)).whereType<ToolCallEvent>().toList();
    expect(toolEvents, hasLength(2));
    expect(toolEvents.map((e) => e.state),
        everyElement(AgentToolCallState.success));
  });

  test('finish_task 收尾时同轮剩余预建工具事件按中断回填，不留永久 running', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    final engine = AgentEngine(
      llm: FinishWithTrailingToolLlm(),
      tools: const FakeAgentToolExecutor(delay: Duration.zero),
      approval: const AutoApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(),
    );
    final task = newTask();
    await store.appendUserMessage(task.id, '收尾');

    await engine.run(task, AgentCancellationToken());

    expect(gateway.last.status, AgentTaskStatus.done);
    final toolEvents =
        (await store.getEvents(task.id)).whereType<ToolCallEvent>().toList();
    // 跟在 finish_task 后面的预建工具事件被回填为失败，而不是永久 running。
    expect(toolEvents.map((e) => e.state),
        isNot(contains(AgentToolCallState.running)));
    expect(toolEvents.map((e) => e.state),
        contains(AgentToolCallState.failure));
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
    // 计划事件两次：in_progress → 全部 completed（收尾自动清空）。
    final plans = events.whereType<PlanUpdateEvent>().toList();
    expect(plans.length, 2);
    expect(plans.first.items, isNotEmpty);
    expect(plans.last.items, isEmpty);
    // update_plan 控制工具有结果回填（成功）。
    final planTools = events
        .whereType<ToolCallEvent>()
        .where((e) => e.toolName == kToolUpdatePlan)
        .toList();
    expect(planTools.length, 2);
    expect(
      planTools.every((e) => e.state == AgentToolCallState.success),
      isTrue,
    );
    // 普通工具调用成功且有耗时/结果。
    final tool = events
        .whereType<ToolCallEvent>()
        .singleWhere((e) => e.toolName == 'read_file');
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

  test('update_plan 参数非法：拒绝并回填错误，已有计划保持不变', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    AgentToolCallRequest call(Map<String, Object?> args) =>
        AgentToolCallRequest(
          id: 'plan-${args.hashCode}',
          name: kToolUpdatePlan,
          argsJson: jsonEncode(args),
          argSummary: '计划',
        );
    final engine = AgentEngine(
      llm: ScriptedLlm([
        AgentLlmTurn(toolCalls: [
          call({
            'items': [
              {'content': '第一步', 'status': 'in_progress'},
            ],
          }),
        ]),
        AgentLlmTurn(toolCalls: [
          // 非法 status + 空 items：都应被拒绝，不覆盖已有计划。
          call({
            'items': [
              {'content': '第一步', 'status': 'done'},
            ],
          }),
          call({'items': <Object?>[]}),
        ]),
        AgentLlmTurn(text: '完成。', toolCalls: [
          AgentToolCallRequest(
            id: 'finish-1',
            name: kToolFinishTask,
            argsJson: jsonEncode({'summary': '完成'}),
            argSummary: '收尾',
          ),
        ]),
      ]),
      tools: const FakeAgentToolExecutor(delay: Duration.zero),
      approval: const AutoApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(),
    );
    final task = newTask();
    await store.appendUserMessage(task.id, '做点事');

    await engine.run(task, AgentCancellationToken());

    expect(gateway.last.status, AgentTaskStatus.done);
    final events = await store.getEvents(task.id);
    // 只有首次合法提交落了计划事件，非法提交没有覆盖/清空。
    final plans = events.whereType<PlanUpdateEvent>().toList();
    expect(plans.length, 1);
    expect(plans.single.items.single.content, '第一步');
    // 控制工具结果回填：1 成功 + 2 失败（带错误说明）。
    final planTools = events
        .whereType<ToolCallEvent>()
        .where((e) => e.toolName == kToolUpdatePlan)
        .toList();
    expect(planTools.length, 3);
    expect(planTools[0].state, AgentToolCallState.success);
    expect(planTools[1].state, AgentToolCallState.failure);
    expect(planTools[1].resultDetail, contains('status 非法'));
    expect(planTools[2].state, AgentToolCallState.failure);
    expect(planTools[2].resultDetail, contains('items 为空'));
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
    var preCompactCalls = 0;
    final postCompactSummaries = <String>[];
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
      onPreCompact: () => preCompactCalls++,
      onPostCompact: postCompactSummaries.add,
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
    // preCompact / postCompact 回调（hooks 接线点）：压缩前后各触发，
    // postCompact 带落库的摘要。
    expect(preCompactCalls, compactions.length);
    expect(postCompactSummaries, [for (final c in compactions) c.summary]);
  });

  test('关自动压缩 → 超阈值不触发压缩，预警提示一次可手动压缩', () async {
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
        autoCompactEnabled: false,
      ),
    );
    final task = newTask();
    await store.appendUserMessage(task.id, '连续读大文件');

    await engine.run(task, AgentCancellationToken());

    expect(gateway.last.status, AgentTaskStatus.done);
    final events = await store.getEvents(task.id);
    expect(events.whereType<CompactionEvent>(), isEmpty);
    final warnings = events
        .whereType<StatusChangeEvent>()
        .where((e) => e.description.contains('自动压缩已关闭'))
        .toList();
    expect(warnings, hasLength(1));
  });

  test('压缩失败 → onCompactionFailed 回调（清理压缩中实况行）', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    var preCompact = 0;
    var postCompact = 0;
    var compactionFailed = 0;
    final engine = AgentEngine(
      llm: EmptySummaryBigOutputLlm(roundsBeforeFinish: 12),
      tools: BigOutputToolExecutor(),
      approval: const AutoApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(
        compactionTriggerChars: 1200,
        compactionKeepChars: 600,
      ),
      onPreCompact: () => preCompact++,
      onPostCompact: (_) => postCompact++,
      onCompactionFailed: () => compactionFailed++,
    );
    final task = newTask();
    await store.appendUserMessage(task.id, '连续读大文件');

    await engine.run(task, AgentCancellationToken());

    expect(gateway.last.status, AgentTaskStatus.done);
    expect(preCompact, greaterThan(0));
    expect(postCompact, 0);
    // 每次失败都回调，压缩中实况行不会挂死。
    expect(compactionFailed, preCompact);
  });

  test('上下文超限 → 反应式压缩后重试本轮并完成（升级计划 ⑧）', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    final engine = AgentEngine(
      llm: OverflowThenFinishLlm(),
      tools: BigOutputToolExecutor(),
      approval: const AutoApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(compactionKeepChars: 600),
    );
    final task = newTask();
    for (var i = 0; i < 12; i++) {
      await store.appendUserMessage(task.id, '消息$i：${'长' * 500}');
    }

    await engine.run(task, AgentCancellationToken());

    expect(gateway.last.status, AgentTaskStatus.done);
    final events = await store.getEvents(task.id);
    expect(events.whereType<CompactionEvent>(), hasLength(1));
    expect(
      events
          .whereType<StatusChangeEvent>()
          .where((e) => e.description.contains('兜底压缩后重试本轮')),
      hasLength(1),
    );
  });

  test('上下文超限持续 → 只兜底一次，第二次直接 failed（防死循环）', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    final engine = AgentEngine(
      llm: OverflowThenFinishLlm(overflowTurns: 99),
      tools: BigOutputToolExecutor(),
      approval: const AutoApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(compactionKeepChars: 600),
    );
    final task = newTask();
    for (var i = 0; i < 12; i++) {
      await store.appendUserMessage(task.id, '消息$i：${'长' * 500}');
    }

    await engine.run(task, AgentCancellationToken());

    expect(gateway.last.status, AgentTaskStatus.failed);
    final events = await store.getEvents(task.id);
    // 兜底压缩发生过一次，但第二次超限不再重试。
    expect(events.whereType<CompactionEvent>(), hasLength(1));
  });

  test('budget 的 microcompact 设置随 AgentLlmContext 传给重放侧', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    final llm = ContextCapturingLlm();
    final engine = AgentEngine(
      llm: llm,
      tools: BigOutputToolExecutor(),
      approval: const AutoApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(
        microCompactEnabled: false,
        microCompactTriggerChars: 12345,
      ),
    );
    final task = newTask();
    await store.appendUserMessage(task.id, '你好');

    await engine.run(task, AgentCancellationToken());

    expect(gateway.last.status, AgentTaskStatus.done);
    expect(llm.capturedMicroEnabled, everyElement(isFalse));
    expect(llm.capturedMicroTriggerChars, everyElement(12345));
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

  test('foldCompactedEvents：已撤销的压缩不参与折叠（视图恢复原样）', () async {
    final store = InMemoryAgentEventStore();
    const taskId = 'task-rv';
    await store.appendUserMessage(taskId, '第一条');
    await store.appendAssistantText(taskId, '回应一', streaming: false);
    await store.appendAssistantText(taskId, '回应二', streaming: false);
    final compaction =
        await store.appendCompaction(taskId, coveredCount: 2, summary: '早期摘要');
    await store.appendUserMessage(taskId, '第二条');
    await store.updateCompaction(taskId, compaction, revoked: true);

    final folded = foldCompactedEvents(await store.getEvents(taskId));
    expect(folded.whereType<CompactionEvent>(), isEmpty);
    expect(folded.length, 4);
    expect((folded[0] as UserMessageEvent).text, '第一条');
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

  group('计划模式（enter/exit_plan_mode）', () {
    AgentToolCallRequest planCall(String name, [Map<String, Object?>? args]) =>
        AgentToolCallRequest(
          id: 'call-$name',
          name: name,
          argsJson: jsonEncode(args ?? const {}),
          argSummary: name,
        );

    test('enter_plan_mode：切入 plan、记录 prePlanMode 并请求重启续跑', () async {
      final store = InMemoryAgentEventStore();
      final gateway = RecordingTaskGateway();
      final restarts = <AgentTask>[];
      final engine = AgentEngine(
        llm: ScriptedLlm([
          AgentLlmTurn(toolCalls: [planCall(kToolEnterPlanMode)]),
        ]),
        tools: const FakeAgentToolExecutor(),
        approval: const AutoApprovalGate(),
        store: store,
        gateway: gateway,
        budget: AgentBudget(),
        onModeSwitchRestart: restarts.add,
      );
      final task = newTask();
      await store.appendUserMessage(task.id, '重构整个模块');

      await engine.run(task, AgentCancellationToken());

      expect(gateway.last.mode, AgentSessionMode.plan);
      expect(gateway.last.prePlanMode, AgentSessionMode.code);
      expect(gateway.last.status, AgentTaskStatus.running);
      expect(restarts.single.mode, AgentSessionMode.plan);
      final toolEvent = (await store.getEvents(task.id))
          .whereType<ToolCallEvent>()
          .single;
      expect(toolEvent.state, AgentToolCallState.success);
      expect(toolEvent.resultDetail, contains('exit_plan_mode'));
    });

    test('enter_plan_mode 在只读模式下拒绝并继续循环', () async {
      final store = InMemoryAgentEventStore();
      final gateway = RecordingTaskGateway();
      final restarts = <AgentTask>[];
      final engine = AgentEngine(
        llm: ScriptedLlm([
          AgentLlmTurn(toolCalls: [planCall(kToolEnterPlanMode)]),
          AgentLlmTurn(text: '规划完成。', toolCalls: [
            planCall(kToolFinishTask, {'summary': '完成'}),
          ]),
        ]),
        tools: const FakeAgentToolExecutor(),
        approval: const AutoApprovalGate(),
        store: store,
        gateway: gateway,
        budget: AgentBudget(),
        onModeSwitchRestart: restarts.add,
      );
      final task = newTask().copyWith(mode: AgentSessionMode.plan);
      await store.appendUserMessage(task.id, '规划');

      await engine.run(task, AgentCancellationToken());

      expect(restarts, isEmpty);
      expect(gateway.last.status, AgentTaskStatus.done);
      final toolEvent = (await store.getEvents(task.id))
          .whereType<ToolCallEvent>()
          .single;
      expect(toolEvent.state, AgentToolCallState.failure);
    });

    test('exit_plan_mode 批准：恢复 prePlanMode、清空标记并回填方案全文', () async {
      final store = InMemoryAgentEventStore();
      final gateway = RecordingTaskGateway();
      final restarts = <AgentTask>[];
      final engine = AgentEngine(
        llm: ScriptedLlm([
          AgentLlmTurn(toolCalls: [
            planCall(kToolExitPlanMode, {'plan': '## 方案\n分两步实现'}),
          ]),
        ]),
        tools: const FakeAgentToolExecutor(),
        approval: const AutoApprovalGate(),
        store: store,
        gateway: gateway,
        budget: AgentBudget(),
        onModeSwitchRestart: restarts.add,
      );
      final task = newTask().copyWith(
        mode: AgentSessionMode.plan,
        prePlanMode: AgentSessionMode.auto,
      );
      await store.appendUserMessage(task.id, '出方案');

      await engine.run(task, AgentCancellationToken());

      expect(gateway.last.mode, AgentSessionMode.auto);
      expect(gateway.last.prePlanMode, isNull);
      expect(gateway.last.status, AgentTaskStatus.running);
      expect(restarts.single.mode, AgentSessionMode.auto);
      final toolEvent = (await store.getEvents(task.id))
          .whereType<ToolCallEvent>()
          .single;
      expect(toolEvent.state, AgentToolCallState.success);
      expect(toolEvent.resultDetail, contains('分两步实现'));
    });

    test('exit_plan_mode 拒绝：留在 plan 模式并把拒绝理由回填给模型', () async {
      final store = InMemoryAgentEventStore();
      final gateway = RecordingTaskGateway();
      final restarts = <AgentTask>[];
      final engine = AgentEngine(
        llm: ScriptedLlm([
          AgentLlmTurn(toolCalls: [
            planCall(kToolExitPlanMode, {'plan': '## 方案 v1'}),
          ]),
          AgentLlmTurn(toolCalls: [
            planCall(kToolFinishTask, {'summary': '修订中'}),
          ]),
        ]),
        tools: const FakeAgentToolExecutor(),
        approval: const DenyingApprovalGate('改用方案 B'),
        store: store,
        gateway: gateway,
        budget: AgentBudget(),
        onModeSwitchRestart: restarts.add,
      );
      final task = newTask().copyWith(mode: AgentSessionMode.plan);
      await store.appendUserMessage(task.id, '出方案');

      await engine.run(task, AgentCancellationToken());

      expect(restarts, isEmpty);
      expect(gateway.last.mode, AgentSessionMode.plan);
      expect(gateway.last.status, AgentTaskStatus.done);
      final toolEvent = (await store.getEvents(task.id))
          .whereType<ToolCallEvent>()
          .first;
      expect(toolEvent.state, AgentToolCallState.denied);
      expect(toolEvent.resultDetail, contains('改用方案 B'));
      expect(toolEvent.resultDetail, contains(kPlanRejectionPrefix));
    });

    test('exit_plan_mode 编辑后批准：以编辑版方案回填并回写参数详情', () async {
      final store = InMemoryAgentEventStore();
      final gateway = RecordingTaskGateway();
      final restarts = <AgentTask>[];
      final engine = AgentEngine(
        llm: ScriptedLlm([
          AgentLlmTurn(toolCalls: [
            planCall(kToolExitPlanMode, {'plan': '## 方案 v1'}),
          ]),
        ]),
        tools: const FakeAgentToolExecutor(),
        approval: const VerdictApprovalGate(
          ApprovalVerdict.approved(editedPlan: '## 方案 v2（用户改）'),
        ),
        store: store,
        gateway: gateway,
        budget: AgentBudget(),
        onModeSwitchRestart: restarts.add,
      );
      final task = newTask().copyWith(mode: AgentSessionMode.plan);
      await store.appendUserMessage(task.id, '出方案');

      await engine.run(task, AgentCancellationToken());

      expect(gateway.last.mode, AgentSessionMode.code);
      expect(restarts, hasLength(1));
      final toolEvent = (await store.getEvents(task.id))
          .whereType<ToolCallEvent>()
          .single;
      expect(toolEvent.state, AgentToolCallState.success);
      expect(toolEvent.resultDetail, contains('## 方案 v2（用户改）'));
      expect(toolEvent.resultDetail, contains('经用户编辑'));
      expect(toolEvent.argsDetail, contains('方案 v2'));
    });

    test('exit_plan_mode 批准并免审执行：切 Auto 模式', () async {
      final store = InMemoryAgentEventStore();
      final gateway = RecordingTaskGateway();
      final restarts = <AgentTask>[];
      final engine = AgentEngine(
        llm: ScriptedLlm([
          AgentLlmTurn(toolCalls: [
            planCall(kToolExitPlanMode, {'plan': '## 方案'}),
          ]),
        ]),
        tools: const FakeAgentToolExecutor(),
        approval: const VerdictApprovalGate(
          ApprovalVerdict.approved(autoAccept: true),
        ),
        store: store,
        gateway: gateway,
        budget: AgentBudget(),
        onModeSwitchRestart: restarts.add,
      );
      final task = newTask().copyWith(
        mode: AgentSessionMode.plan,
        prePlanMode: AgentSessionMode.code,
      );
      await store.appendUserMessage(task.id, '出方案');

      await engine.run(task, AgentCancellationToken());

      expect(gateway.last.mode, AgentSessionMode.auto);
      expect(gateway.last.prePlanMode, isNull);
      expect(restarts.single.mode, AgentSessionMode.auto);
    });

    test('杀进程恢复：挂起中的方案审批不回填失败，直接重建挂起', () async {
      final store = InMemoryAgentEventStore();
      final gateway = RecordingTaskGateway();
      final restarts = <AgentTask>[];
      final task = newTask().copyWith(
        mode: AgentSessionMode.plan,
        prePlanMode: AgentSessionMode.code,
      );
      await store.appendUserMessage(task.id, '出方案');
      // 模拟上次进程死亡时留下的挂起审批事件。
      await store.appendToolCall(
        task.id,
        planCall(kToolExitPlanMode, {'plan': '## 方案（恢复）'}),
        AgentToolCallState.waitingApproval,
      );
      final engine = AgentEngine(
        llm: ScriptedLlm(const []), // 批准后重启，不应再走 LLM
        tools: const FakeAgentToolExecutor(),
        approval: const AutoApprovalGate(),
        store: store,
        gateway: gateway,
        budget: AgentBudget(),
        onModeSwitchRestart: restarts.add,
      );

      await engine.run(task, AgentCancellationToken());

      expect(gateway.last.mode, AgentSessionMode.code);
      expect(restarts, hasLength(1));
      final toolEvent = (await store.getEvents(task.id))
          .whereType<ToolCallEvent>()
          .single;
      expect(toolEvent.state, AgentToolCallState.success);
      expect(toolEvent.resultDetail, contains('## 方案（恢复）'));
    });

    test('杀进程恢复：方案审批被拒绝后留在 plan 继续循环', () async {
      final store = InMemoryAgentEventStore();
      final gateway = RecordingTaskGateway();
      final restarts = <AgentTask>[];
      final task = newTask().copyWith(mode: AgentSessionMode.plan);
      await store.appendUserMessage(task.id, '出方案');
      await store.appendToolCall(
        task.id,
        planCall(kToolExitPlanMode, {'plan': '## 方案'}),
        AgentToolCallState.waitingApproval,
      );
      final engine = AgentEngine(
        llm: ScriptedLlm([
          AgentLlmTurn(toolCalls: [
            planCall(kToolFinishTask, {'summary': '修订中'}),
          ]),
        ]),
        tools: const FakeAgentToolExecutor(),
        approval: const DenyingApprovalGate('换个思路'),
        store: store,
        gateway: gateway,
        budget: AgentBudget(),
        onModeSwitchRestart: restarts.add,
      );

      await engine.run(task, AgentCancellationToken());

      expect(restarts, isEmpty);
      expect(gateway.last.mode, AgentSessionMode.plan);
      expect(gateway.last.status, AgentTaskStatus.done);
      final toolEvent = (await store.getEvents(task.id))
          .whereType<ToolCallEvent>()
          .first;
      expect(toolEvent.state, AgentToolCallState.denied);
      expect(toolEvent.resultDetail, contains('换个思路'));
    });

    test('exit_plan_mode 不在计划模式时按失败回填并继续', () async {
      final store = InMemoryAgentEventStore();
      final gateway = RecordingTaskGateway();
      final engine = AgentEngine(
        llm: ScriptedLlm([
          AgentLlmTurn(toolCalls: [
            planCall(kToolExitPlanMode, {'plan': '方案'}),
          ]),
          AgentLlmTurn(toolCalls: [
            planCall(kToolFinishTask, {'summary': '完成'}),
          ]),
        ]),
        tools: const FakeAgentToolExecutor(),
        approval: const AutoApprovalGate(),
        store: store,
        gateway: gateway,
        budget: AgentBudget(),
      );
      final task = newTask(); // code 模式
      await store.appendUserMessage(task.id, '继续');

      await engine.run(task, AgentCancellationToken());

      expect(gateway.last.status, AgentTaskStatus.done);
      final toolEvent = (await store.getEvents(task.id))
          .whereType<ToolCallEvent>()
          .first;
      expect(toolEvent.state, AgentToolCallState.failure);
      expect(toolEvent.resultDetail, contains('不在计划模式'));
    });
  });
}

/// 按脚本逐轮返回 turn 的 LLM（计划模式流程测试用）。
class ScriptedLlm implements AgentLlmClient {
  ScriptedLlm(this.turns);

  final List<AgentLlmTurn> turns;
  int _index = 0;

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
    if (_index >= turns.length) return const AgentLlmTurn(text: '（无更多脚本）');
    return turns[_index++];
  }

  @override
  Future<String> summarizeForCompaction(
    AgentTask task,
    List<AgentEvent> events, {
    String? customInstructions,
  }) async =>
      '摘要';
}

/// 一律要求审批且返回固定裁决（测编辑后批准 / 免审执行）。
class VerdictApprovalGate implements ApprovalGate {
  const VerdictApprovalGate(this.verdict);

  final ApprovalVerdict verdict;

  @override
  Future<ApprovalRequirement> evaluate(
    AgentToolCallRequest call,
    AgentTask task,
  ) async =>
      ApprovalRequirement.needsUser;

  @override
  Future<ApprovalVerdict> waitForVerdict(
    AgentToolCallRequest call,
    AgentTask task,
    AgentCancellationToken cancel,
  ) async =>
      verdict;
}

/// 一律要求审批且裁决为拒绝（测方案被拒流程）。
class DenyingApprovalGate implements ApprovalGate {
  const DenyingApprovalGate(this.reason);

  final String reason;

  @override
  Future<ApprovalRequirement> evaluate(
    AgentToolCallRequest call,
    AgentTask task,
  ) async =>
      ApprovalRequirement.needsUser;

  @override
  Future<ApprovalVerdict> waitForVerdict(
    AgentToolCallRequest call,
    AgentTask task,
    AgentCancellationToken cancel,
  ) async =>
      ApprovalVerdict.denied(reason);
}
