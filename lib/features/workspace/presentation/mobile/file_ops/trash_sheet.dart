import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// 回收站面板：列出回收站内的条目，支持单个恢复、彻底删除与清空。
/// 纯 UI —— 实际操作通过回调交给 WorkspaceFileOps（含确认对话框）。
class TrashSheet extends StatefulWidget {
  const TrashSheet({
    super.key,
    required this.listTrash,
    required this.onRestore,
    required this.onDeleteForever,
    required this.onEmptyTrash,
  });

  /// Lists the trash contents (empty list when the trash dir doesn't exist).
  final Future<List<WorkspaceEntry>> Function() listTrash;

  /// Restores [entry] to the workspace root. Returns true when it happened.
  final Future<bool> Function(WorkspaceEntry entry) onRestore;

  /// Permanently deletes [entry] (with confirm). Returns true when deleted.
  final Future<bool> Function(WorkspaceEntry entry) onDeleteForever;

  /// Permanently deletes everything (with confirm). Returns true when done.
  final Future<bool> Function() onEmptyTrash;

  @override
  State<TrashSheet> createState() => _TrashSheetState();
}

class _TrashSheetState extends State<TrashSheet> {
  List<WorkspaceEntry>? _entries;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final entries = await widget.listTrash();
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  Future<void> _run(Future<bool> Function() op) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await op();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _entries;
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
                  LucideIcons.trash2,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '回收站',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: (entries == null || entries.isEmpty || _busy)
                      ? null
                      : () => _run(widget.onEmptyTrash),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: const Text('清空'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: entries == null
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
                : entries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            '回收站是空的',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: entries.length,
                        itemBuilder: (context, i) {
                          final e = entries[i];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              e.isDirectory
                                  ? LucideIcons.folder
                                  : LucideIcons.file,
                              size: 18,
                            ),
                            title: Text(
                              e.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: '恢复到工作区根目录',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    LucideIcons.undo2,
                                    size: 18,
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => _run(() => widget.onRestore(e)),
                                ),
                                IconButton(
                                  tooltip: '彻底删除',
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    LucideIcons.trash2,
                                    size: 18,
                                    color: theme.colorScheme.error,
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          () => widget.onDeleteForever(e)),
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
