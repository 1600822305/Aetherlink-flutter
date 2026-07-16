import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_file_templates.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_name_conflicts.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/readable_path.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

import 'directory_picker_sheet.dart';
import 'entry_action_sheet.dart';
import 'entry_details_dialog.dart';
import 'file_op_dialogs.dart';
import 'trash_sheet.dart';

part 'workspace_file_ops_batch.dart';
part 'workspace_file_ops_trash.dart';

/// Drives the file-tree write operations (create/rename/delete/move/copy).
///
/// It owns no state: the tree passes in its [backend], the workspace [rootPath]/
/// [rootName] (for the move/copy destination picker) and a small set of
/// callbacks so the tree can refresh the affected directories after an op
/// succeeds. Each method shows its own dialog(s), calls the backend and reports
/// success/failure through a snackbar.
///
/// 拆分：回收站/可撤销删除在 `workspace_file_ops_trash.dart`，多选批量操作在
/// `workspace_file_ops_batch.dart`（同库 part，扩展方法）；长按菜单 sheet 与
/// 详情对话框是独立组件（`entry_action_sheet.dart` / `entry_details_dialog.dart`）。
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
    this.onFileHistory,
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

  /// Opens the app-level file-history sheet for [entry]（checkpoint 快照，
  /// 与 Git 无关）。Null ⇒ the action is hidden.
  final Future<void> Function(WorkspaceEntry entry)? onFileHistory;

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
    final action = await showModalBottomSheet<FileEntryAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => EntryActionSheet(
        entry: entry,
        protected: protected,
        writable: _writable,
        showGitDiff: canGitDiff?.call(entry) ?? false,
        showFileHistory: onFileHistory != null && !entry.isDirectory,
        showShare: onShare != null && !entry.isDirectory,
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case FileEntryAction.newFile:
        await newFile(entry.path);
      case FileEntryAction.newFolder:
        await newFolder(entry.path);
      case FileEntryAction.rename:
        await rename(entry);
      case FileEntryAction.move:
        await move(entry);
      case FileEntryAction.copy:
        await copy(entry);
      case FileEntryAction.copyPath:
        await copyPath(entry);
      case FileEntryAction.details:
        await showDetails(entry);
      case FileEntryAction.gitDiff:
        await onGitDiff?.call(entry);
      case FileEntryAction.fileHistory:
        await onFileHistory?.call(entry);
      case FileEntryAction.share:
        await onShare?.call(entry);
      case FileEntryAction.delete:
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
      builder: (context) => EntryDetailsDialog(
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
