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

  // Moves [entry] into [destDir], auto-renaming to keep both when a sibling of
  // the same name already exists there. [avoidDir] adds another directory's
  // names to steer clear of when generating the fresh name (so the pick is free
  // in both the source and destination). Returns the moved path and the
  // effective name (== entry.name when no rename was needed).
  Future<({String path, String name})> _moveKeepingBoth(
    WorkspaceEntry entry,
    String destDir, {
    String? avoidDir,
  }) async {
    var srcPath = entry.path;
    var name = entry.name;
    final destNames = await _siblingNames(destDir);
    if (destNames.contains(name)) {
      final taken = {
        ...destNames,
        if (avoidDir != null) ...await _siblingNames(avoidDir),
      }..remove(entry.name);
      name = resolveDuplicateName(entry.name, taken);
      srcPath = await backend.rename(entry.path, name);
    }
    final moved = await backend.move(srcPath, destDir);
    return (path: moved, name: name);
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
    final moved = await _moveKeepingBoth(entry, trash, avoidDir: source);
    await reloadDir(source);
    return () async {
      try {
        var restored = await backend.move(moved.path, source);
        if (moved.name != entry.name) {
          restored = await backend.rename(restored, entry.name);
        }
        await reloadDir(source);
        _snack('已恢复 ${entry.name}');
      } catch (e) {
        _snack('撤销失败 · $e');
      }
    };
  }

  /// 打开回收站面板（列出已删除条目，可恢复/彻底删除/清空）。
  Future<void> openTrash() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => TrashSheet(
        listTrash: listTrashEntries,
        onRestore: restoreFromTrash,
        onDeleteForever: _deleteTrashedWithConfirm,
        onEmptyTrash: emptyTrash,
      ),
    );
  }

  /// The trash dir's current contents (empty when it doesn't exist yet).
  Future<List<WorkspaceEntry>> listTrashEntries() async {
    final trashPath = await _findTrashPath();
    if (trashPath == null) return const [];
    try {
      return await backend.listDir(trashPath);
    } catch (_) {
      return const [];
    }
  }

  /// 把回收站里的 [entry] 恢复到工作区根目录（原位置未记录），
  /// 同名时自动改名保留两者。
  Future<bool> restoreFromTrash(WorkspaceEntry entry) async {
    try {
      final trash = await _findTrashPath();
      final moved = await _moveKeepingBoth(entry, rootPath, avoidDir: trash);
      await reloadDir(rootPath);
      _snack('已恢复 ${moved.name} 到工作区根目录');
      return true;
    } catch (e) {
      _snack('恢复失败 · $e');
      return false;
    }
  }

  Future<bool> _deleteTrashedWithConfirm(WorkspaceEntry entry) async {
    final ok = await confirmDelete(
      context,
      name: entry.name,
      isDirectory: entry.isDirectory,
    );
    if (!ok) return false;
    try {
      if (entry.isDirectory) _snack('正在删除 ${entry.name}…');
      await backend.delete(
        entry.path,
        isDirectory: entry.isDirectory,
        recursive: entry.isDirectory,
      );
      await reloadDir(_parentDirOf(entry));
      return true;
    } catch (e) {
      _snack('删除失败 · $e');
      return false;
    }
  }

  /// 彻底删除回收站里的全部条目（删除回收站目录本身）。
  Future<bool> emptyTrash() async {
    final trashPath = await _findTrashPath();
    if (trashPath == null) return true;
    if (!context.mounted) return false;
    final ok = await confirmDelete(
      context,
      name: '回收站全部内容',
      isDirectory: true,
    );
    if (!ok) return false;
    try {
      _snack('正在清空回收站…');
      await backend.delete(trashPath, isDirectory: true, recursive: true);
      await reloadDir(rootPath);
      _snack('已清空回收站');
      return true;
    } catch (e) {
      _snack('清空失败 · $e');
      return false;
    }
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
      if (entry.isDirectory) _snack('正在删除 ${entry.name}…');
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
