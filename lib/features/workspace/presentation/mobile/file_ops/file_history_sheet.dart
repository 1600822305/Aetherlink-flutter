// 文件历史面板（长按菜单「文件历史」）：应用级 checkpoint 快照列表，
// 支持与当前内容对比、恢复到某个快照、删除单条记录。与 Git 无关，任何
// 后端（含 SAF）可用。纯展示逻辑，数据来自 WorkspaceFileHistoryStore。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_file_history.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_diff_view.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// Opens the file-history bottom sheet for [entry].
Future<void> showFileHistorySheet(
  BuildContext context,
  WidgetRef ref, {
  required WorkspaceBackend backend,
  required WorkspaceEntry entry,
}) async {
  final store = await ref.read(workspaceFileHistoryProvider.future);
  if (!context.mounted) return;
  if (store == null) {
    AppToast.info(context, '当前没有打开的工作区');
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _FileHistorySheet(
      store: store,
      backend: backend,
      entry: entry,
    ),
  );
}

class _FileHistorySheet extends StatefulWidget {
  const _FileHistorySheet({
    required this.store,
    required this.backend,
    required this.entry,
  });

  final WorkspaceFileHistoryStore store;
  final WorkspaceBackend backend;
  final WorkspaceEntry entry;

  @override
  State<_FileHistorySheet> createState() => _FileHistorySheetState();
}

class _FileHistorySheetState extends State<_FileHistorySheet> {
  List<FileHistorySnapshot>? _snapshots;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final snapshots = await widget.store.snapshotsFor(widget.entry.path);
    if (mounted) setState(() => _snapshots = snapshots);
  }

  Future<void> _showDiff(FileHistorySnapshot snapshot) async {
    final old = await widget.store.read(snapshot);
    if (!mounted) return;
    if (old == null) {
      AppToast.error(context, '快照内容已丢失');
      return;
    }
    String current;
    try {
      current = await widget.backend.readFile(widget.entry.path);
    } catch (e) {
      if (mounted) AppToast.error(context, '读取当前内容失败 · $e');
      return;
    }
    if (!mounted) return;
    await showReadOnlyDiffSheet(
      context,
      fileName: widget.entry.name,
      subtitle: '红色 - 为 ${_timeLabel(snapshot.savedAt)} 的快照，'
          '绿色 + 为当前内容',
      oldText: old,
      newText: current,
    );
  }

  Future<void> _restore(FileHistorySnapshot snapshot) async {
    if (_busy || !widget.backend.capabilities.canWrite) return;
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复到此版本？'),
        content: Text(
          '「${widget.entry.name}」将恢复为 ${_timeLabel(snapshot.savedAt)} '
          '的快照内容。当前内容会先存入历史，可再恢复回来。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final content = await widget.store.read(snapshot);
      if (content == null) {
        if (mounted) AppToast.error(context, '快照内容已丢失');
        return;
      }
      // 先把当前内容也存进历史，恢复本身可再回滚。
      try {
        final current = await widget.backend.readFile(widget.entry.path);
        await widget.store
            .record(widget.entry.path, current, source: '恢复前');
      } catch (_) {}
      await widget.backend.writeFile(widget.entry.path, content);
      if (mounted) AppToast.success(context, '已恢复');
      await _reload();
    } catch (e) {
      if (mounted) AppToast.error(context, '恢复失败 · $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(FileHistorySnapshot snapshot) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.store.remove(snapshot);
      await _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshots = _snapshots;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
            child: Row(
              children: [
                Icon(
                  LucideIcons.history,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '文件历史 · ${widget.entry.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: snapshots == null
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : snapshots.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            '还没有历史快照\n编辑器保存或智能体修改文件时会自动记录',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: snapshots.length,
                        itemBuilder: (context, i) {
                          final s = snapshots[i];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              LucideIcons.fileClock,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            title: Text(_timeLabel(s.savedAt)),
                            subtitle: Text(
                              '${s.source} · ${_sizeLabel(s.size)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            onTap: _busy ? null : () => _showDiff(s),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.backend.capabilities.canWrite)
                                  IconButton(
                                    tooltip: '恢复到此版本',
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(LucideIcons.undo2,
                                        size: 18),
                                    onPressed:
                                        _busy ? null : () => _restore(s),
                                  ),
                                IconButton(
                                  tooltip: '删除此快照',
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    LucideIcons.trash2,
                                    size: 18,
                                    color: theme.colorScheme.error,
                                  ),
                                  onPressed: _busy ? null : () => _remove(s),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

String _timeLabel(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
  if (diff.inDays < 1) return '${diff.inHours}小时前';
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')} '
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

String _sizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
