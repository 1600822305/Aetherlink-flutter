import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';

/// 计划更新行：▤ 计划已更新 3/5 · 当前：xxx（弱化单行，
/// 让 update_plan 在时间线里有即时反馈；完整清单看顶部计划纪要条）。
class PlanUpdateTile extends StatelessWidget {
  const PlanUpdateTile({required this.event, super.key});

  final PlanUpdateEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final items = event.items;
    final done = items
        .where((i) => i.status == AgentPlanItemStatus.completed)
        .length;
    final current = items
        .where((i) => i.status == AgentPlanItemStatus.inProgress)
        .firstOrNull;
    final label = current != null
        ? '计划已更新 $done/${items.length} · 当前：${current.content}'
        : '计划已更新 $done/${items.length}';
    return EventRail(
      node: Icon(LucideIcons.listTodo, size: 13, color: muted),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(color: muted),
      ),
    );
  }
}
