import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_file_op_service.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_file_templates.dart';
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

/// The interaction half of the file-tree operations: dialogs, pickers and
/// toasts. Every backend mutation and its conflict-resolution rules live in
/// the UI-free [WorkspaceFileOpService]; this class prompts the user, calls
/// the service and refreshes the affected directories through the callbacks
/// the tree passes in.
///
/// 拆分：回收站/可撤销删除在 `workspace_file_ops_trash.dart`，多选批量操作在
/// `workspace_file_ops_batch.dart`（同库 part，扩展方法）；长按菜单 sheet 与
/// 详情对话框是独立组件（`entry_action_sheet.dart` / `entry_details_dialog.dart`）。
class WorkspaceFileOps {
  WorkspaceFileOps({
    required this.context,
    required WorkspaceBackend backend,
    required String rootPath,
    required this.rootName,
    required this.reloadDir,
    required this.ensureExpanded,
    required String? Function(String childPath) parentOf,
    this.onFileCreated,
    this.canPaste = false,
    this.onClipboardSet,
    this.onPaste,
    this.canGitDiff,
    this.onGitDiff,
    this.onFileHistory,
    this.onShare,
  }) : service = WorkspaceFileOpService(
          backend: backend,
          rootPath: rootPath,
          parentOf: parentOf,
        );

  final BuildContext context;

  /// The UI-free operation service (backend calls + conflict rules).
  final WorkspaceFileOpService service;

  final String rootName;

  /// Re-list a directory and refresh its rows in the tree.
  final Future<void> Function(String dirPath) reloadDir;

  /// Make sure a directory is expanded (so freshly-created children show).
  final void Function(String dirPath) ensureExpanded;

  /// Called with the freshly-created file so the tree can open it in an
  /// editor tab right away (新建后自动打开).
  final void Function(WorkspaceEntry entry)? onFileCreated;

  /// Whether the file-tree clipboard holds something pasteable in this
  /// workspace — gates the 「粘贴」 menu item.
  final bool canPaste;

  /// Puts [entries] on the file-tree clipboard（cut = 粘贴后移动，否则复制）.
  final void Function(List<WorkspaceEntry> entries, {required bool cut})?
      onClipboardSet;

  /// Pastes the current clipboard into [destDir]（由树侧读取剪贴板并回调
  /// [pasteEntries]，剪切粘贴后清空剪贴板）.
  final Future<void> Function(String destDir)? onPaste;

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

  WorkspaceBackend get backend => service.backend;

  String get rootPath => service.rootPath;

  void _snack(String message) {
    if (!context.mounted) return;
    AppToast.info(context, message);
  }

  /// Opens the per-entry action sheet (long-press menu). [entry] is the
  /// long-pressed row.
  Future<void> showEntryMenu(WorkspaceEntry entry) async {
    final protected = service.isProtected(entry.path);
    final action = await showModalBottomSheet<FileEntryAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => EntryActionSheet(
        entry: entry,
        protected: protected,
        writable: service.canWrite,
        canPaste: canPaste && onPaste != null,
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
      case FileEntryAction.cut:
        onClipboardSet?.call([entry], cut: true);
        _snack('已剪切 ${entry.name}，长按目标目录粘贴');
      case FileEntryAction.copyToClipboard:
        onClipboardSet?.call([entry], cut: false);
        _snack('已复制 ${entry.name}，长按目标目录粘贴');
      case FileEntryAction.paste:
        await onPaste?.call(
          entry.isDirectory ? entry.path : service.parentDirOf(entry),
        );
      case FileEntryAction.duplicate:
        await duplicate(entry);
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
      final entry = await service.createFile(
        parentPath,
        name,
        content: req.useTemplate ? fileTemplateFor(name) : null,
      );
      ensureExpanded(parentPath);
      await reloadDir(parentPath);
      _snack('已创建 $name');
      onFileCreated?.call(entry);
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
      await service.createDirectory(parentPath, name);
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
      await service.rename(entry, name);
      await reloadDir(service.parentDirOf(entry));
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
    final source = service.parentDirOf(entry);
    if (dest == source) {
      _snack('目标与当前目录相同');
      return;
    }
    try {
      var name = entry.name;
      final existing = await service.findConflict(dest, entry.name);
      if (existing != null) {
        final action = await _promptConflict(existing);
        if (action == null) return;
        if (action == ConflictAction.overwrite) {
          await service.deleteEntry(existing);
          if (!context.mounted) return;
          await service.move(entry.path, dest);
        } else {
          if (!context.mounted) return;
          name = await service.moveKeepBoth(entry, source, dest);
        }
      } else {
        await service.move(entry.path, dest);
      }
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
      final existing = await service.findConflict(dest, entry.name);
      if (existing != null) {
        final action = await _promptConflict(existing);
        if (action == null) return;
        if (action == ConflictAction.overwrite) {
          await service.deleteEntry(existing);
        } else {
          newName = await service.copyKeepBothName(entry, dest);
        }
        if (!context.mounted) return;
      }
      await service.copy(entry, dest, newName: newName);
      ensureExpanded(dest);
      await reloadDir(dest);
      _snack('已复制 ${newName ?? entry.name}');
    } catch (e) {
      _snack('复制失败 · $e');
    }
  }

  /// 原地副本：复制到同目录，自动取「name (2).ext」式空闲名。
  Future<void> duplicate(WorkspaceEntry entry) async {
    if (!_guardWritable()) return;
    try {
      final parent = service.parentDirOf(entry);
      final name = await service.duplicate(entry);
      await reloadDir(parent);
      _snack('已创建副本 $name');
    } catch (e) {
      _snack('创建副本失败 · $e');
    }
  }

  /// 粘贴剪贴板内容到 [dest]：剪切 = 批量移动，复制 = 批量复制；重名自动
  /// 「保留两者」，受保护/移入自身等自动跳过并汇总提示。返回是否有条目
  /// 真正落地（调用方据此决定是否清空剪切剪贴板）。
  Future<bool> pasteEntries(
    List<WorkspaceEntry> entries, {
    required bool cut,
    required String dest,
  }) async {
    if (!_guardWritable()) return false;
    try {
      if (cut) {
        final result = await service.moveMany(entries, dest);
        ensureExpanded(dest);
        for (final dir in result.touchedDirs) {
          await reloadDir(dir);
        }
        _snack(
          '已移动 ${result.moved} 项'
          '${result.skipped > 0 ? '，跳过 ${result.skipped} 项' : ''}',
        );
        return result.moved > 0;
      }
      final result = await service.copyMany(entries, dest);
      ensureExpanded(dest);
      await reloadDir(dest);
      _snack(
        '已复制 ${result.copied} 项'
        '${result.skipped > 0 ? '，跳过 ${result.skipped} 项' : ''}',
      );
      return result.copied > 0;
    } catch (e) {
      _snack('粘贴失败 · $e');
      return false;
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

  bool _guardWritable() {
    if (service.canWrite) return true;
    _snack('当前后端不支持写操作');
    return false;
  }

  // Mount points mapping to real phone storage (e.g. /sdcard in the PRoot
  // backend) must not be deleted / renamed / moved.
  bool _guardNotProtected(WorkspaceEntry entry) {
    if (!service.isProtected(entry.path)) return true;
    _snack('${entry.name} 是受保护的挂载点，不能删除/重命名/移动');
    return false;
  }
}
