// 智能体审批挂起登记处：引擎侧 waitForVerdict 挂起在这里，
// 事件流审批卡按钮 respond 裁决。每个任务同一时刻至多一条挂起
// （引擎逐个执行工具），所以按 taskId 键控。挂起无超时（初稿 §4.2：
// 用户可能锁屏离场，超时拒绝会毁任务）。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';

/// 用户批准时的授权范围（审批卡三档，初稿 §6.3）。
enum AgentApprovalScope {
  /// 只放行本次调用。
  once,

  /// 本任务内此工具不再询问（运行级宽限，随任务结束失效）。
  taskTool,

  /// 永久加入工具授权白名单（持久化，越界命令仍强制审批）。
  whitelist,
}

/// 审批卡上的用户裁决。
class AgentApprovalDecision {
  const AgentApprovalDecision({
    required this.approved,
    this.reason = '',
    this.scope = AgentApprovalScope.once,
  });

  final bool approved;
  final String reason;
  final AgentApprovalScope scope;
}

/// 一条挂起中的审批请求（UI 据此渲染可交互的审批卡）。
class PendingAgentApproval {
  PendingAgentApproval({required this.taskId, required this.call});

  final String taskId;
  final AgentToolCallRequest call;
  final Completer<AgentApprovalDecision> completer =
      Completer<AgentApprovalDecision>();
}

class AgentApprovalRegistryNotifier
    extends Notifier<Map<String, PendingAgentApproval>> {
  /// 运行级宽限：taskId → 本任务内免审的工具名集合。
  final Map<String, Set<String>> _taskGrace = {};

  @override
  Map<String, PendingAgentApproval> build() => const {};

  /// 引擎挂起等待用户裁决（同任务旧挂起先按拒绝清掉，防御性兜底）。
  Future<AgentApprovalDecision> request(
    String taskId,
    AgentToolCallRequest call,
  ) {
    respond(
      taskId,
      const AgentApprovalDecision(approved: false, reason: '被新的审批请求顶替'),
    );
    final pending = PendingAgentApproval(taskId: taskId, call: call);
    state = {...state, taskId: pending};
    return pending.completer.future;
  }

  /// 审批卡按钮 / 取消轮询调用：完成挂起并从登记处移除。
  void respond(String taskId, AgentApprovalDecision decision) {
    final pending = state[taskId];
    if (pending == null) return;
    state = Map.of(state)..remove(taskId);
    if (decision.approved && decision.scope == AgentApprovalScope.taskTool) {
      (_taskGrace[taskId] ??= <String>{}).add(pending.call.name);
    }
    if (!pending.completer.isCompleted) pending.completer.complete(decision);
  }

  bool hasTaskGrace(String taskId, String toolName) =>
      _taskGrace[taskId]?.contains(toolName) ?? false;
}

final agentApprovalRegistryProvider = NotifierProvider<
    AgentApprovalRegistryNotifier, Map<String, PendingAgentApproval>>(
  AgentApprovalRegistryNotifier.new,
);
