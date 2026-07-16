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
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

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

/// All discovered repos of one workspace, sorted by root-path length
/// descending so [repoOf] resolves nested repos by longest-prefix match.
/// The workspace root itself need not be a repo — a 「多仓库容器」式工作区
/// 下每个子仓库各自一份 [GitStatusSnapshot]。
class GitStatusOverview {
  GitStatusOverview({required List<GitStatusSnapshot> repos})
      : repos = _sortedByRootLength(repos);

  static List<GitStatusSnapshot> _sortedByRootLength(
    List<GitStatusSnapshot> repos,
  ) {
    final sorted = [...repos]
      ..sort((a, b) => b.repoRoot.length.compareTo(a.repoRoot.length));
    return List.unmodifiable(sorted);
  }

  final List<GitStatusSnapshot> repos;

  /// The repo owning [path] (longest root prefix), or null.
  GitStatusSnapshot? repoOf(String path) {
    for (final repo in repos) {
      if (path == repo.repoRoot || path.startsWith('${repo.repoRoot}/')) {
        return repo;
      }
    }
    return null;
  }

  GitFileStatus? statusOf(String path) => repoOf(path)?.statusOf(path);

  bool dirHasChanges(String dirPath) =>
      repos.any((repo) => repo.dirHasChanges(dirPath));

  int get totalChanges =>
      repos.fold(0, (sum, repo) => sum + repo.files.length);
}

/// Caps for the downward `.git` scan: don't crawl huge trees, don't run
/// `git status` over an unbounded repo list.
const int kGitDiscoverMaxDepth = 4;
const int kGitDiscoverMaxRepos = 12;

/// Finds the git repos a workspace [root] relates to, on an exec backend:
/// upward `rev-parse` first (root inside a repo → single repo); otherwise a
/// bounded downward scan for `.git` entries (multi-repo container 工作区).
/// Returns absolute repo roots, or an empty list when none are found.
Future<List<String>> discoverGitRepos(
  WorkspaceBackend backend,
  String root,
) async {
  if (!backend.capabilities.canExec) return const [];
  try {
    // 向上 rev-parse 与向下扫描合成一次 exec：每次 exec 在 SSH 是一次
    // 往返、在 PRoot 是一次进程启动，合并后发现成本减半。`.git` 可能
    // 是目录（普通仓）或文件（worktree/submodule），所以不加 -type；
    // node_modules 与回收站目录直接剪枝。
    final result = await backend.exec(
      'git rev-parse --show-toplevel 2>/dev/null || '
      'find ${shellQuoteArg(root)} -maxdepth $kGitDiscoverMaxDepth '
      "! -path '*/node_modules/*' ! -path '*/.Trash*' -name .git "
      '2>/dev/null | head -n $kGitDiscoverMaxRepos',
      workingDirectory: root,
      timeout: const Duration(seconds: 20),
    );
    final roots = <String>[];
    for (final line in result.stdout.split('\n')) {
      final path = line.trim();
      if (path.isEmpty) continue;
      if (path.endsWith('/.git')) {
        roots.add(path.substring(0, path.length - '/.git'.length));
      } else if (path.startsWith('/')) {
        return [path]; // rev-parse 命中：工作区在某个仓库内
      }
    }
    roots.sort();
    return roots;
  } catch (_) {
    return const [];
  }
}

/// One `printf`-delimited `git status` pass over every repo in [roots] in a
/// single exec (\x01 starts a repo record, \x02 separates root from its
/// porcelain output). Repos whose status fails contribute empty output and
/// are skipped.
String buildBatchStatusCommand(List<String> roots) {
  final buf = StringBuffer();
  for (final r in roots) {
    buf
      ..write("printf '\\001%s\\002' ${shellQuoteArg(r)}; ")
      ..write('git -C ${shellQuoteArg(r)} -c core.quotepath=off '
          'status --porcelain=v1 -z 2>/dev/null; ');
  }
  return buf.toString();
}

/// Parses [buildBatchStatusCommand] output into per-repo snapshots.
List<GitStatusSnapshot> parseBatchStatusOutput(String out) {
  final snapshots = <GitStatusSnapshot>[];
  for (final chunk in out.split('\x01')) {
    final sep = chunk.indexOf('\x02');
    if (sep <= 0) continue;
    final repoRoot = chunk.substring(0, sep);
    final porcelain = chunk.substring(sep + 1);
    snapshots.add(GitStatusSnapshot(
      repoRoot: repoRoot,
      files: parseGitPorcelainZ(repoRoot, porcelain),
    ));
  }
  return snapshots;
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

/// Latest git status over every repo the current workspace relates to
/// (工作区在仓库内 / 工作区是多仓库容器都支持), or `null` when the backend
/// can't exec / no repo was found. Refreshed by the file tree (initial load /
/// manual refresh / debounced change events).
final gitStatusProvider =
    NotifierProvider<GitStatusNotifier, GitStatusOverview?>(
  GitStatusNotifier.new,
);

class GitStatusNotifier extends Notifier<GitStatusOverview?> {
  bool _refreshing = false;
  bool _pending = false;

  /// Discovered repo roots, cached per workspace — discovery (rev-parse +
  /// find) 只在首次/手动重扫时跑，watch 事件触发的刷新只跑一次批量 status。
  List<String>? _roots;

  @override
  GitStatusOverview? build() {
    // Reset the snapshot whenever the opened workspace changes.
    ref.watch(currentWorkspaceProvider);
    _roots = null;
    return null;
  }

  /// The workspace's repo roots, discovering (and caching) on first call.
  Future<List<String>> repoRoots() async {
    final cached = _roots;
    if (cached != null) return cached;
    final backend = ref.read(workspacePreviewBackendProvider);
    final workspace = ref.read(currentWorkspaceProvider);
    if (backend == null || workspace == null) return const [];
    return _roots = await discoverGitRepos(backend, workspace.root);
  }

  /// Runs one batched `git status` pass over the cached repo roots. A call
  /// arriving mid-run is coalesced into a single trailing rerun so the last
  /// change is never missed. [rediscover] re-scans the workspace for repos
  /// first (手动刷新/新建仓库后用).
  Future<void> refresh({bool rediscover = false}) async {
    if (rediscover) _roots = null;
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
      final roots = await repoRoots();
      if (roots.isEmpty) {
        state = null;
        return;
      }
      final result = await backend.exec(
        buildBatchStatusCommand(roots),
        workingDirectory: workspace.root,
        timeout: const Duration(seconds: 20),
      );
      final snapshots = parseBatchStatusOutput(result.stdout);
      state = snapshots.isEmpty
          ? null
          : GitStatusOverview(repos: snapshots);
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
