import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';

/// 状态迁移行：◆ 节点 + 弱化文字（出错/暂停/恢复……）。
class StatusChangeTile extends StatelessWidget {
  const StatusChangeTile({required this.event, super.key});

  final StatusChangeEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    return EventRail(
      node: Icon(LucideIcons.diamond, size: 12, color: muted),
      child: Text(
        event.description,
        style: theme.textTheme.labelSmall?.copyWith(color: muted),
      ),
    );
  }
}
