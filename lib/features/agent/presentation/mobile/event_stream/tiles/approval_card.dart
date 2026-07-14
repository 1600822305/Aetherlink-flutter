import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_approval_registry.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';

/// 审批卡（内嵌事件流）：摘要 + 批准/拒绝/白名单▾（UI 稿 §五）。
/// 按钮接 [agentApprovalRegistryProvider]：引擎挂起在登记处等裁决，
/// 白名单▾ 提供「本任务内不再询问」与「永久加入白名单」两档（初稿 §6.3）。
/// 无挂起（如重启后的历史卡）时按钮禁用，续跑任务会重新发起审批。
class ApprovalCard extends ConsumerWidget {
  const ApprovalCard({required this.event, required this.taskId, super.key});

  final ToolCallEvent event;
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    const orange = Colors.orange;
    final pending = ref.watch(agentApprovalRegistryProvider)[taskId];
    final active = pending != null && pending.call.name == event.toolName;

    void respond(AgentApprovalDecision decision) {
      ref
          .read(agentApprovalRegistryProvider.notifier)
          .respond(taskId, decision);
    }

    return EventRail(
      node: const Icon(LucideIcons.triangleAlert, size: 14, color: orange),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: orange.withValues(alpha: 0.5)),
          color: orange.withValues(alpha: 0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠ 等待授权',
              style: theme.textTheme.labelMedium?.copyWith(
                color: orange,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${event.toolName} ${event.argSummary}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton(
                  onPressed: active
                      ? () =>
                            respond(const AgentApprovalDecision(approved: true))
                      : null,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('批准'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: active
                      ? () => respond(
                          const AgentApprovalDecision(
                            approved: false,
                            reason: '用户拒绝',
                          ),
                        )
                      : null,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('拒绝'),
                ),
                const SizedBox(width: 8),
                _WhitelistMenuButton(
                  enabled: active,
                  onSelected: (scope) => respond(
                    AgentApprovalDecision(approved: true, scope: scope),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 「白名单 ▾」两档快捷入口：批准并附带授权范围。
class _WhitelistMenuButton extends StatelessWidget {
  const _WhitelistMenuButton({required this.enabled, required this.onSelected});

  final bool enabled;
  final void Function(AgentApprovalScope scope) onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AgentApprovalScope>(
      popUpAnimationStyle: AnimationStyle.noAnimation,
      enabled: enabled,
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: AgentApprovalScope.taskTool,
          child: Text('批准，本任务内此工具不再询问'),
        ),
        PopupMenuItem(
          value: AgentApprovalScope.whitelist,
          child: Text('批准，永久加入白名单'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          '白名单 ▾',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: enabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).disabledColor,
          ),
        ),
      ),
    );
  }
}
