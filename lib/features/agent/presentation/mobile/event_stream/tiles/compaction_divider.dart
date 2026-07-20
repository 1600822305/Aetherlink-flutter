import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_runner.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// compaction 分隔线：`── ✂ 已压缩 N 条早期事件 ──`，点开看摘要；
/// 最近一次压缩可撤销（撤销后视图恢复原样，分隔线保留作审计痕迹）。
class CompactionDivider extends ConsumerWidget {
  const CompactionDivider({
    required this.event,
    required this.taskId,
    super.key,
  });

  final CompactionEvent event;
  final String taskId;

  /// 只允许撤销最近一次未撤销的压缩：更早的压缩可能已被后续压缩
  /// 覆盖计数，回退语义不清晰，不开放。
  bool _isLatestActive(List<AgentEvent> events) {
    CompactionEvent? latest;
    for (final e in events) {
      if (e is CompactionEvent && !e.revoked) latest = e;
    }
    return latest?.id == event.id;
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤销这次压缩？'),
        content: const Text(
          '摘要不再参与进入模型的上下文，被压缩的原始内容恢复参与。'
          '上下文占用将回到压缩前的水平。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('撤销压缩'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(agentTaskRunnerProvider.notifier)
          .revokeCompaction(taskId, event);
      if (context.mounted) AppToast.success(context, '已撤销压缩');
    } catch (e) {
      if (context.mounted) AppToast.error(context, '撤销失败 · $e');
    }
  }

  void _showSummary(BuildContext context, WidgetRef ref, bool canRevoke) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          event.revoked
              ? '已撤销的压缩（原覆盖 ${event.coveredCount} 条）'
              : '已压缩 ${event.coveredCount} 条早期事件',
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(event.summary),
              if (event.restoredFiles.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '已随摘要恢复 ${event.restoredFiles.length} 个文件快照：\n'
                  '${event.restoredFiles.map((f) => '· ${f.path}').join('\n')}',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (canRevoke)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _revoke(context, ref);
              },
              child: const Text('撤销压缩'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.4);
    final events = ref.watch(agentTaskEventsProvider(taskId)).value ?? const [];
    final canRevoke = !event.revoked && _isLatestActive(events);
    return InkWell(
      onTap: () => _showSummary(context, ref, canRevoke),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Divider(color: muted.withValues(alpha: 0.3))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                event.revoked
                    ? '✂ 压缩已撤销（原覆盖 ${event.coveredCount} 条）'
                    : '✂ 已压缩 ${event.coveredCount} 条早期事件'
                        '${canRevoke ? ' · 可撤销' : ''}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: muted,
                  decoration:
                      event.revoked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Expanded(child: Divider(color: muted.withValues(alpha: 0.3))),
          ],
        ),
      ),
    );
  }
}
