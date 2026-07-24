import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 恢复语义（L7）：上次进程死亡时半途的工具调用（仍 running /
/// waitingApproval）按失败回填，重放时模型可重新发起并重过审批。
/// [keepPendingPlanApproval] 时挂起中的方案审批（exit_plan_mode
/// waitingApproval）不回填，原样返回给调用方重建挂起。
Future<ToolCallEvent?> backfillInterruptedToolCalls(
  AgentEventStore store,
  String taskId, {
  bool keepPendingPlanApproval = false,
}) async {
  final events = await store.getEvents(taskId);
  ToolCallEvent? pendingPlanApproval;
  for (final event in events.whereType<ToolCallEvent>()) {
    if (event.state == AgentToolCallState.running ||
        event.state == AgentToolCallState.waitingApproval) {
      if (keepPendingPlanApproval &&
          event.state == AgentToolCallState.waitingApproval &&
          event.toolName == kToolExitPlanMode) {
        pendingPlanApproval = event;
        continue;
      }
      await store.updateToolCall(
        taskId,
        event,
        state: AgentToolCallState.failure,
        resultSummary: '进程中断，未执行完成',
      );
    }
  }
  return pendingPlanApproval;
}
