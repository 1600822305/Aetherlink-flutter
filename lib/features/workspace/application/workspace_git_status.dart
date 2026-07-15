// Git 集成最小版（status 染色 + diff）的纯逻辑层。
//
// 仅对 canExec 的后端（SSH / PRoot / Termux）生效：这些后端的路径是真实
// POSIX 路径，`git status` 输出的相对路径可以拼回绝对路径与树条目匹配；
// SAF 的 `content://` opaque 路径不适用（也没有 git 可执行环境）。
//
// 解析逻辑是纯 Dart（可单测/桌面复用）；[gitStatusProvider] 负责跑
// `git rev-parse` / `git status --porcelain -z` 并缓存快照。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';

/// A file's git working-tree state, reduced to what the tree colours on.
enum GitFileStatus { modified, added, deleted, renamed, untracked, conflicted }

/// One `git status` run over the repo containing the workspace root.
/// [files] keys are absolute POSIX paths (`repoRoot` + `/` + porcelain path),
/// matching [WorkspaceEntry.path] on exec-capable backends.
class GitStatusSnapshot {
  GitStatusSnapshot({required this.repoRoot, required this.files})
      : _changedDirs = _ancestorDirsOf(files.keys);

  final String repoRoot;
  final Map<String, GitFileStatus> files;

  /// Every ancestor directory of a changed file, precomputed so directory
  /// roll-up colouring is an O(1) lookup per row instead of a prefix scan
  /// over all changed files.
  final Set<String> _changedDirs;

  GitFileStatus? statusOf(String path) => files[path];

  /// Whether any changed file lives under [dirPath] (for directory roll-up
  /// colouring).
  bool dirHasChanges(String dirPath) => _changedDirs.contains(dirPath);

  static Set<String> _ancestorDirsOf(Iterable<String> paths) {
    final dirs = <String>{};
    for (final path in paths) {
      var slash = path.lastIndexOf('/');
      while (slash > 0) {
        final dir = path.substring(0, slash);
        if (!dirs.add(dir)) break; // ancestors already added
        slash = dir.lastIndexOf('/');
      }
    }
    return dirs;
  }
}

/// Parses `git status --porcelain=v1 -z` output into absolute-path statuses.
/// `-z` gives NUL-separated, unquoted records: `XY path` (renames/copies are
/// followed by an extra NUL-separated origin path, which is skipped).
Map<String, GitFileStatus> parseGitPorcelainZ(String repoRoot, String out) {
  final files = <String, GitFileStatus>{};
  final tokens = out.split('\x00');
  for (var i = 0; i < tokens.length; i++) {
    final rec = tokens[i];
    if (rec.length < 4) continue;
    final x = rec[0];
    final y = rec[1];
    var rel = rec.substring(3);
    if (x == 'R' || x == 'C') i++; // skip the origin-path token
    if (rel.endsWith('/')) rel = rel.substring(0, rel.length - 1);
    if (rel.isEmpty) continue;
    final status = _statusFromXY(x, y);
    if (status == null) continue;
    files['$repoRoot/$rel'] = status;
  }
  return files;
}

/// POSIX single-quote shell quoting for one argument (paths with spaces etc.).
String shellQuoteArg(String s) => "'${s.replaceAll("'", "'\\''")}'";

GitFileStatus? _statusFromXY(String x, String y) {
  if (x == '?' && y == '?') return GitFileStatus.untracked;
  if (x == '!' && y == '!') return null; // ignored
  if (x == 'U' || y == 'U' || (x == 'A' && y == 'A') || (x == 'D' && y == 'D')) {
    return GitFileStatus.conflicted;
  }
  if (x == 'R' || y == 'R' || x == 'C') return GitFileStatus.renamed;
  if (x == 'A' || y == 'A') return GitFileStatus.added;
  if (x == 'D' || y == 'D') return GitFileStatus.deleted;
  if (x == 'M' || y == 'M' || x == 'T' || y == 'T') {
    return GitFileStatus.modified;
  }
  return null;
}

/// Latest git status of the current workspace's repo, or `null` when the
/// backend can't exec / the root isn't inside a git repo. Refreshed by the
/// file tree (initial load / manual refresh / debounced change events).
final gitStatusProvider = NotifierProvider<GitStatusNotifier, GitStatusSnapshot?>(
  GitStatusNotifier.new,
);

class GitStatusNotifier extends Notifier<GitStatusSnapshot?> {
  bool _refreshing = false;
  bool _pending = false;

  @override
  GitStatusSnapshot? build() {
    // Reset the snapshot whenever the opened workspace changes.
    ref.watch(currentWorkspaceProvider);
    return null;
  }

  /// Runs one `git status` pass. A call arriving mid-run is coalesced into a
  /// single trailing rerun so the last change is never missed.
  Future<void> refresh() async {
    if (_refreshing) {
      _pending = true;
      return;
    }
    final backend = ref.read(workspacePreviewBackendProvider);
    final workspace = ref.read(currentWorkspaceProvider);
    if (backend == null ||
        workspace == null ||
        !backend.capabilities.canExec) {
      state = null;
      return;
    }
    _refreshing = true;
    try {
      final top = await backend.exec(
        'git rev-parse --show-toplevel',
        workingDirectory: workspace.root,
        timeout: const Duration(seconds: 10),
      );
      final repoRoot = top.stdout.trim();
      if (top.exitCode != 0 || repoRoot.isEmpty) {
        state = null;
        return;
      }
      final status = await backend.exec(
        'git -c core.quotepath=off status --porcelain=v1 -z',
        workingDirectory: workspace.root,
        timeout: const Duration(seconds: 20),
      );
      if (status.exitCode != 0) {
        state = null;
        return;
      }
      state = GitStatusSnapshot(
        repoRoot: repoRoot,
        files: parseGitPorcelainZ(repoRoot, status.stdout),
      );
    } catch (_) {
      state = null;
    } finally {
      _refreshing = false;
      if (_pending) {
        _pending = false;
        Future.microtask(refresh);
      }
    }
  }
}
