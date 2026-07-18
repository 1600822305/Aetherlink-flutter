// 智能体审批挂起登记处：引擎侧 waitForVerdict 挂起在这里，
// 事件流审批卡按钮 respond 裁决。每个任务同一时刻至多一条挂起
// （引擎逐个执行工具），所以按 taskId 键控。挂起无超时（初稿 §4.2：
// 用户可能锁屏离场，超时拒绝会毁任务）。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_permission_rules.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/data/agent_notification_service.dart';
import 'package:aetherlink_flutter/features/agent/domain/permission_rule.dart';

/// 用户批准时的授权范围（审批卡三档，初稿 §6.3）。
enum AgentApprovalScope {
  /// 只放行本次调用。
  once,

  /// 本任务内此工具不再询问（会话临时规则，随任务结束失效）。
  taskTool,

  /// 永久加入工具授权白名单（持久化，越界命令仍强制审批）。
  whitelist,

  /// 本任务内允许本次命中的 pattern（如 `npm run *`，随任务结束失效）。
  taskPatterns,

  /// 永久允许本次命中的 pattern（写入用户全局规则）。
  alwaysPatterns,

  /// 永久禁止本次命中的 pattern（配合拒绝，写入用户全局 deny 规则）。
  denyPatterns,
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

/// 审批裁决 → 要落的授权规则（纯函数）：patterns 为空时按整工具（`*`）。
/// session 层规则进会话临时层，userGlobal 层规则持久化。
List<PermissionRule> approvalGrantRules({
  required AgentApprovalScope scope,
  required bool approved,
  required String permission,
  required List<String> patterns,
}) {
  final effective = patterns.isEmpty ? const ['*'] : patterns;
  switch (scope) {
    case AgentApprovalScope.once:
    case AgentApprovalScope.whitelist:
      return const [];
    case AgentApprovalScope.taskTool:
      if (!approved) return const [];
      return [
        PermissionRule(
          permission: permission,
          action: PermissionAction.allow,
          layer: PermissionRuleLayer.session,
        ),
      ];
    case AgentApprovalScope.taskPatterns:
      if (!approved) return const [];
      return [
        for (final pattern in effective)
          PermissionRule(
            permission: permission,
            pattern: pattern,
            action: PermissionAction.allow,
            layer: PermissionRuleLayer.session,
          ),
      ];
    case AgentApprovalScope.alwaysPatterns:
      if (!approved) return const [];
      return [
        for (final pattern in effective)
          PermissionRule(
            permission: permission,
            pattern: pattern,
            action: PermissionAction.allow,
            layer: PermissionRuleLayer.userGlobal,
          ),
      ];
    case AgentApprovalScope.denyPatterns:
      if (approved) return const [];
      return [
        for (final pattern in effective)
          PermissionRule(
            permission: permission,
            pattern: pattern,
            action: PermissionAction.deny,
            layer: PermissionRuleLayer.userGlobal,
          ),
      ];
  }
}

/// 一条挂起中的审批请求（UI 据此渲染可交互的审批卡）。
/// [permission] / [alwaysPatterns] 由审批门映射好传入：批准的授权范围
/// （taskTool / whitelist）按它们落成规则。
class PendingAgentApproval {
  PendingAgentApproval({
    required this.taskId,
    required this.call,
    this.permission = '',
    this.alwaysPatterns = const [],
  });

  final String taskId;
  final AgentToolCallRequest call;
  final String permission;
  final List<String> alwaysPatterns;
  final Completer<AgentApprovalDecision> completer =
      Completer<AgentApprovalDecision>();
}

class AgentApprovalRegistryNotifier
    extends Notifier<Map<String, PendingAgentApproval>> {
  /// 会话临时规则层：taskId → 本任务内生效的授权规则（随任务结束丢弃）。
  final Map<String, List<PermissionRule>> _sessionRules = {};

  @override
  Map<String, PendingAgentApproval> build() {
    // 审批通知点击 → 选中对应话题（审批卡就在事件流里）。
    AgentNotificationService().onSelectTask = (taskId) =>
        ref.read(selectedAgentTaskIdProvider.notifier).select(taskId);
    return const {};
  }

  /// 引擎挂起等待用户裁决（同任务旧挂起先按拒绝清掉，防御性兜底）。
  Future<AgentApprovalDecision> request(
    String taskId,
    AgentToolCallRequest call, {
    String permission = '',
    List<String> alwaysPatterns = const [],
  }) {
    respond(
      taskId,
      const AgentApprovalDecision(approved: false, reason: '被新的审批请求顶替'),
    );
    final pending = PendingAgentApproval(
      taskId: taskId,
      call: call,
      permission: permission,
      alwaysPatterns: alwaysPatterns,
    );
    state = {...state, taskId: pending};
    // App 在后台时发系统通知提醒审批（初稿 §6.3）。
    final task = ref
        .read(agentTasksProvider)
        .where((t) => t.id == taskId)
        .firstOrNull;
    unawaited(AgentNotificationService().showApprovalRequest(
      taskId: taskId,
      taskTitle: task?.title ?? '智能体任务',
      toolName: call.name,
    ));
    return pending.completer.future;
  }

  /// 审批卡按钮 / 取消轮询调用：完成挂起并从登记处移除。
  void respond(String taskId, AgentApprovalDecision decision) {
    final pending = state[taskId];
    if (pending == null) return;
    state = Map.of(state)..remove(taskId);
    unawaited(AgentNotificationService().cancelApprovalRequest(taskId));
    final grants = approvalGrantRules(
      scope: decision.scope,
      approved: decision.approved,
      permission: pending.permission.isEmpty
          ? pending.call.name
          : pending.permission,
      patterns: pending.alwaysPatterns,
    );
    for (final rule in grants) {
      if (rule.layer == PermissionRuleLayer.session) {
        (_sessionRules[taskId] ??= <PermissionRule>[]).add(rule);
      } else {
        ref.read(agentPermissionRulesProvider.notifier).add(rule);
      }
    }
    if (!pending.completer.isCompleted) pending.completer.complete(decision);
  }

  /// 本任务内生效的会话临时规则层（审批门拼进规则引擎的最高优先级层）。
  List<PermissionRule> sessionRules(String taskId) =>
      _sessionRules[taskId] ?? const [];

  /// 任务终态（done/cancelled/failed）时清掉会话临时规则，
  /// 保证「随任务结束失效」的语义并避免 map 只增不减。
  void clearTaskGrace(String taskId) => _sessionRules.remove(taskId);
}

final agentApprovalRegistryProvider = NotifierProvider<
    AgentApprovalRegistryNotifier, Map<String, PendingAgentApproval>>(
  AgentApprovalRegistryNotifier.new,
);
