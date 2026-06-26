import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/data/local_saf_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

import 'directory_picker_sheet.dart';
import 'file_op_dialogs.dart';

/// Drives the file-tree write operations (create/rename/delete/move/copy).
///
/// It owns no state: the tree passes in its [backend], the workspace [rootPath]/
/// [rootName] (for the move/copy destination picker) and a small set of
/// callbacks so the tree can refresh the affected directories after an op
/// succeeds. Each method shows its own dialog(s), calls the backend and reports
/// success/failure through a snackbar.
class WorkspaceFileOps {
  const WorkspaceFileOps({
    required this.context,
    required this.backend,
    required this.rootPath,
    required this.rootName,
    required this.reloadDir,
    required this.ensureExpanded,
    required this.parentOf,
  });

  final BuildContext context;
  final WorkspaceBackend backend;
  final String rootPath;
  final String rootName;

  /// Re-list a directory and refresh its rows in the tree.
  final Future<void> Function(String dirPath) reloadDir;

  /// Make sure a directory is expanded (so freshly-created children show).
  final void Function(String dirPath) ensureExpanded;

  /// The cached parent directory of an entry, or `null` when unknown (e.g. a
  /// top-level entry whose parent is the root).
  final String? Function(String childPath) parentOf;

  bool get _writable => backend is LocalSafBackend;

  void _snack(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Resolves the parent of [entry] for refresh; falls back to the root.
  String _parentDirOf(WorkspaceEntry entry) => parentOf(entry.path) ?? rootPath;

  /// Opens the per-entry action sheet (long-press menu). [entry] is the
  /// long-pressed row.
  Future<void> showEntryMenu(WorkspaceEntry entry) async {
    final action = await showModalBottomSheet<_FileAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ActionSheet(entry: entry),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _FileAction.newFile:
        await newFile(entry.path);
      case _FileAction.newFolder:
        await newFolder(entry.path);
      case _FileAction.rename:
        await rename(entry);
      case _FileAction.move:
        await move(entry);
      case _FileAction.copy:
        await copy(entry);
      case _FileAction.delete:
        await delete(entry);
    }
  }

  Future<void> newFile(String parentPath) async {
    if (!_guardWritable()) return;
    final name = await promptName(
      context,
      title: '新建文件',
      confirmLabel: '创建',
      hint: '文件名,如 notes.md',
    );
    if (name == null) return;
    try {
      await backend.createFile(parentPath, name);
      ensureExpanded(parentPath);
      await reloadDir(parentPath);
      _snack('已创建 $name');
    } catch (e) {
      _snack('新建文件失败 · $e');
    }
  }

  Future<void> newFolder(String parentPath) async {
    if (!_guardWritable()) return;
    final name = await promptName(
      context,
      title: '新建文件夹',
      confirmLabel: '创建',
      hint: '文件夹名',
    );
    if (name == null) return;
    try {
      await backend.createDirectory(parentPath, name);
      ensureExpanded(parentPath);
      await reloadDir(parentPath);
      _snack('已创建 $name');
    } catch (e) {
      _snack('新建文件夹失败 · $e');
    }
  }

  Future<void> rename(WorkspaceEntry entry) async {
    if (!_guardWritable()) return;
    final name = await promptName(
      context,
      title: '重命名',
      confirmLabel: '重命名',
      initial: entry.name,
    );
    if (name == null || name == entry.name) return;
    try {
      await backend.rename(entry.path, name);
      await reloadDir(_parentDirOf(entry));
      _snack('已重命名为 $name');
    } catch (e) {
      _snack('重命名失败 · $e');
    }
  }

  Future<void> delete(WorkspaceEntry entry) async {
    if (!_guardWritable()) return;
    final ok = await confirmDelete(
      context,
      name: entry.name,
      isDirectory: entry.isDirectory,
    );
    if (!ok) return;
    try {
      await backend.delete(
        entry.path,
        isDirectory: entry.isDirectory,
        recursive: entry.isDirectory,
      );
      await reloadDir(_parentDirOf(entry));
      _snack('已删除 ${entry.name}');
    } catch (e) {
      _snack('删除失败 · $e');
    }
  }

  Future<void> move(WorkspaceEntry entry) async {
    if (!_guardWritable()) return;
    final dest = await pickDestinationDirectory(
      context,
      backend: backend,
      rootPath: rootPath,
      rootName: rootName,
      disabledPath: entry.isDirectory ? entry.path : null,
    );
    if (dest == null) return;
    final source = _parentDirOf(entry);
    if (dest == source) {
      _snack('目标与当前目录相同');
      return;
    }
    try {
      await backend.move(entry.path, dest);
      ensureExpanded(dest);
      await reloadDir(source);
      await reloadDir(dest);
      _snack('已移动 ${entry.name}');
    } catch (e) {
      _snack('移动失败 · $e');
    }
  }

  Future<void> copy(WorkspaceEntry entry) async {
    if (!_guardWritable()) return;
    final dest = await pickDestinationDirectory(
      context,
      backend: backend,
      rootPath: rootPath,
      rootName: rootName,
    );
    if (dest == null) return;
    try {
      await backend.copy(entry.path, dest);
      ensureExpanded(dest);
      await reloadDir(dest);
      _snack('已复制 ${entry.name}');
    } catch (e) {
      _snack('复制失败 · $e');
    }
  }

  bool _guardWritable() {
    if (_writable) return true;
    _snack('当前后端不支持写操作');
    return false;
  }
}

enum _FileAction { newFile, newFolder, rename, move, copy, delete }

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({required this.entry});

  final WorkspaceEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDir = entry.isDirectory;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (isDir) ...[
            const _ActionTile(
              icon: LucideIcons.filePlus,
              label: '在此新建文件',
              action: _FileAction.newFile,
            ),
            const _ActionTile(
              icon: LucideIcons.folderPlus,
              label: '在此新建文件夹',
              action: _FileAction.newFolder,
            ),
          ],
          const _ActionTile(
            icon: LucideIcons.pencil,
            label: '重命名',
            action: _FileAction.rename,
          ),
          const _ActionTile(
            icon: LucideIcons.cornerUpRight,
            label: '移动到…',
            action: _FileAction.move,
          ),
          const _ActionTile(
            icon: LucideIcons.copy,
            label: '复制到…',
            action: _FileAction.copy,
          ),
          const _ActionTile(
            icon: LucideIcons.trash2,
            label: '删除',
            action: _FileAction.delete,
            destructive: true,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.action,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final _FileAction action;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? theme.colorScheme.error : null;
    return ListTile(
      leading: Icon(icon, size: 20, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}
