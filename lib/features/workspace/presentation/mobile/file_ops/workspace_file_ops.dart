import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_file_templates.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_name_conflicts.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_placeholders.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/readable_path.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

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
    this.onFileCreated,
    this.canGitDiff,
    this.onGitDiff,
    this.onShare,
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

  /// Called with the freshly-created file so the tree can open it in an
  /// editor tab right away (新建后自动打开).
  final void Function(WorkspaceEntry entry)? onFileCreated;

  /// Whether the 「Git 对比」 action applies to [entry]（exec-capable backend
  /// and the file has a git status）. Both null ⇒ the action is hidden.
  final bool Function(WorkspaceEntry entry)? canGitDiff;

  /// Shows the git working-tree diff for [entry]。
  final Future<void> Function(WorkspaceEntry entry)? onGitDiff;

  /// Exports [entry]'s bytes to the OS share sheet (用其他应用打开/分享).
  /// Null ⇒ the action is hidden.
  final Future<void> Function(WorkspaceEntry entry)? onShare;

  bool get _writable => backend.capabilities.canWrite;

  void _snack(String message) {
    if (!context.mounted) return;
    AppToast.info(context, message);
  }

  // Resolves the parent of [entry] for refresh; falls back to the root.
  String _parentDirOf(WorkspaceEntry entry) => parentOf(entry.path) ?? rootPath;

  /// Opens the per-entry action sheet (long-press menu). [entry] is the
  /// long-pressed row.
  Future<void> showEntryMenu(WorkspaceEntry entry) async {
    final protected = backend.isProtectedPath(entry.path);
    final action = await showModalBottomSheet<_FileAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ActionSheet(
        entry: entry,
        protected: protected,
        writable: _writable,
        showGitDiff: canGitDiff?.call(entry) ?? false,
        showShare: onShare != null && !entry.isDirectory,
      ),
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
      case _FileAction.copyPath:
        await copyPath(entry);
      case _FileAction.details:
        await showDetails(entry);
      case _FileAction.gitDiff:
        await onGitDiff?.call(entry);
      case _FileAction.share:
        await onShare?.call(entry);
      case _FileAction.delete:
        await delete(entry);
    }
  }

  /// Copies the human-readable path to the clipboard. The opaque token
  /// (`content://` URI on SAF) is useless to a human, so the readable form is
  /// what gets copied — it's display-only and must never be fed back to a
  /// backend.
  Future<void> copyPath(WorkspaceEntry entry) async {
    await Clipboard.setData(
      ClipboardData(text: readableWorkspacePath(entry.path)),
    );
    _snack('已复制路径');
  }

  /// Shows a details dialog (name / type / size / mtime / readable path),
  /// refreshing the metadata via [WorkspaceBackend.getFileInfo] when the
  /// backend supports it.
  Future<void> showDetails(WorkspaceEntry entry) async {
    var info = entry;
    try {
      info = await backend.getFileInfo(entry.path);
    } catch (_) {
      // Backend can't stat (or the entry vanished) — show the cached row data.
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _DetailsDialog(
        entry: info,
        onCopyPath: () => copyPath(info),
      ),
    );
  }

  Future<void> newFile(String parentPath) async {
    if (!_guardWritable()) return;
    final req = await promptNewFile(context);
    if (req == null) return;
    final name = req.name;
    try {
      final newPath = await backend.createFile(
        parentPath,
        name,
        content: req.useTemplate ? fileTemplateFor(name) : null,
      );
      ensureExpanded(parentPath);
      await reloadDir(parentPath);
      _snack('已创建 $name');
      onFileCreated?.call(await _entryForCreated(newPath, name));
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
    if (!_guardWritable() || !_guardNotProtected(entry)) return;
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

  /// 回收站目录名（工作区根下的隐藏目录）。删除默认是「移入回收站 + 可撤销」；
  /// 回收站内的条目（或回收站本身）才真正删除。
  static const String kTrashDirName = '.aetherlink_trash';

  // The trash directory's opaque path when it already exists under the root.
  Future<String?> _findTrashPath() async {
    try {
      for (final e in await backend.listDir(rootPath)) {
        if (e.name == kTrashDirName && e.isDirectory) return e.path;
      }
    } catch (_) {}
    return null;
  }

  // Whether [ancestor] appears in [path]'s cached parent chain. Paths are
  // opaque, so this only knows about directories already loaded in the tree.
  bool _hasAncestor(String path, String ancestor) {
    var cursor = parentOf(path);
    while (cursor != null) {
      if (cursor == ancestor) return true;
      if (cursor == rootPath) return false;
      cursor = parentOf(cursor);
    }
    return false;
  }

  Future<void> delete(WorkspaceEntry entry) async {
    if (!_guardWritable() || !_guardNotProtected(entry)) return;
    final trashPath = await _findTrashPath();
    if (!context.mounted) return;
    final inTrash = trashPath != null &&
        (entry.path == trashPath || _hasAncestor(entry.path, trashPath));
    if (inTrash) {
      await _deleteForever(entry);
      return;
    }
    try {
      final undo = await _moveToTrash(entry, trashPath);
      if (undo == null) return;
      if (!context.mounted) return;
      AppToast.success(
        context,
        '已移入回收站 ${entry.name}',
        duration: const Duration(seconds: 6),
        action: AppToastAction(label: '撤销', onPressed: undo),
      );
    } catch (e) {
      _snack('删除失败 · $e');
    }
  }

  // Moves [entry] into the trash dir (creating it if needed, keep-both on
  // name conflicts) and returns an undo closure, or null when it failed.
  Future<VoidCallback?> _moveToTrash(
    WorkspaceEntry entry,
    String? trashPath,
  ) async {
    final source = _parentDirOf(entry);
    final trash = trashPath ??
        await backend.createDirectory(rootPath, kTrashDirName);
    var srcPath = entry.path;
    var name = entry.name;
    final trashNames = await _siblingNames(trash);
    if (trashNames.contains(name)) {
      final taken = {
        ...trashNames,
        ...await _siblingNames(source),
      }..remove(entry.name);
      name = resolveDuplicateName(entry.name, taken);
      srcPath = await backend.rename(entry.path, name);
    }
    final trashedPath = await backend.move(srcPath, trash);
    await reloadDir(source);
    return () async {
      try {
        var restored = await backend.move(trashedPath, source);
        if (name != entry.name) {
          restored = await backend.rename(restored, entry.name);
        }
        await reloadDir(source);
        _snack('已恢复 ${entry.name}');
      } catch (e) {
        _snack('撤销失败 · $e');
      }
    };
  }

  // Permanent deletion (used inside the trash dir), with the hard confirm.
  Future<void> _deleteForever(WorkspaceEntry entry) async {
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

  // ===== 多选批量操作 =====

  /// Batch soft-delete: every entry is moved to the trash; a single toast
  /// undoes all of them. Protected mounts and entries already in the trash
  /// are skipped.
  Future<void> deleteMany(List<WorkspaceEntry> entries) async {
    if (!_guardWritable()) return;
    var trashPath = await _findTrashPath();
    final undos = <VoidCallback>[];
    var skipped = 0;
    for (final entry in entries) {
      final inTrash = trashPath != null &&
          (entry.path == trashPath || _hasAncestor(entry.path, trashPath));
      if (backend.isProtectedPath(entry.path) || inTrash) {
        skipped++;
        continue;
      }
      try {
        final undo = await _moveToTrash(entry, trashPath);
        trashPath ??= await _findTrashPath();
        if (undo != null) undos.add(undo);
      } catch (_) {
        skipped++;
      }
    }
    if (!context.mounted) return;
    if (undos.isEmpty) {
      _snack('没有可删除的项（跳过 $skipped 项）');
      return;
    }
    AppToast.success(
      context,
      '已移入回收站 ${undos.length} 项${skipped > 0 ? '，跳过 $skipped 项' : ''}',
      duration: const Duration(seconds: 6),
      action: AppToastAction(
        label: '撤销',
        onPressed: () {
          for (final undo in undos) {
            undo();
          }
        },
      ),
    );
  }

  /// Batch move to a picked destination. Name conflicts resolve as keep-both
  /// (「name (2).ext」) — no per-item dialogs. Protected mounts, entries
  /// already in the destination and moves into themselves are skipped.
  Future<void> moveMany(List<WorkspaceEntry> entries) async {
    if (!_guardWritable()) return;
    final dest = await pickDestinationDirectory(
      context,
      backend: backend,
      rootPath: rootPath,
      rootName: rootName,
    );
    if (dest == null) return;
    var moved = 0;
    var skipped = 0;
    final touched = <String>{dest};
    for (final entry in entries) {
      final source = _parentDirOf(entry);
      if (backend.isProtectedPath(entry.path) ||
          source == dest ||
          entry.path == dest ||
          (entry.isDirectory && _hasAncestor(dest, entry.path))) {
        skipped++;
        continue;
      }
      try {
        var srcPath = entry.path;
        var name = entry.name;
        if ((await _siblingNames(dest)).contains(name)) {
          final taken = {
            ...await _siblingNames(dest),
            ...await _siblingNames(source),
          }..remove(entry.name);
          name = resolveDuplicateName(entry.name, taken);
          srcPath = await backend.rename(entry.path, name);
        }
        await backend.move(srcPath, dest);
        touched.add(source);
        moved++;
      } catch (_) {
        skipped++;
      }
    }
    ensureExpanded(dest);
    for (final dir in touched) {
      await reloadDir(dir);
    }
    _snack('已移动 $moved 项${skipped > 0 ? '，跳过 $skipped 项' : ''}');
  }

  /// Batch copy to a picked destination; keep-both on name conflicts.
  Future<void> copyMany(List<WorkspaceEntry> entries) async {
    if (!_guardWritable()) return;
    final dest = await pickDestinationDirectory(
      context,
      backend: backend,
      rootPath: rootPath,
      rootName: rootName,
    );
    if (dest == null) return;
    var copied = 0;
    var skipped = 0;
    for (final entry in entries) {
      if (entry.path == dest ||
          (entry.isDirectory && _hasAncestor(dest, entry.path))) {
        skipped++;
        continue;
      }
      try {
        String? newName;
        if ((await _siblingNames(dest)).contains(entry.name)) {
          newName = resolveDuplicateName(
            entry.name,
            await _siblingNames(dest),
          );
        }
        await backend.copy(entry.path, dest, newName: newName);
        copied++;
      } catch (_) {
        skipped++;
      }
    }
    ensureExpanded(dest);
    await reloadDir(dest);
    _snack('已复制 $copied 项${skipped > 0 ? '，跳过 $skipped 项' : ''}');
  }

  Future<void> move(WorkspaceEntry entry) async {
    if (!_guardWritable() || !_guardNotProtected(entry)) return;
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
      var srcPath = entry.path;
      var name = entry.name;
      final existing = await _findConflict(dest, entry.name);
      if (existing != null) {
        final action = await _promptConflict(existing);
        if (action == null) return;
        if (action == ConflictAction.overwrite) {
          await backend.delete(
            existing.path,
            isDirectory: existing.isDirectory,
            recursive: existing.isDirectory,
          );
        } else {
          // 保留两者：先在源目录里改成一个两边都不冲突的名字再移动
          // （move 不支持改名，改名发生在源目录，所以两边都要查）。
          final taken = <String>{
            ...await _siblingNames(dest),
            ...await _siblingNames(source),
          };
          name = resolveDuplicateName(entry.name, taken);
          srcPath = await backend.rename(entry.path, name);
        }
        if (!context.mounted) return;
      }
      await backend.move(srcPath, dest);
      ensureExpanded(dest);
      await reloadDir(source);
      await reloadDir(dest);
      _snack('已移动 $name');
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
      String? newName;
      final existing = await _findConflict(dest, entry.name);
      if (existing != null) {
        final action = await _promptConflict(existing);
        if (action == null) return;
        if (action == ConflictAction.overwrite) {
          await backend.delete(
            existing.path,
            isDirectory: existing.isDirectory,
            recursive: existing.isDirectory,
          );
        } else {
          newName = resolveDuplicateName(
            entry.name,
            await _siblingNames(dest),
          );
        }
        if (!context.mounted) return;
      }
      await backend.copy(entry.path, dest, newName: newName);
      ensureExpanded(dest);
      await reloadDir(dest);
      _snack('已复制 ${newName ?? entry.name}');
    } catch (e) {
      _snack('复制失败 · $e');
    }
  }

  // The destination's same-name entry, or null when the name is free (or the
  // destination can't be listed — the op then proceeds and may still throw).
  Future<WorkspaceEntry?> _findConflict(String dest, String name) async {
    try {
      for (final e in await backend.listDir(dest)) {
        if (e.name == name) return e;
      }
    } catch (_) {}
    return null;
  }

  Future<Set<String>> _siblingNames(String dir) async {
    try {
      return (await backend.listDir(dir)).map((e) => e.name).toSet();
    } catch (_) {
      return const {};
    }
  }

  Future<ConflictAction?> _promptConflict(WorkspaceEntry existing) {
    if (!context.mounted) return Future.value();
    return promptNameConflict(
      context,
      name: existing.name,
      existingIsDirectory: existing.isDirectory,
    );
  }

  // Resolves the created file's entry for the auto-open callback; falls back
  // to a minimal stub when the backend can't stat.
  Future<WorkspaceEntry> _entryForCreated(String path, String name) async {
    try {
      return await backend.getFileInfo(path);
    } catch (_) {}
    return WorkspaceEntry(
      name: name,
      path: path,
      isDirectory: false,
      size: 0,
      mtime: 0,
    );
  }

  bool _guardWritable() {
    if (_writable) return true;
    _snack('当前后端不支持写操作');
    return false;
  }

  // Mount points mapping to real phone storage (e.g. /sdcard in the PRoot
  // backend) must not be deleted / renamed / moved.
  bool _guardNotProtected(WorkspaceEntry entry) {
    if (!backend.isProtectedPath(entry.path)) return true;
    _snack('${entry.name} 是受保护的挂载点，不能删除/重命名/移动');
    return false;
  }
}

enum _FileAction {
  newFile,
  newFolder,
  rename,
  move,
  copy,
  copyPath,
  details,
  gitDiff,
  share,
  delete,
}

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({
    required this.entry,
    this.protected = false,
    this.writable = true,
    this.showGitDiff = false,
    this.showShare = false,
  });

  final WorkspaceEntry entry;

  /// Protected entries (storage mount points) hide the destructive actions.
  final bool protected;

  /// Read-only backends only get the non-mutating actions (复制路径/详情).
  final bool writable;

  /// Whether to offer 「Git 对比」 (the entry has a git working-tree status).
  final bool showGitDiff;

  /// Whether to offer 「用其他应用打开/分享」 (files only).
  final bool showShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDir = entry.isDirectory;
    // 写操作组（新建/重命名/移动/复制到…）与「复制路径/详情」信息组之间加
    // 分隔线；有写操作时才需要分隔。
    final hasWriteGroup = writable && (isDir || !protected);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (writable && isDir) ...[
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
          if (writable && !protected) ...[
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
          ],
          if (writable)
            const _ActionTile(
              icon: LucideIcons.copy,
              label: '复制到…',
              action: _FileAction.copy,
            ),
          if (hasWriteGroup) const _MenuDivider(),
          const _ActionTile(
            icon: LucideIcons.clipboardCopy,
            label: '复制路径',
            action: _FileAction.copyPath,
          ),
          const _ActionTile(
            icon: LucideIcons.info,
            label: '详情',
            action: _FileAction.details,
          ),
          if (showGitDiff)
            const _ActionTile(
              icon: LucideIcons.fileDiff,
              label: 'Git 对比',
              action: _FileAction.gitDiff,
            ),
          if (showShare)
            const _ActionTile(
              icon: LucideIcons.share2,
              label: '用其他应用打开/分享',
              action: _FileAction.share,
            ),
          if (writable && !protected) ...[
            const _MenuDivider(),
            const _ActionTile(
              icon: LucideIcons.trash2,
              label: '删除',
              action: _FileAction.delete,
              destructive: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Thin inset divider between the action-sheet's groups.
class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 20, endIndent: 20);
}

/// The 「详情」 dialog: name / type / size / mtime / readable path, plus a
/// copy-path shortcut. The path shown is the display-only readable form.
class _DetailsDialog extends StatelessWidget {
  const _DetailsDialog({required this.entry, required this.onCopyPath});

  final WorkspaceEntry entry;
  final VoidCallback onCopyPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <(String, String)>[
      ('名称', entry.name),
      ('类型', fileTypeLabel(entry)),
      if (!entry.isDirectory) ('大小', formatBytes(entry.size)),
      ('修改时间', formatMtime(entry.mtime)),
      ('路径', readableWorkspacePath(entry.path)),
    ];
    return AlertDialog(
      title: const Text('详情'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(value, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCopyPath();
          },
          child: const Text('复制路径'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
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
      dense: true,
      visualDensity: VisualDensity.compact,
      minLeadingWidth: 0,
      horizontalTitleGap: 12,
      leading: Icon(icon, size: 19, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}
