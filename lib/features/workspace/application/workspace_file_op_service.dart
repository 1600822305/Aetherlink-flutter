import 'package:flutter/foundation.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_name_conflicts.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// A file moved into the trash, with enough context to undo the move.
@immutable
class TrashedEntry {
  const TrashedEntry({
    required this.movedPath,
    required this.movedName,
    required this.sourceDir,
    required this.originalName,
  });

  /// The entry's opaque path inside the trash directory.
  final String movedPath;

  /// The name it carries in the trash (may differ from [originalName] when a
  /// keep-both rename was needed).
  final String movedName;

  /// The directory it was moved out of.
  final String sourceDir;

  final String originalName;
}

/// Outcome of a batch soft-delete: what actually reached the trash and how
/// many entries were skipped (protected mounts, already-trashed, failures).
@immutable
class BatchTrashResult {
  const BatchTrashResult({required this.trashed, required this.skipped});

  final List<TrashedEntry> trashed;
  final int skipped;
}

/// Outcome of a batch move: how many moved / were skipped, and every directory
/// whose listing the operation touched (sources + destination).
@immutable
class BatchMoveResult {
  const BatchMoveResult({
    required this.moved,
    required this.skipped,
    required this.touchedDirs,
  });

  final int moved;
  final int skipped;
  final Set<String> touchedDirs;
}

/// Outcome of a batch copy.
@immutable
class BatchCopyResult {
  const BatchCopyResult({required this.copied, required this.skipped});

  final int copied;
  final int skipped;
}

/// The backend-facing half of the file-tree operations: create / rename /
/// move / copy / trash and their conflict-resolution rules, with **no UI
/// concerns** (no BuildContext, no dialogs, no toasts). The presentation layer
/// (`WorkspaceFileOps`) prompts the user and reports results; this service is
/// what actually talks to the [WorkspaceBackend], so the rules (keep-both
/// naming, trash semantics, batch skip policies) are unit-testable.
///
/// Paths are opaque tokens (`content://` URIs on SAF) — the service never
/// parses them; parent relationships come from the injected [parentOf]
/// resolver (backed by the tree's cached listings).
class WorkspaceFileOpService {
  const WorkspaceFileOpService({
    required this.backend,
    required this.rootPath,
    required this.parentOf,
  });

  final WorkspaceBackend backend;
  final String rootPath;

  /// The cached parent directory of an entry, or `null` when unknown.
  final String? Function(String childPath) parentOf;

  /// 回收站目录名（工作区根下的隐藏目录）。
  static const String kTrashDirName = '.aetherlink_trash';

  bool get canWrite => backend.capabilities.canWrite;

  bool isProtected(String path) => backend.isProtectedPath(path);

  /// Resolves the parent of [entry] for refresh; falls back to the root.
  String parentDirOf(WorkspaceEntry entry) => parentOf(entry.path) ?? rootPath;

  // ===== creation =====

  /// Creates a file and resolves its [WorkspaceEntry] (falling back to a
  /// minimal stub when the backend can't stat the fresh path).
  Future<WorkspaceEntry> createFile(
    String parentPath,
    String name, {
    String? content,
  }) async {
    final newPath = await backend.createFile(parentPath, name, content: content);
    try {
      return await backend.getFileInfo(newPath);
    } catch (_) {}
    return WorkspaceEntry(
      name: name,
      path: newPath,
      isDirectory: false,
      size: 0,
      mtime: 0,
    );
  }

  Future<String> createDirectory(String parentPath, String name) =>
      backend.createDirectory(parentPath, name);

  Future<String> rename(WorkspaceEntry entry, String name) =>
      backend.rename(entry.path, name);

  // ===== conflicts =====

  /// The destination's same-name entry, or null when the name is free (or the
  /// destination can't be listed — the op then proceeds and may still throw).
  Future<WorkspaceEntry?> findConflict(String dest, String name) async {
    try {
      for (final e in await backend.listDir(dest)) {
        if (e.name == name) return e;
      }
    } catch (_) {}
    return null;
  }

  Future<Set<String>> siblingNames(String dir) async {
    try {
      return (await backend.listDir(dir)).map((e) => e.name).toSet();
    } catch (_) {
      return const {};
    }
  }

  /// Permanently deletes [existing] (the overwrite arm of a name conflict).
  Future<void> deleteEntry(WorkspaceEntry existing) => backend.delete(
        existing.path,
        isDirectory: existing.isDirectory,
        recursive: existing.isDirectory,
      );

  // ===== single move / copy =====

  /// Moves [entry] (from [source]) into [dest], renaming it first to a name
  /// free in both directories when the caller resolved a conflict as
  /// keep-both. Returns the effective name.
  Future<String> moveKeepBoth(
    WorkspaceEntry entry,
    String source,
    String dest,
  ) async {
    // 保留两者：先在源目录里改成一个两边都不冲突的名字再移动
    // （move 不支持改名，改名发生在源目录，所以两边都要查）。
    final taken = <String>{
      ...await siblingNames(dest),
      ...await siblingNames(source),
    };
    final name = resolveDuplicateName(entry.name, taken);
    final srcPath = await backend.rename(entry.path, name);
    await backend.move(srcPath, dest);
    return name;
  }

  Future<void> move(String path, String dest) => backend.move(path, dest);

  /// Copies [entry] into [dest]; [newName] carries the keep-both name when the
  /// caller resolved a conflict that way.
  Future<void> copy(WorkspaceEntry entry, String dest, {String? newName}) =>
      backend.copy(entry.path, dest, newName: newName);

  /// The keep-both name for copying [entry] into [dest].
  Future<String> copyKeepBothName(WorkspaceEntry entry, String dest) async =>
      resolveDuplicateName(entry.name, await siblingNames(dest));

  /// 原地副本：把 [entry] 复制到它所在的目录，自动取「name (2).ext」式
  /// 空闲名（源条目本身占着原名，所以副本必然改名）。返回副本的名字。
  Future<String> duplicate(WorkspaceEntry entry) async {
    final parent = parentDirOf(entry);
    final name = resolveDuplicateName(entry.name, await siblingNames(parent));
    await backend.copy(entry.path, parent, newName: name);
    return name;
  }

  // ===== trash =====

  /// The trash directory's opaque path when it already exists under the root.
  Future<String?> findTrashPath() async {
    try {
      for (final e in await backend.listDir(rootPath)) {
        if (e.name == kTrashDirName && e.isDirectory) return e.path;
      }
    } catch (_) {}
    return null;
  }

  /// Whether [ancestor] appears in [path]'s cached parent chain. Paths are
  /// opaque, so this only knows about directories already loaded in the tree.
  bool hasAncestor(String path, String ancestor) {
    var cursor = parentOf(path);
    while (cursor != null) {
      if (cursor == ancestor) return true;
      if (cursor == rootPath) return false;
      cursor = parentOf(cursor);
    }
    return false;
  }

  /// Whether [entry] already lives in (or is) the trash directory.
  bool isInTrash(WorkspaceEntry entry, String? trashPath) =>
      trashPath != null &&
      (entry.path == trashPath || hasAncestor(entry.path, trashPath));

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
    final destNames = await siblingNames(destDir);
    if (destNames.contains(name)) {
      final taken = {
        ...destNames,
        if (avoidDir != null) ...await siblingNames(avoidDir),
      };
      name = resolveDuplicateName(entry.name, taken);
      srcPath = await backend.rename(entry.path, name);
    }
    final moved = await backend.move(srcPath, destDir);
    return (path: moved, name: name);
  }

  /// Moves [entry] into the trash dir (creating it if needed, keep-both on
  /// name conflicts). Pass the known [trashPath] to avoid re-listing the root.
  Future<TrashedEntry> moveToTrash(
    WorkspaceEntry entry, {
    String? trashPath,
  }) async {
    final source = parentDirOf(entry);
    final trash =
        trashPath ?? await backend.createDirectory(rootPath, kTrashDirName);
    final moved = await _moveKeepingBoth(entry, trash, avoidDir: source);
    return TrashedEntry(
      movedPath: moved.path,
      movedName: moved.name,
      sourceDir: source,
      originalName: entry.name,
    );
  }

  /// Undoes [trashed]: moves it back to its source directory and restores the
  /// original name when a keep-both rename happened on the way in.
  Future<void> undoTrash(TrashedEntry trashed) async {
    var restored = await backend.move(trashed.movedPath, trashed.sourceDir);
    if (trashed.movedName != trashed.originalName) {
      await backend.rename(restored, trashed.originalName);
    }
  }

  /// The trash dir's current contents (empty when it doesn't exist yet).
  Future<List<WorkspaceEntry>> listTrashEntries() async {
    final trashPath = await findTrashPath();
    if (trashPath == null) return const [];
    try {
      return await backend.listDir(trashPath);
    } catch (_) {
      return const [];
    }
  }

  /// 把回收站里的 [entry] 恢复到工作区根目录（原位置未记录），
  /// 同名时自动改名保留两者。返回恢复后的名字。
  Future<String> restoreFromTrash(WorkspaceEntry entry) async {
    final trash = await findTrashPath();
    final moved = await _moveKeepingBoth(entry, rootPath, avoidDir: trash);
    return moved.name;
  }

  /// 彻底删除回收站目录本身（清空回收站）。No-op when there is no trash.
  Future<void> deleteTrashDir() async {
    final trashPath = await findTrashPath();
    if (trashPath == null) return;
    await backend.delete(trashPath, isDirectory: true, recursive: true);
  }

  // ===== batch =====

  /// Batch soft-delete: every entry is moved to the trash. Protected mounts
  /// and entries already in the trash are skipped, as are individual failures.
  Future<BatchTrashResult> deleteManyToTrash(
    List<WorkspaceEntry> entries,
  ) async {
    var trashPath = await findTrashPath();
    final trashed = <TrashedEntry>[];
    var skipped = 0;
    for (final entry in entries) {
      if (isProtected(entry.path) || isInTrash(entry, trashPath)) {
        skipped++;
        continue;
      }
      try {
        trashed.add(await moveToTrash(entry, trashPath: trashPath));
        trashPath ??= await findTrashPath();
      } catch (_) {
        skipped++;
      }
    }
    return BatchTrashResult(trashed: trashed, skipped: skipped);
  }

  /// Batch move into [dest]. Name conflicts resolve as keep-both
  /// (「name (2).ext」). Protected mounts, entries already in the destination
  /// and moves into themselves are skipped.
  Future<BatchMoveResult> moveMany(
    List<WorkspaceEntry> entries,
    String dest,
  ) async {
    var moved = 0;
    var skipped = 0;
    final touched = <String>{dest};
    for (final entry in entries) {
      final source = parentDirOf(entry);
      if (isProtected(entry.path) ||
          source == dest ||
          entry.path == dest ||
          (entry.isDirectory && hasAncestor(dest, entry.path))) {
        skipped++;
        continue;
      }
      try {
        var srcPath = entry.path;
        if ((await siblingNames(dest)).contains(entry.name)) {
          final taken = {
            ...await siblingNames(dest),
            ...await siblingNames(source),
          };
          final name = resolveDuplicateName(entry.name, taken);
          srcPath = await backend.rename(entry.path, name);
        }
        await backend.move(srcPath, dest);
        touched.add(source);
        moved++;
      } catch (_) {
        skipped++;
      }
    }
    return BatchMoveResult(moved: moved, skipped: skipped, touchedDirs: touched);
  }

  /// Batch copy into [dest]; keep-both on name conflicts. Copies into
  /// themselves are skipped.
  Future<BatchCopyResult> copyMany(
    List<WorkspaceEntry> entries,
    String dest,
  ) async {
    var copied = 0;
    var skipped = 0;
    for (final entry in entries) {
      if (entry.path == dest ||
          (entry.isDirectory && hasAncestor(dest, entry.path))) {
        skipped++;
        continue;
      }
      try {
        String? newName;
        if ((await siblingNames(dest)).contains(entry.name)) {
          newName = resolveDuplicateName(
            entry.name,
            await siblingNames(dest),
          );
        }
        await backend.copy(entry.path, dest, newName: newName);
        copied++;
      } catch (_) {
        skipped++;
      }
    }
    return BatchCopyResult(copied: copied, skipped: skipped);
  }
}
