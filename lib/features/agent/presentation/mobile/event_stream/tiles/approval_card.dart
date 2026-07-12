import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';

/// 审批卡（内嵌事件流）：摘要 + 批准/拒绝/白名单▾（UI 稿 §五）。
/// 按钮动作接真引擎时补；UI 阶段只占位。
class ApprovalCard extends StatelessWidget {
  const ApprovalCard({required this.event, super.key});

  final ToolCallEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const orange = Colors.orange;
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
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('批准'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('拒绝'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('白名单 ▾'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
