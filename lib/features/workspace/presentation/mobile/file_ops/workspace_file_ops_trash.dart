part of 'workspace_file_ops.dart';

/// 删除 = 回收站语义：默认把条目移入工作区根下的隐藏回收站目录（可撤销），
/// 回收站内的条目（或回收站本身）才真正删除。只依赖后端 move/rename，
/// 从不对 opaque 路径做字符串推导。
extension WorkspaceFileOpsTrash on WorkspaceFileOps {
  /// 回收站目录名（工作区根下的隐藏目录）。
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
    final trash =
        trashPath ?? await backend.createDirectory(rootPath, kTrashDirName);
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
}
