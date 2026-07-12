import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_runner.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 检查点标记行（初稿 §5.5 P2）：🏳 节点 + 弱化文字 + 「回滚」按钮。
/// 回滚只还原工作区文件到该消息之前的状态，对话记录不受影响；
/// 回滚前当前状态会自动落为新检查点（可再回滚回来）。
class CheckpointTile extends ConsumerStatefulWidget {
  const CheckpointTile({required this.event, required this.taskId, super.key});

  final CheckpointEvent event;
  final String taskId;

  @override
  ConsumerState<CheckpointTile> createState() => _CheckpointTileState();
}

class _CheckpointTileState extends ConsumerState<CheckpointTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final running =
        ref.watch(agentTaskRunnerProvider).contains(widget.taskId);
    final label = widget.event.label.isEmpty ? '检查点' : widget.event.label;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(LucideIcons.flag, size: 12, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '检查点 · $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: running ? null : _confirmRollback,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('回滚', style: theme.textTheme.labelSmall),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRollback() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('回滚到此检查点？'),
        content: const Text(
          '工作区文件将还原到该消息之前的状态（含终端命令产生的改动）；'
          '对话记录不受影响。\n\n回滚前会自动把当前状态保存为新检查点，'
          '可以再回滚回来。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('回滚'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final task = ref
        .read(agentTasksProvider)
        .where((t) => t.id == widget.taskId)
        .firstOrNull;
    if (task == null) return;

    setState(() => _busy = true);
    String? error;
    try {
      await ref
          .read(agentTaskRunnerProvider.notifier)
          .rollbackToCheckpoint(task, widget.event);
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error == null ? '已回滚到检查点' : '回滚失败：$error'),
    ));
  }
}
