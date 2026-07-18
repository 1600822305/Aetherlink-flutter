import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_tree_sort.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// Cap on the directories the reveal fallback DFS may list. Without it, a
/// deep / wide project could trigger a full recursive `listDir` crawl (slow
/// on SAF and remote backends) just to locate one file.
const int kMaxRevealSearchDirs = 64;

/// One row of the flattened tree the ListView renders.
class FileTreeRowData {
  const FileTreeRowData({
    required this.entry,
    required this.depth,
    required this.expanded,
  }) : isLoading = false;

  const FileTreeRowData.loading(this.depth)
      : entry = null,
        expanded = false,
        isLoading = true;

  final WorkspaceEntry? entry;
  final int depth;
  final bool expanded;
  final bool isLoading;
}

/// The file tree's state machine, extracted from the tree widget so the racy
/// parts (listDir generations, watch debouncing, the three-tier reveal
/// strategy, selection mode) are unit-testable without a widget tree.
///
/// The widget owns one instance, forwards user intents (toggle / refresh /
/// select …) and rebuilds on [notifyListeners]; UI side effects go through the
/// injected callbacks:
///
/// - [onError] — surface a listDir failure (toast);
/// - [onGitRefresh] — ask the git status provider to refresh (throttled here);
/// - [onReveal] — scroll the revealed row into view.
///
/// Directories load their children on first expand and cache them. Paths are
/// opaque tokens (`content://` URIs on SAF): parent relationships only come
/// from cached listings ([parentOf]), never from parsing.
class FileTreeController extends ChangeNotifier {
  FileTreeController({
    required this.onError,
    required this.onGitRefresh,
    required this.onReveal,
  });

  final void Function(String message) onError;
  final VoidCallback onGitRefresh;
  final void Function(String path) onReveal;

  // The tree root — the opened workspace's `root`. `null` until a workspace
  // is opened.
  String? _root;
  String? get root => _root;

  WorkspaceBackend? _backend;
  WorkspaceBackend? get backend => _backend;

  final Set<String> _expanded = {};
  final Set<String> _loading = {};
  final Map<String, List<WorkspaceEntry>> _children = {};

  // Per-directory listDir generation: bumped when a (re)load starts so a
  // slower, older in-flight response can't overwrite a newer listing.
  final Map<String, int> _listGen = {};

  // Sorted view of [_children] per directory, memoised so rebuilding the
  // flattened rows doesn't re-sort every expanded directory on every build.
  // Invalidated per-dir on relist and wholesale when the sort mode changes.
  final Map<String, List<WorkspaceEntry>> _sortedCache = {};
  TreeSortMode? _sortedCacheMode;

  // child path → parent directory path, kept in sync with [_children] so
  // [parentOf] is O(1) instead of scanning every cached listing per call.
  final Map<String, String> _parentIndex = {};

  // Live file-change subscription (in-app mutations: editor save / file-ops /
  // agent tools). Affected directories are coalesced and re-listed on a short
  // debounce so a burst of agent edits costs one reload per dir, and so it
  // doesn't race the synchronous reload file-ops already does.
  StreamSubscription<WorkspaceChangeEvent>? _watchSub;
  Timer? _watchDebounce;
  Timer? _watchRetry;
  final Set<String> _pendingReload = {};

  // Git refresh is throttled separately from directory reloads: a burst of
  // agent writes re-lists dirs every debounce tick, but the two git execs
  // only run once per second.
  Timer? _gitDebounce;

  // 多选模式：选中集合按路径索引，退出时清空。
  bool _selecting = false;
  bool get selecting => _selecting;
  final Map<String, WorkspaceEntry> _selected = {};
  Map<String, WorkspaceEntry> get selected => _selected;

  // Guards against re-revealing the same active file repeatedly.
  String? _revealedPath;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _watchDebounce?.cancel();
    _watchRetry?.cancel();
    _gitDebounce?.cancel();
    _watchSub?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool isLoading(String path) => _loading.contains(path);
  bool isExpanded(String path) => _expanded.contains(path);

  /// Whether the root is bound, loading and nothing is renderable yet.
  bool get rootLoading {
    final root = _root;
    return root != null && _loading.contains(root);
  }

  // ===== binding =====

  /// Resets the tree to a new workspace root (or none) and loads the root.
  void bind(String? root, WorkspaceBackend? backend) {
    _root = root;
    _backend = backend;
    _selecting = false;
    _selected.clear();
    _expanded.clear();
    _children.clear();
    _parentIndex.clear();
    _loading.clear();
    _listGen.clear();
    _sortedCache.clear();
    _revealedPath = null;
    _rebindWatch();
    if (root != null) {
      _expanded.add(root);
      load(root);
    }
    // Defer: bind can run inside build (workspace switch).
    Future.microtask(() {
      if (!_disposed) onGitRefresh();
    });
  }

  // (Re)subscribes to the backend's change stream for the current workspace.
  // On stream error/close the subscription is rebuilt after a short delay so
  // the tree keeps following file changes instead of silently going stale.
  void _rebindWatch() {
    _watchDebounce?.cancel();
    _watchRetry?.cancel();
    _watchSub?.cancel();
    _watchSub = null;
    _pendingReload.clear();
    final backend = _backend;
    if (_root == null || backend == null || !backend.capabilities.canWatch) {
      return;
    }
    final boundRoot = _root;
    void retry() {
      _watchRetry?.cancel();
      _watchRetry = Timer(const Duration(seconds: 2), () {
        if (!_disposed && _root == boundRoot) _rebindWatch();
      });
    }

    _watchSub = backend.watch().listen(
          _onWatchEvent,
          onError: (Object _) => retry(),
          onDone: retry,
        );
  }

  // Queues the directories an event touched and schedules a debounced reload.
  // Only directories already loaded into the tree are re-listed — there's no
  // point fetching ones the user hasn't expanded.
  void _onWatchEvent(WorkspaceChangeEvent event) {
    for (final dir in {
      event.parentPath,
      parentOf(event.path),
      if (event.fromPath != null) parentOf(event.fromPath!),
    }) {
      if (dir != null && _children.containsKey(dir)) _pendingReload.add(dir);
    }
    if (_pendingReload.isEmpty) return;
    _watchDebounce?.cancel();
    _watchDebounce = Timer(const Duration(milliseconds: 200), _flushReload);
  }

  void _flushReload() {
    if (_disposed) return;
    final dirs = _pendingReload.toList();
    _pendingReload.clear();
    for (final dir in dirs) {
      if (_children.containsKey(dir)) reload(dir);
    }
    _gitDebounce ??= Timer(const Duration(seconds: 1), () {
      _gitDebounce = null;
      if (!_disposed) onGitRefresh();
    });
  }

  // ===== loading =====

  int _bumpGen(String path) => _listGen[path] = (_listGen[path] ?? 0) + 1;

  // Caches [path]'s listing and indexes each child's parent for [parentOf].
  // Children that disappeared since the last listing get their stale parent
  // mapping and cached subtree evicted so [parentOf] / reveal never resolve
  // through deleted paths.
  void _cacheChildren(String path, List<WorkspaceEntry> entries) {
    final old = _children[path];
    if (old != null) {
      final alive = {for (final e in entries) e.path};
      for (final e in old) {
        if (!alive.contains(e.path)) _evictSubtree(e.path);
      }
    }
    _children[path] = entries;
    _sortedCache.remove(path);
    for (final e in entries) {
      _parentIndex[e.path] = path;
    }
  }

  // Drops every cached trace of [path] and its cached descendants.
  void _evictSubtree(String path) {
    _parentIndex.remove(path);
    _expanded.remove(path);
    _loading.remove(path);
    _listGen.remove(path);
    _sortedCache.remove(path);
    final children = _children.remove(path);
    if (children == null) return;
    for (final e in children) {
      _evictSubtree(e.path);
    }
  }

  Future<void> load(String path) async {
    final backend = _backend;
    if (backend == null) return;
    if (_children.containsKey(path) || _loading.contains(path)) return;
    _loading.add(path);
    _notify();
    final gen = _bumpGen(path);
    try {
      final entries = await backend.listDir(path);
      if (_disposed || _listGen[path] != gen) return;
      _loading.remove(path);
      _cacheChildren(path, entries);
      _notify();
    } catch (e) {
      if (_disposed || _listGen[path] != gen) return;
      // Collapse on failure so the lazy-load-from-build path doesn't retry
      // (and toast) in a loop for a directory that keeps failing to list.
      _loading.remove(path);
      _expanded.remove(path);
      _notify();
      onError('列目录失败 · $e');
    }
  }

  /// Re-lists a single directory (after a write op) and refreshes its rows,
  /// bypassing the load-once cache guard.
  Future<void> reload(String path) async {
    final backend = _backend;
    if (backend == null) return;
    _loading.add(path);
    _notify();
    final gen = _bumpGen(path);
    try {
      final entries = await backend.listDir(path);
      if (_disposed || _listGen[path] != gen) return;
      _loading.remove(path);
      _cacheChildren(path, entries);
      _notify();
    } catch (e) {
      if (_disposed || _listGen[path] != gen) return;
      _loading.remove(path);
      _notify();
      onError('列目录失败 · $e');
    }
  }

  void toggleDir(WorkspaceEntry entry) {
    final path = entry.path;
    if (_expanded.contains(path)) {
      _expanded.remove(path);
      _notify();
    } else {
      _expanded.add(path);
      _notify();
      load(path);
    }
  }

  /// Ensures a directory is expanded so freshly-created/moved children show.
  void ensureExpanded(String path) {
    if (_expanded.contains(path)) return;
    _expanded.add(path);
    _notify();
    load(path);
  }

  /// Drops every cached listing and reloads the root, so the tree reflects any
  /// out-of-band changes. Expand state for still-present directories is kept;
  /// their listings reload lazily as they become visible.
  void refresh() {
    final root = _root;
    if (root == null) return;
    _children.clear();
    _parentIndex.clear();
    _loading.clear();
    _sortedCache.clear();
    _notify();
    load(root);
  }

  /// Collapses everything back to the root. Cached children stay so
  /// re-expanding is instant.
  void collapseAll() {
    final root = _root;
    _expanded.clear();
    if (root != null) _expanded.add(root);
    _notify();
  }

  /// The cached parent directory of an entry. Paths are opaque `content://`
  /// URIs, so the parent can only be recovered from the loaded tree structure.
  String? parentOf(String childPath) => _parentIndex[childPath];

  // ===== selection mode =====

  void enterSelect() {
    _selecting = true;
    _notify();
  }

  void exitSelect() {
    _selecting = false;
    _selected.clear();
    _notify();
  }

  void toggleSelected(WorkspaceEntry entry) {
    if (_selected.containsKey(entry.path)) {
      _selected.remove(entry.path);
    } else {
      _selected[entry.path] = entry;
    }
    _notify();
  }

  /// Snapshots the selection and exits select mode (batch ops run after).
  List<WorkspaceEntry> takeSelection() {
    final sel = _selected.values.toList();
    _selecting = false;
    _selected.clear();
    _notify();
    return sel;
  }

  // ===== reveal active file (IDE follow mode) =====

  // Lists [path] and caches it, awaiting the result (unlike [load], which is
  // fire-and-forget). Returns null on failure.
  Future<List<WorkspaceEntry>?> _ensureChildren(String path) async {
    final cached = _children[path];
    if (cached != null) return cached;
    final backend = _backend;
    if (backend == null) return null;
    final gen = _bumpGen(path);
    try {
      final entries = await backend.listDir(path);
      if (_disposed) return null;
      if (_listGen[path] != gen) return _children[path];
      _cacheChildren(path, entries);
      _notify();
      return entries;
    } catch (_) {
      return null;
    }
  }

  // The ancestor directory chain (root → … → parent) for an already-loaded
  // [target], or null when any ancestor isn't cached yet.
  List<String>? _knownChain(String target) {
    final root = _root;
    if (root == null) return null;
    final chain = <String>[];
    var cursor = parentOf(target);
    while (cursor != null) {
      chain.add(cursor);
      if (cursor == root) {
        return chain.reversed.toList();
      }
      cursor = parentOf(cursor);
    }
    return null;
  }

  // Derives the ancestor chain from path strings when the backend uses plain
  // posix paths (SSH / Termux / PRoot), so revealing a file costs one listDir
  // per ancestor instead of a tree crawl. Each derived level is verified
  // against the actual listing; any mismatch (opaque SAF URIs, odd layouts)
  // returns null and the caller falls back to the DFS.
  Future<List<String>?> _deriveChain(String root, String target) async {
    if (root.contains('://')) return null;
    final base = root.endsWith('/')
        ? root.substring(0, root.length - 1)
        : root;
    if (!target.startsWith('$base/')) return null;
    final segments = target.substring(base.length + 1).split('/');
    if (segments.isEmpty || segments.any((s) => s.isEmpty)) return null;
    final chain = <String>[root];
    var dir = base;
    for (var i = 0; i < segments.length - 1; i++) {
      dir = '$dir/${segments[i]}';
      chain.add(dir);
    }
    for (var i = 0; i < chain.length; i++) {
      final entries = await _ensureChildren(chain[i]);
      if (entries == null) return null;
      final expected = i + 1 < chain.length ? chain[i + 1] : target;
      if (!entries.any((e) => e.path == expected)) return null;
    }
    return chain;
  }

  // Depth-first search down from [dir] for [target], returning the directory
  // chain to expand (root → … → parent), or null if not found. [visited]
  // caps how many directories may be listed so the fallback can't crawl an
  // entire large project.
  Future<List<String>?> _searchChain(
    String dir,
    String target,
    List<String> chain,
    _SearchBudget visited,
  ) async {
    if (visited.used >= kMaxRevealSearchDirs) return null;
    visited.used++;
    final entries = await _ensureChildren(dir);
    if (entries == null) return null;
    if (entries.any((e) => e.path == target)) return chain;
    for (final e in entries) {
      if (!e.isDirectory) continue;
      final found = await _searchChain(
        e.path,
        target,
        [...chain, e.path],
        visited,
      );
      if (found != null) return found;
      if (visited.used >= kMaxRevealSearchDirs) return null;
    }
    return null;
  }

  /// Expands [target]'s ancestors and asks the view to scroll its row into
  /// view, then marks it revealed so repeat builds don't re-run the search.
  /// A failed reveal (e.g. a listDir error) leaves the path unmarked so a
  /// later trigger can retry it.
  Future<void> revealActive(String target) async {
    if (_revealedPath == target) return;
    _revealedPath = target;
    final ok = await revealPath(target);
    if (!ok && _revealedPath == target) _revealedPath = null;
  }

  /// Expands [target]'s ancestors and asks the view to scroll its row into
  /// view. Also used to locate a directory picked from the search sheet, so it
  /// carries no active-file dedup guard. Returns whether the target was found.
  Future<bool> revealPath(String target) async {
    final root = _root;
    if (root == null) return false;

    var chain = _knownChain(target);
    chain ??= await _deriveChain(root, target);
    chain ??= await _searchChain(root, target, [root], _SearchBudget());
    if (chain == null || _disposed) return false;

    final toExpand = chain.where((d) => !_expanded.contains(d)).toList();
    if (toExpand.isNotEmpty) {
      _expanded.addAll(toExpand);
      _notify();
    }
    onReveal(target);
    return true;
  }

  // ===== rows =====

  // Memoised per-directory sorted listing; the whole cache resets when the
  // sort mode changes, individual dirs are invalidated by [_cacheChildren].
  List<WorkspaceEntry> _sortedChildren(
    String path,
    List<WorkspaceEntry> entries,
    TreeSortMode sortMode,
  ) {
    if (_sortedCacheMode != sortMode) {
      _sortedCache.clear();
      _sortedCacheMode = sortMode;
    }
    return _sortedCache[path] ??= sortTreeEntries(entries, sortMode);
  }

  /// Walks the cached tree depth-first into the flat rows the ListView
  /// renders. Hidden entries are skipped unless [showHidden]; each directory's
  /// entries are ordered by [sortMode] (directories first) at render time, so
  /// switching modes never needs a reload. Expanded-but-uncached directories
  /// (e.g. right after 刷新 cleared the caches) show a loading row and reload
  /// lazily.
  List<FileTreeRowData> buildRows(bool showHidden, TreeSortMode sortMode) {
    final root = _root;
    final rows = <FileTreeRowData>[];
    if (root != null) {
      _appendRows(root, 0, rows, showHidden, sortMode);
    }
    return rows;
  }

  void _appendRows(
    String path,
    int depth,
    List<FileTreeRowData> out,
    bool showHidden,
    TreeSortMode sortMode,
  ) {
    final entries = _children[path];
    if (entries == null) return;
    for (final entry in _sortedChildren(path, entries, sortMode)) {
      if (!showHidden && entry.isHidden) continue;
      final expanded = _expanded.contains(entry.path);
      out.add(
        FileTreeRowData(entry: entry, depth: depth, expanded: expanded),
      );
      if (entry.isDirectory && expanded) {
        if (_loading.contains(entry.path)) {
          out.add(FileTreeRowData.loading(depth + 1));
        } else if (!_children.containsKey(entry.path)) {
          out.add(FileTreeRowData.loading(depth + 1));
          scheduleMicrotask(() {
            if (!_disposed) load(entry.path);
          });
        } else {
          _appendRows(entry.path, depth + 1, out, showHidden, sortMode);
        }
      }
    }
  }
}

// Mutable listDir counter shared across a reveal DFS's recursive calls.
class _SearchBudget {
  int used = 0;
}
