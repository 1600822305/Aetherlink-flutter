import 'dart:convert';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_budget.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/approval_gate.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/loop/task_transition.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 方案审批（exit_plan_mode）的挂起 + 裁决处理：批准后恢复
/// prePlanMode（autoAccept 则切 Auto 免审）并请求重启（resolve 返回
/// true，调用方应 return）；拒绝后留在 Plan 模式回填理由继续循环
/// （返回 false）。启动恢复与循环内两个入口共用。
class PlanApprovalFlow {
  PlanApprovalFlow({
    required this.approval,
    required this.budget,
    required this.tx,
    this.onNotification,
    this.onModeSwitchRestart,
  });

  final ApprovalGate approval;
  final AgentBudget budget;
  final TaskTransitions tx;
  final void Function(String message, String type)? onNotification;
  final void Function(AgentTask task)? onModeSwitchRestart;

  Future<bool> resolve(
    ToolCallEvent event,
    AgentToolCallRequest call,
    String plan,
    AgentCancellationToken cancel,
  ) async {
    final store = tx.store;
    await store.appendStatusChange(tx.current.id, '等待方案批准');
    var current = await tx.save(
      tx.current.copyWith(
        status: AgentTaskStatus.waitingApproval,
        updatedAt: DateTime.now(),
        lastEventSummary: '等待方案批准',
      ),
    );
    onNotification?.call('等待方案批准', 'approval');
    final verdict = await approval.waitForVerdict(call, current, cancel);
    if (!verdict.approved) {
      await store.updateToolCall(
        current.id,
        event,
        state: AgentToolCallState.denied,
        resultSummary: '用户拒绝方案',
        resultDetail: '$kPlanRejectionPrefix\n${verdict.reason}',
      );
      await store.appendStatusChange(current.id, '方案被拒绝，继续修订');
      await tx.save(
        current.copyWith(
          status: AgentTaskStatus.running,
          updatedAt: DateTime.now(),
          lastEventSummary: '方案被拒绝，继续修订',
        ),
      );
      budget.recordToolResult(ok: false);
      cancel.consumeToolInterrupt();
      return false;
    }
    final edited = verdict.editedPlan?.trim();
    final wasEdited = edited != null && edited.isNotEmpty && edited != plan;
    final effectivePlan = wasEdited ? edited : plan;
    final restored = verdict.autoAccept
        ? AgentSessionMode.auto
        : (current.prePlanMode ?? AgentSessionMode.code);
    await store.updateToolCall(
      current.id,
      event,
      state: AgentToolCallState.success,
      // 编辑后批准：批准版方案回写参数详情，UI/重放都以它为准。
      argsDetail: wasEdited ? jsonEncode({'plan': effectivePlan}) : null,
      resultSummary: '方案已批准',
      resultDetail:
          '用户已批准方案${wasEdited ? '（经用户编辑，以下为最终版本）' : ''}，'
          '现在可以开始实现。先用 update_plan 同步执行计划，然后按方案执行。'
          '\n\n## 已批准的方案：\n$effectivePlan',
    );
    await store.appendStatusChange(
      current.id,
      '模式切换：plan → ${restored.name}'
      '（方案已批准${verdict.autoAccept ? '，免审执行' : ''}）',
    );
    current = await tx.save(
      current.copyWith(
        status: AgentTaskStatus.running,
        mode: restored,
        clearPrePlanMode: true,
        updatedAt: DateTime.now(),
        lastEventSummary: '方案已批准，开始执行',
      ),
    );
    cancel.consumeToolInterrupt();
    onModeSwitchRestart?.call(current);
    return true;
  }
}
