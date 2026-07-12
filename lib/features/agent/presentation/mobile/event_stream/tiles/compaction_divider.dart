import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// compaction 分隔线：`── ✂ 已压缩 N 条早期事件 ──`，点开看摘要。
class CompactionDivider extends StatelessWidget {
  const CompactionDivider({required this.event, super.key});

  final CompactionEvent event;

  void _showSummary(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('已压缩 ${event.coveredCount} 条早期事件'),
        content: SingleChildScrollView(child: Text(event.summary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.4);
    return InkWell(
      onTap: () => _showSummary(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Divider(color: muted.withValues(alpha: 0.3))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '✂ 已压缩 ${event.coveredCount} 条早期事件',
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ),
            Expanded(child: Divider(color: muted.withValues(alpha: 0.3))),
          ],
        ),
      ),
    );
  }
}
