import 'package:aetherlink_flutter/features/agent/application/engine/agent_budget.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_subagent.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_executor.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 同批子代理并行跑（对标 Cursor：同轮多个 spawn 并行，父级阻塞等
/// 全部结果）。派生本身不过审批门：子代理内部的每个工具调用仍走
/// 自身的审批链。[launcher] 为 null = 本层不支持派生（子代理不嵌套）。
Future<void> runSubagentBatch({
  required AgentEventStore store,
  required AgentBudget budget,
  required AgentSubagentLauncher? launcher,
  required AgentTask current,
  required List<AgentToolCallRequest> batch,
  required AgentCancellationToken cancel,
}) async {
  final events = <ToolCallEvent>[];
  for (final call in batch) {
    events.add(
      await store.appendToolCall(current.id, call, AgentToolCallState.running),
    );
  }
  if (launcher == null) {
    for (final event in events) {
      await store.updateToolCall(
        current.id,
        event,
        state: AgentToolCallState.failure,
        resultSummary: '子代理不可用 ✗',
        resultDetail: '当前上下文不支持派生子代理（子代理内不可再嵌套）',
      );
      budget.recordToolResult(ok: false);
    }
    return;
  }
  await Future.wait([
    for (var i = 0; i < batch.length; i++)
      () async {
        final stopwatch = Stopwatch()..start();
        AgentToolResult result;
        try {
          result = await launcher.launch(
            parent: current,
            call: batch[i],
            toolEventId: events[i].id,
            cancel: cancel,
          );
        } catch (e) {
          result = AgentToolResult(ok: false, summary: '子代理异常 ✗', detail: '$e');
        }
        stopwatch.stop();
        await store.updateToolCall(
          current.id,
          events[i],
          state: result.ok
              ? AgentToolCallState.success
              : AgentToolCallState.failure,
          resultSummary: result.summary,
          resultDetail: result.detail,
          elapsed: stopwatch.elapsed,
        );
        budget.recordToolResult(ok: result.ok);
      }(),
  ]);
}
