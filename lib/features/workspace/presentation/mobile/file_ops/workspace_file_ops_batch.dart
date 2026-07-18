part of 'workspace_file_ops.dart';

/// 多选批量操作（批量删除/移动/复制）。与单项操作的差异：目的地只选一次，
/// 重名冲突不逐项弹框而是自动「保留两者」，受保护挂载点/移入自身自动跳过并
/// 汇总提示。循环与跳过规则在 [WorkspaceFileOpService]，这里只负责目的地
/// 选择、汇总 toast 与树刷新。
extension WorkspaceFileOpsBatch on WorkspaceFileOps {
  /// Batch soft-delete: every entry is moved to the trash; a single toast
  /// undoes all of them.
  Future<void> deleteMany(List<WorkspaceEntry> entries) async {
    if (!_guardWritable()) return;
    final result = await service.deleteManyToTrash(entries);
    for (final t in result.trashed) {
      onEntryRemoved?.call(t.sourcePath);
    }
    for (final dir in {for (final t in result.trashed) t.sourceDir}) {
      await reloadDir(dir);
    }
    if (!context.mounted) return;
    if (result.trashed.isEmpty) {
      _snack('没有可删除的项（跳过 ${result.skipped} 项）');
      return;
    }
    AppToast.success(
      context,
      '已移入回收站 ${result.trashed.length} 项'
      '${result.skipped > 0 ? '，跳过 ${result.skipped} 项' : ''}',
      duration: const Duration(seconds: 6),
      action: AppToastAction(
        label: '撤销',
        onPressed: () {
          for (final trashed in result.trashed) {
            _undoTrash(trashed);
          }
        },
      ),
    );
  }

  /// Batch move to a picked destination. Name conflicts resolve as keep-both
  /// (「name (2).ext」) — no per-item dialogs.
  Future<void> moveMany(List<WorkspaceEntry> entries) async {
    if (!_guardWritable()) return;
    final dest = await pickDestinationDirectory(
      context,
      backend: backend,
      rootPath: rootPath,
      rootName: rootName,
    );
    if (dest == null) return;
    final result = await service.moveMany(entries, dest);
    for (final m in result.moves) {
      onEntryMoved?.call(m.sourcePath, m.movedPath, m.movedName);
    }
    ensureExpanded(dest);
    for (final dir in result.touchedDirs) {
      await reloadDir(dir);
    }
    _moveResultToast(result, dest);
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
    final result = await service.copyMany(entries, dest);
    ensureExpanded(dest);
    await reloadDir(dest);
    _snack(
      '已复制 ${result.copied} 项'
      '${result.skipped > 0 ? '，跳过 ${result.skipped} 项' : ''}',
    );
  }
}
