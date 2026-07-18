part of 'workspace_file_ops.dart';

/// 删除 = 回收站语义：默认把条目移入工作区根下的隐藏回收站目录（可撤销），
/// 回收站内的条目（或回收站本身）才真正删除。移动/命名规则在
/// [WorkspaceFileOpService]，这里只负责确认对话框、撤销 toast 与树刷新。
extension WorkspaceFileOpsTrash on WorkspaceFileOps {
  Future<void> delete(WorkspaceEntry entry) async {
    if (!_guardWritable() || !_guardNotProtected(entry)) return;
    final trashPath = await service.findTrashPath();
    if (!context.mounted) return;
    if (service.isInTrash(entry, trashPath)) {
      await _deleteForever(entry);
      return;
    }
    try {
      final trashed = await service.moveToTrash(entry, trashPath: trashPath);
      await reloadDir(trashed.sourceDir);
      if (!context.mounted) return;
      AppToast.success(
        context,
        '已移入回收站 ${entry.name}',
        duration: const Duration(seconds: 6),
        action: AppToastAction(
          label: '撤销',
          onPressed: () => _undoTrash(trashed),
        ),
      );
    } catch (e) {
      _snack('删除失败 · $e');
    }
  }

  Future<void> _undoTrash(TrashedEntry trashed) async {
    try {
      await service.undoTrash(trashed);
      await reloadDir(trashed.sourceDir);
      _snack('已恢复 ${trashed.originalName}');
    } catch (e) {
      _snack('撤销失败 · $e');
    }
  }

  /// 打开回收站面板（列出已删除条目，可恢复/彻底删除/清空）。
  Future<void> openTrash() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => TrashSheet(
        listTrash: service.listTrashEntries,
        onRestore: restoreFromTrash,
        onDeleteForever: _deleteTrashedWithConfirm,
        onEmptyTrash: emptyTrash,
      ),
    );
  }

  /// 把回收站里的 [entry] 恢复到工作区根目录（原位置未记录），
  /// 同名时自动改名保留两者。
  Future<bool> restoreFromTrash(WorkspaceEntry entry) async {
    try {
      final name = await service.restoreFromTrash(entry);
      await reloadDir(rootPath);
      _snack('已恢复 $name 到工作区根目录');
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
      await service.deleteEntry(entry);
      await reloadDir(service.parentDirOf(entry));
      return true;
    } catch (e) {
      _snack('删除失败 · $e');
      return false;
    }
  }

  /// 彻底删除回收站里的全部条目（删除回收站目录本身）。
  Future<bool> emptyTrash() async {
    final trashPath = await service.findTrashPath();
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
      await service.deleteTrashDir();
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
      await service.deleteEntry(entry);
      await reloadDir(service.parentDirOf(entry));
      _snack('已删除 ${entry.name}');
    } catch (e) {
      _snack('删除失败 · $e');
    }
  }
}
