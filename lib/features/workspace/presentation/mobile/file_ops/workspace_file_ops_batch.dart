part of 'workspace_file_ops.dart';

/// 多选批量操作（批量删除/移动/复制）。与单项操作的差异：目的地只选一次，
/// 重名冲突不逐项弹框而是自动「保留两者」，受保护挂载点/移入自身自动跳过并
/// 汇总提示。
extension WorkspaceFileOpsBatch on WorkspaceFileOps {
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
}
