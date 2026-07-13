import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tool_detail_sheet.dart';

/// 工具行（collapsed 单行）：图标+名称+关键参数+结果摘要；
/// 点击 → 底部抽屉看完整参数/输出。
class ToolRow extends StatelessWidget {
  const ToolRow({required this.event, required this.taskId, super.key});

  final ToolCallEvent event;
  final String taskId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    final (icon, iconColor) = switch (event.state) {
      AgentToolCallState.running => (LucideIcons.loaderCircle, cs.primary),
      AgentToolCallState.success => (LucideIcons.circleCheck, Colors.green),
      AgentToolCallState.failure => (LucideIcons.circleX, cs.error),
      AgentToolCallState.denied => (LucideIcons.ban, muted),
      AgentToolCallState.waitingApproval => (
        LucideIcons.circleAlert,
        Colors.orange,
      ),
    };
    return EventRail(
      node: event.state == AgentToolCallState.running
          ? SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            )
          : Icon(icon, size: 14, color: iconColor),
      child: InkWell(
        onTap: () => showToolDetailSheet(context, event, taskId: taskId),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    event.toolName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event.argSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: muted,
                      ),
                    ),
                  ),
                ],
              ),
              if (event.resultSummary.isNotEmpty)
                Text(
                  '↳ ${event.resultSummary}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: event.state == AgentToolCallState.failure
                        ? cs.error
                        : muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
