import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_budget.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_subagent.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_executor.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/approval_gate.dart';
import 'package:aetherlink_flutter/features/agent/data/datasources/local/agent_converters.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

import 'engine/agent_engine_test.dart'
    show InMemoryAgentEventStore, RecordingTaskGateway, newTask;

/// 第一轮派两个子代理，第二轮收尾（测同轮并行派发）。
class TwoSpawnLlm implements AgentLlmClient {
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
    if (_round == 1) {
      return AgentLlmTurn(
        toolCalls: [
          AgentToolCallRequest(
            id: 'call-spawn-1',
            name: kToolSpawnSubagent,
            argsJson: jsonEncode({
              'type': 'explore',
              'prompt': '调研 A 模块',
              'description': '调研 A',
            }),
            argSummary: 'explore 调研 A',
          ),
          AgentToolCallRequest(
            id: 'call-spawn-2',
            name: kToolSpawnSubagent,
            argsJson: jsonEncode({
              'type': 'explore',
              'prompt': '调研 B 模块',
              'description': '调研 B',
            }),
            argSummary: 'explore 调研 B',
          ),
        ],
      );
    }
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

  @override
  Future<String> summarizeForCompaction(
    AgentTask task,
    List<AgentEvent> events,
  ) async =>
      '摘要';
}

class NoToolExecutor implements AgentToolExecutor {
  @override
  Future<AgentToolResult> execute(
    AgentToolCallRequest call,
    AgentCancellationToken cancel,
  ) async =>
      const AgentToolResult(ok: false, summary: '不应走 executor ✗');
}

/// 记录并发度的假启动器：两个都启动后才放行（验证 Future.wait 并行）。
class ParallelProbeLauncher implements AgentSubagentLauncher {
  int launched = 0;
  final Completer<void> bothStarted = Completer<void>();
  final List<String> toolEventIds = [];

  @override
  Future<AgentToolResult> launch({
    required AgentTask parent,
    required AgentToolCallRequest call,
    required String toolEventId,
    required AgentCancellationToken cancel,
  }) async {
    launched++;
    toolEventIds.add(toolEventId);
    if (launched == 2 && !bothStarted.isCompleted) {
      bothStarted.complete();
    }
    // 两个都启动了才返回：若是串行执行会死锁超时。
    await bothStarted.future.timeout(const Duration(seconds: 5));
    final args = jsonDecode(call.argsJson) as Map<String, dynamic>;
    return AgentToolResult(
      ok: true,
      summary: '子代理完成 · 3 轮',
      detail: '结论：${args['prompt']}',
    );
  }
}

void main() {
  test('spawn_subagent 工具定义：schema 必填 type/prompt', () {
    expect(kSpawnSubagentToolDefinition.name, kToolSpawnSubagent);
    final schema = kSpawnSubagentToolDefinition.inputSchema;
    final props = schema['properties'] as Map<String, dynamic>;
    expect(
      props.keys,
      containsAll(['type', 'prompt', 'description', 'background']),
    );
    expect(schema['required'], containsAll(['type', 'prompt']));
  });

  test('子任务 id 派生规则稳定', () {
    expect(subagentTaskIdFor('tc-1'), 'sub-tc-1');
  });

  test('AgentTask.parentTaskId 持久化 round trip', () {
    const converter = AgentTaskConverter();
    final task = newTask();
    final child = AgentTask(
      id: 'sub-1',
      profileId: task.profileId,
      title: '子任务',
      workspaceId: task.workspaceId,
      workspaceName: task.workspaceName,
      status: AgentTaskStatus.running,
      mode: AgentSessionMode.ask,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
      parentTaskId: task.id,
    );
    final decoded = converter.fromSql(converter.toSql(child));
    expect(decoded.parentTaskId, task.id);
    expect(decoded.isSubtask, isTrue);
    // copyWith 不丢父子关系。
    expect(decoded.copyWith(status: AgentTaskStatus.done).parentTaskId,
        task.id);
    // 旧数据无该字段 → 空串（非子任务）。
    expect(converter.fromSql(converter.toSql(task)).isSubtask, isFalse);
  });

  test('同轮两个 spawn_subagent 并行执行，结果回填父事件流', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    final launcher = ParallelProbeLauncher();
    final engine = AgentEngine(
      llm: TwoSpawnLlm(),
      tools: NoToolExecutor(),
      approval: const AutoApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(),
      subagents: launcher,
    );
    final task = newTask();
    await store.appendUserMessage(task.id, '并行调研 A 和 B');

    await engine.run(task, AgentCancellationToken());

    expect(gateway.last.status, AgentTaskStatus.done);
    expect(launcher.launched, 2);
    final spawns = (await store.getEvents(task.id))
        .whereType<ToolCallEvent>()
        .where((e) => e.toolName == kToolSpawnSubagent)
        .toList();
    expect(spawns.length, 2);
    for (final e in spawns) {
      expect(e.state, AgentToolCallState.success);
      expect(e.resultSummary, contains('子代理完成'));
      expect(e.resultDetail, contains('结论'));
      expect(e.elapsed, isNotNull);
    }
    // toolEventId 与父事件一一对应（UI 由此定位子事件流）。
    expect(launcher.toolEventIds.toSet(), {for (final e in spawns) e.id});
    // 子代理中间过程不进父事件流（父级只有回填的工具结果）。
    expect(
      (await store.getEvents(task.id))
          .whereType<AssistantTextEvent>()
          .where((e) => e.text.contains('调研')),
      isEmpty,
    );
  });

  test('未注入启动器（子代理内不可嵌套）→ spawn 按失败回填', () async {
    final store = InMemoryAgentEventStore();
    final gateway = RecordingTaskGateway();
    final engine = AgentEngine(
      llm: TwoSpawnLlm(),
      tools: NoToolExecutor(),
      approval: const AutoApprovalGate(),
      store: store,
      gateway: gateway,
      budget: AgentBudget(),
    );
    final task = newTask();
    await store.appendUserMessage(task.id, '并行调研 A 和 B');

    await engine.run(task, AgentCancellationToken());

    expect(gateway.last.status, AgentTaskStatus.done);
    final spawns = (await store.getEvents(task.id))
        .whereType<ToolCallEvent>()
        .where((e) => e.toolName == kToolSpawnSubagent)
        .toList();
    expect(spawns.length, 2);
    for (final e in spawns) {
      expect(e.state, AgentToolCallState.failure);
      expect(e.resultSummary, contains('不可用'));
    }
  });
}
