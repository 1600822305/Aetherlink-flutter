import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_runner.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 检查点标记行（初稿 §5.5 P2）：🏳 节点 + 弱化文字 + 「回滚」按钮。
/// 点回滚先弹预览面板：列出会被还原/删除/恢复的文件（可点开看 diff），
/// 确认后才执行。回滚只还原工作区文件，对话记录不受影响；
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
    final running = ref.watch(agentTaskRunnerProvider).contains(widget.taskId);
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
              onPressed: running ? null : _startRollback,
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

  Future<void> _startRollback() async {
    final task = ref
        .read(agentTasksProvider)
        .where((t) => t.id == widget.taskId)
        .firstOrNull;
    if (task == null) return;

    setState(() => _busy = true);
    List<RollbackFileChange> preview;
    try {
      preview = await ref
          .read(agentTaskRunnerProvider.notifier)
          .previewRollback(task, widget.event);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('回滚预览失败：$e');
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _RollbackPreviewSheet(
        label: widget.event.label,
        files: preview,
        loadDiff: (path) => ref
            .read(agentTaskRunnerProvider.notifier)
            .rollbackFileDiff(task, widget.event, path),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    String? error;
    AgentRollbackResult? result;
    try {
      result = await ref
          .read(agentTaskRunnerProvider.notifier)
          .rollbackToCheckpoint(task, widget.event);
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    _snack(
      error == null ? '已回滚到检查点，还原 ${result!.files.length} 个文件' : '回滚失败：$error',
    );
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

/// 回滚预览面板：列出会被触达的文件（可点开看 diff），底部确认/取消。
class _RollbackPreviewSheet extends StatelessWidget {
  const _RollbackPreviewSheet({
    required this.label,
    required this.files,
    required this.loadDiff,
  });

  final String label;
  final List<RollbackFileChange> files;
  final Future<String> Function(String path) loadDiff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final maxHeight = MediaQuery.of(context).size.height * 0.75;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('回滚到此检查点', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                label.isEmpty ? '工作区文件将还原到该消息之前的状态' : '还原到「$label」之前的状态',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              const SizedBox(height: 12),
              if (files.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      '未检测到文件差异，仍可执行回滚以确保工作区与检查点一致',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
                )
              else ...[
                Text(
                  '将触达 ${files.length} 个文件（点文件可看改动内容）：',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: files.length,
                    itemBuilder: (context, i) =>
                        _FileRow(file: files[i], loadDiff: loadDiff),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '对话记录不受影响；回滚前会自动保存当前状态',
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      files.isEmpty ? '回滚' : '回滚 ${files.length} 个文件',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, required this.loadDiff});

  final RollbackFileChange file;
  final Future<String> Function(String path) loadDiff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (badge, color, action) = switch (file.kind) {
      RollbackFileKind.added => ('A', Colors.green, '回滚将删除'),
      RollbackFileKind.modified => ('M', Colors.orange, '回滚将还原'),
      RollbackFileKind.deleted => ('D', Colors.red, '回滚将恢复'),
    };
    return InkWell(
      onTap: () => _showDiff(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                file.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              action,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDiff(BuildContext context) async {
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          file.path.split('/').last,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<String>(
            future: loadDiff(file.path),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('取 diff 失败：${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final diff = snapshot.data!.trim();
              if (diff.isEmpty) {
                return const Text('（检查点之后新增的未跟踪文件，回滚将直接删除，无逐行 diff）');
              }
              return SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    diff,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
