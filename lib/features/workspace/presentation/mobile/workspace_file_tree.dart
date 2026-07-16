import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_git_status.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_tree_sort.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_diff_view.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_registry.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/workspace_file_share.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_ops/open_workspace_sheet.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_ops/workspace_file_ops.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_ops/workspace_search_sheet.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_tree/file_tree_empty.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_tree/file_tree_row.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_tree/file_tree_toolbar.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// The left page: a lazily-loaded file tree over [WorkspaceBackend], rooted at
/// the opened workspace ([currentWorkspaceProvider]). When nothing is open it
/// shows an empty state pointing back to the 起始屏.
///
/// Directories load their children on first expand and cache them. Tapping a
/// file opens it in a middle-page tab ([openWorkspaceFilesProvider]); the shell
/// then animates over to the editor. The 「打开文件夹」 button in the header opens
/// or switches workspaces (the old start screen lived here before).
///
/// 拆分：行组件/加载行在 `file_tree/file_tree_row.dart`，工具条（普通/多选）与
/// 排序菜单在 `file_tree/file_tree_toolbar.dart`，空状态在
/// `file_tree/file_tree_empty.dart`；本文件只保留树状态机与页面骨架。
///
/// The tree follows the active tab like an IDE: whenever the active file changes
/// (tab switch, session restore) its ancestor folders are expanded and the row
/// is scrolled into view and highlighted. Since paths are opaque `content://`
/// URIs (no derivable parent), the ancestor chain is found by a cached
/// depth-first search down from the root.

/// Fixed row height so scroll-to-index can target the active file precisely.
const double _kRowHeight = 38;

/// Cap on the directories the reveal fallback DFS may list. Without it, a
/// deep / wide project could trigger a full recursive `listDir` crawl (slow
/// on SAF and remote backends) just to locate one file.
const int _kMaxRevealSearchDirs = 64;

class WorkspaceFileTree extends ConsumerStatefulWidget {
  const WorkspaceFileTree({
    super.key,
    required this.topInset,
    required this.onBack,
  });

  final double topInset;

  /// Pops back to the middle page (the lone back affordance for this page).
  final VoidCallback onBack;

  @override
  ConsumerState<WorkspaceFileTree> createState() => _WorkspaceFileTreeState();
}

class _WorkspaceFileTreeState extends ConsumerState<WorkspaceFileTree>
    with AutomaticKeepAliveClientMixin {
  // Keep the tree alive when the PageView swaps to the middle page on file
  // select; otherwise this State is disposed and re-bound, collapsing the tree.
  @override
  bool get wantKeepAlive => true;

  // The tree root — the opened workspace's `root` (a `content://` URI for
  // SAF). `null` until a workspace is opened.
  String? _root;

  // Resolved from [currentWorkspaceProvider]; `null` until a workspace opens.
  WorkspaceBackend? get _backend => ref.read(workspacePreviewBackendProvider);

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
  // [_parentOf] is O(1) instead of scanning every cached listing per call
  // (which the ancestor-chain walk did once per level).
  final Map<String, String> _parentIndex = {};

  // The flattened rows produced by the last [build], reused by
  // [_scrollToPath] so revealing a file doesn't re-walk the whole tree.
  List<_TreeRow> _rows = const [];

  final ScrollController _scroll = ScrollController();

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

  // 多选模式：选中集合按路径索引，退出时清空。选择中点击行只切换勾选，
  // 不展开目录/不打开文件；长按菜单也禁用。
  bool _selecting = false;
  final Map<String, WorkspaceEntry> _selected = {};

  // Guards against re-revealing the same active file repeatedly and lets the
  // first build trigger an initial reveal (no change event fires for the
  // already-set active tab on entry).
  String? _revealedPath;
  bool _initialRevealDone = false;

  @override
  void initState() {
    super.initState();
    _bindWorkspace(ref.read(currentWorkspaceProvider));
  }

  @override
  void dispose() {
    _watchDebounce?.cancel();
    _watchRetry?.cancel();
    _gitDebounce?.cancel();
    _watchSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  // Resets the tree to a new workspace root (or none) and loads the root.
  void _bindWorkspace(Workspace? workspace) {
    _root = workspace?.root;
    _selecting = false;
    _selected.clear();
    _expanded.clear();
    _children.clear();
    _parentIndex.clear();
    _loading.clear();
    _listGen.clear();
    _sortedCache.clear();
    _revealedPath = null;
    _initialRevealDone = false;
    _rebindWatch();
    final root = _root;
    if (root != null) {
      _expanded.add(root);
      _load(root);
    }
    // Defer: _bindWorkspace can run inside build (workspace switch).
    Future.microtask(() {
      if (mounted) ref.read(gitStatusProvider.notifier).refresh();
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
        if (mounted && _root == boundRoot) _rebindWatch();
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
      _parentOf(event.path),
      if (event.fromPath != null) _parentOf(event.fromPath!),
    }) {
      if (dir != null && _children.containsKey(dir)) _pendingReload.add(dir);
    }
    if (_pendingReload.isEmpty) return;
    _watchDebounce?.cancel();
    _watchDebounce = Timer(const Duration(milliseconds: 200), _flushReload);
  }

  void _flushReload() {
    if (!mounted) return;
    final dirs = _pendingReload.toList();
    _pendingReload.clear();
    for (final dir in dirs) {
      if (_children.containsKey(dir)) _reload(dir);
    }
    _gitDebounce ??= Timer(const Duration(seconds: 1), () {
      _gitDebounce = null;
      if (mounted) ref.read(gitStatusProvider.notifier).refresh();
    });
  }

  // ===== reveal active file (IDE follow mode) =====

  // Lists [path] and caches it, awaiting the result (unlike [_load], which is
  // fire-and-forget). Returns null on failure.
  Future<List<WorkspaceEntry>?> _ensureChildren(String path) async {
    final cached = _children[path];
    if (cached != null) return cached;
    final backend = _backend;
    if (backend == null) return null;
    final gen = _bumpGen(path);
    try {
      final entries = await backend.listDir(path);
      if (!mounted) return null;
      if (_listGen[path] != gen) return _children[path];
      setState(() => _cacheChildren(path, entries));
      return entries;
    } catch (_) {
      return null;
    }
  }

  int _bumpGen(String path) => _listGen[path] = (_listGen[path] ?? 0) + 1;

  // Caches [path]'s listing and indexes each child's parent for [_parentOf].
  // Children that disappeared since the last listing get their stale parent
  // mapping and cached subtree evicted so [_parentOf] / reveal never resolve
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

  // The ancestor directory chain (root → … → parent) for an already-loaded
  // [target], or null when any ancestor isn't cached yet.
  List<String>? _knownChain(String target) {
    final root = _root;
    if (root == null) return null;
    final chain = <String>[];
    var cursor = _parentOf(target);
    while (cursor != null) {
      chain.add(cursor);
      if (cursor == root) {
        return chain.reversed.toList();
      }
      cursor = _parentOf(cursor);
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
    if (visited.used >= _kMaxRevealSearchDirs) return null;
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
      if (visited.used >= _kMaxRevealSearchDirs) return null;
    }
    return null;
  }

  // Expands [target]'s ancestors and scrolls its row to the middle, then marks
  // it revealed so repeat builds don't re-run the search. A failed reveal
  // (e.g. a listDir error) leaves the path unmarked so a later trigger can
  // retry it.
  Future<void> _revealActive(String target) async {
    if (_revealedPath == target) return;
    _revealedPath = target;
    final ok = await _revealPath(target);
    if (!ok && _revealedPath == target) _revealedPath = null;
  }

  // Expands [target]'s ancestors and scrolls its row to the middle. Also used
  // to locate a directory picked from the search sheet, so it carries no
  // active-file dedup guard. Returns whether the target was located.
  Future<bool> _revealPath(String target) async {
    final root = _root;
    if (root == null) return false;

    var chain = _knownChain(target);
    chain ??= await _deriveChain(root, target);
    chain ??= await _searchChain(root, target, [root], _SearchBudget());
    if (chain == null || !mounted) return false;

    final toExpand = chain.where((d) => !_expanded.contains(d)).toList();
    if (toExpand.isNotEmpty) {
      setState(() => _expanded.addAll(toExpand));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToPath(target));
    return true;
  }

  // Animates the active row to the vertical centre of the viewport.
  void _scrollToPath(String target) {
    final root = _root;
    if (root == null || !_scroll.hasClients) return;
    final index = _rows.indexWhere((r) => r.entry?.path == target);
    if (index < 0) return;
    final position = _scroll.position;
    final target0 =
        index * _kRowHeight - position.viewportDimension / 2 + _kRowHeight / 2;
    _scroll.animateTo(
      target0.clamp(0.0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _load(String path) async {
    final backend = _backend;
    if (backend == null) return;
    if (_children.containsKey(path) || _loading.contains(path)) return;
    setState(() => _loading.add(path));
    final gen = _bumpGen(path);
    try {
      final entries = await backend.listDir(path);
      if (!mounted || _listGen[path] != gen) return;
      setState(() {
        _loading.remove(path);
        _cacheChildren(path, entries);
      });
    } catch (e) {
      if (!mounted || _listGen[path] != gen) return;
      // Collapse on failure so the lazy-load-from-build path doesn't retry
      // (and toast) in a loop for a directory that keeps failing to list.
      setState(() {
        _loading.remove(path);
        _expanded.remove(path);
      });
      AppToast.error(context, '列目录失败 · $e');
    }
  }

  void _toggleDir(WorkspaceEntry entry) {
    final path = entry.path;
    if (_expanded.contains(path)) {
      setState(() => _expanded.remove(path));
    } else {
      setState(() => _expanded.add(path));
      _load(path);
    }
  }

  // Re-lists a single directory (after a write op) and refreshes its rows,
  // bypassing the load-once cache guard.
  Future<void> _reload(String path) async {
    final backend = _backend;
    if (backend == null) return;
    setState(() => _loading.add(path));
    final gen = _bumpGen(path);
    try {
      final entries = await backend.listDir(path);
      if (!mounted || _listGen[path] != gen) return;
      setState(() {
        _loading.remove(path);
        _cacheChildren(path, entries);
      });
    } catch (e) {
      if (!mounted || _listGen[path] != gen) return;
      setState(() => _loading.remove(path));
      AppToast.error(context, '列目录失败 · $e');
    }
  }

  // Ensures a directory is expanded so freshly-created/moved children show.
  void _ensureExpanded(String path) {
    if (_expanded.contains(path)) return;
    setState(() => _expanded.add(path));
    _load(path);
  }

  // The cached parent directory of an entry. Paths are opaque `content://`
  // URIs, so the parent can only be recovered from the loaded tree structure.
  String? _parentOf(String childPath) => _parentIndex[childPath];

  // A row's git badge: the file's own status, or a roll-up marker when a
  // directory contains changed descendants.
  GitFileStatus? _gitStatusOf(GitStatusOverview? snap, WorkspaceEntry entry) {
    if (snap == null) return null;
    final direct = snap.statusOf(entry.path);
    if (direct != null) return direct;
    if (entry.isDirectory && snap.dirHasChanges(entry.path)) {
      return GitFileStatus.modified;
    }
    return null;
  }

  // 「Git 对比」：HEAD 版本 vs 当前工作区内容，只读 diff 面板。仅 exec 后端
  // 可用，此时路径是真实 POSIX 路径，可以安全地剪出仓内相对路径。
  Future<void> _showGitDiff(WorkspaceEntry entry) async {
    final backend = _backend;
    final repo = ref.read(gitStatusProvider)?.repoOf(entry.path);
    final status = repo?.statusOf(entry.path);
    if (backend == null || repo == null || status == null) return;
    final prefix = '${repo.repoRoot}/';
    if (!entry.path.startsWith(prefix)) return;
    final rel = entry.path.substring(prefix.length);
    try {
      var oldText = '';
      if (status != GitFileStatus.untracked &&
          status != GitFileStatus.added) {
        final show = await backend.exec(
          'git -c core.quotepath=off show ${shellQuoteArg('HEAD:$rel')}',
          workingDirectory: repo.repoRoot,
          timeout: const Duration(seconds: 20),
        );
        if (show.exitCode == 0) oldText = show.stdout;
      }
      var newText = '';
      if (status != GitFileStatus.deleted) {
        newText = await backend.readFile(entry.path);
      }
      if (!mounted) return;
      await showReadOnlyDiffSheet(
        context,
        fileName: entry.name,
        subtitle: '红色 - 为 HEAD 版本，绿色 + 为当前工作区内容（$rel）',
        oldText: oldText,
        newText: newText,
      );
    } catch (e) {
      if (mounted) AppToast.error(context, 'Git 对比失败 · $e');
    }
  }

  // Drops every cached listing and reloads the root, so the tree reflects any
  // out-of-band changes. Expand state for still-present directories is kept;
  // their listings reload lazily from [_appendRows] as they become visible.
  void _refresh() {
    final root = _root;
    if (root == null) return;
    setState(() {
      _children.clear();
      _parentIndex.clear();
      _loading.clear();
      _sortedCache.clear();
    });
    _load(root);
    ref.read(gitStatusProvider.notifier).refresh(rediscover: true);
  }

  // Opens the search sheet; a picked file opens in an editor tab (the shell
  // then slides to the middle page — with a 「跳到某行」 request when a content
  // match line was picked), a picked directory is revealed in place.
  Future<void> _openSearch() async {
    final backend = _backend;
    final root = _root;
    if (backend == null || root == null) return;
    final pick = await showWorkspaceSearchSheet(
      context,
      backend: backend,
      rootPath: root,
    );
    if (pick == null || !mounted) return;
    final entry = pick.entry;
    if (entry.isDirectory) {
      await _revealPath(entry.path);
    } else {
      ref.read(openWorkspaceFilesProvider.notifier).open(
            entry,
            dirtyPaths: ref.read(dirtyFilesProvider),
            line: pick.line,
          );
    }
  }

  void _toggleSelected(WorkspaceEntry entry) {
    setState(() {
      if (_selected.containsKey(entry.path)) {
        _selected.remove(entry.path);
      } else {
        _selected[entry.path] = entry;
      }
    });
  }

  // Runs a batch op over the current selection, then exits select mode.
  Future<void> _batch(
    Future<void> Function(List<WorkspaceEntry> sel) op,
  ) async {
    final sel = _selected.values.toList();
    if (sel.isEmpty) return;
    setState(() {
      _selecting = false;
      _selected.clear();
    });
    await op(sel);
  }

  // Collapses everything back to the root. Cached children stay so re-expanding
  // is instant.
  void _collapseAll() {
    final root = _root;
    setState(() {
      _expanded.clear();
      if (root != null) _expanded.add(root);
    });
  }

  // Walks the cached tree depth-first into flat rows the ListView renders.
  // Hidden entries are skipped unless the 「显示隐藏文件」 toggle is on; each
  // directory's entries are ordered by the picked sort mode (directories
  // first) at render time, so switching modes never needs a reload.
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

  void _appendRows(
    String path,
    int depth,
    List<_TreeRow> out,
    bool showHidden,
    TreeSortMode sortMode,
  ) {
    final entries = _children[path];
    if (entries == null) return;
    for (final entry in _sortedChildren(path, entries, sortMode)) {
      if (!showHidden && entry.isHidden) continue;
      final expanded = _expanded.contains(entry.path);
      out.add(_TreeRow(entry: entry, depth: depth, expanded: expanded));
      if (entry.isDirectory && expanded) {
        if (_loading.contains(entry.path)) {
          out.add(_TreeRow.loading(depth + 1));
        } else if (!_children.containsKey(entry.path)) {
          // Expanded but not cached (e.g. right after 刷新 cleared the
          // caches): show the spinner and reload lazily.
          out.add(_TreeRow.loading(depth + 1));
          scheduleMicrotask(() {
            if (mounted) _load(entry.path);
          });
        } else {
          _appendRows(entry.path, depth + 1, out, showHidden, sortMode);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final topPad = MediaQuery.paddingOf(context).top + widget.topInset + 8;
    final selectedPath = ref.watch(openWorkspaceFilesProvider).activePath;

    // Follow the active tab: reveal it whenever it changes.
    ref.listen(openWorkspaceFilesProvider.select((s) => s.activePath), (
      _,
      next,
    ) {
      if (next != null) _revealActive(next);
    });

    // Re-bind whenever the opened workspace changes (open / switch / close).
    final workspace = ref.watch(currentWorkspaceProvider);
    if (workspace?.root != _root) {
      _bindWorkspace(workspace);
    }

    // No change event fires for an already-set active tab on entry / restore;
    // kick off the first reveal once the root is bound.
    if (!_initialRevealDone && _root != null && selectedPath != null) {
      _initialRevealDone = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _revealActive(selectedPath),
      );
    }

    final showHidden = ref.watch(showHiddenFilesProvider);
    final sortMode = ref.watch(treeSortModeProvider);
    final gitSnap = ref.watch(gitStatusProvider);
    final root = _root;
    final rows = <_TreeRow>[];
    if (root != null) {
      _appendRows(root, 0, rows, showHidden, sortMode);
    }
    _rows = rows;
    final rootLoading = root != null && _loading.contains(root) && rows.isEmpty;

    final backend = _backend;
    // Ops are built even for read-only backends: the long-press menu still
    // offers the non-mutating actions (复制路径/详情); write actions are gated
    // inside by capabilities.canWrite.
    final ops = (root != null && backend != null)
        ? WorkspaceFileOps(
            context: context,
            backend: backend,
            rootPath: root,
            rootName: workspace?.name ?? '工作区',
            reloadDir: _reload,
            ensureExpanded: _ensureExpanded,
            parentOf: _parentOf,
            canGitDiff: (entry) =>
                !entry.isDirectory &&
                backend.capabilities.canExec &&
                ref.read(gitStatusProvider)?.statusOf(entry.path) != null,
            onGitDiff: _showGitDiff,
            onFileCreated: (entry) =>
                ref.read(openWorkspaceFilesProvider.notifier).open(
                      entry,
                      dirtyPaths: ref.read(dirtyFilesProvider),
                    ),
            onShare: (entry) =>
                shareWorkspaceFile(context, ref, entry: entry),
          )
        : null;
    final canWrite = backend?.capabilities.canWrite ?? false;

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(4, topPad, 4, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '返回',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(LucideIcons.arrowLeft, size: 20),
                    onPressed: widget.onBack,
                  ),
                  Icon(
                    LucideIcons.folderTree,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      workspace?.name ?? '工作区',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '搜索文件',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(LucideIcons.search, size: 18),
                    onPressed: root == null ? null : _openSearch,
                  ),
                  IconButton(
                    tooltip: '打开文件夹',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(LucideIcons.folderOpen, size: 18),
                    onPressed: () => showOpenWorkspaceSheet(context, ref),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: _selecting
                  ? FileTreeSelectionToolbar(
                      selectedCount: _selected.length,
                      actionsEnabled: canWrite && _selected.isNotEmpty,
                      onMove: () => _batch((sel) => ops!.moveMany(sel)),
                      onCopy: () => _batch((sel) => ops!.copyMany(sel)),
                      onDelete: () => _batch((sel) => ops!.deleteMany(sel)),
                      onExit: () => setState(() {
                        _selecting = false;
                        _selected.clear();
                      }),
                    )
                  : FileTreeToolbar(
                      hasRoot: root != null,
                      canWrite: canWrite,
                      canCreate: ops != null && canWrite,
                      gitEnabled: gitSnap != null,
                      gitChangeCount: gitSnap?.totalChanges ?? 0,
                      onOpenGit: () =>
                          context.push(AppRouter.gitReviewPath),
                      showHidden: showHidden,
                      sortMode: sortMode,
                      onNewFile: () => ops?.newFile(ops.rootPath),
                      onNewFolder: () => ops?.newFolder(ops.rootPath),
                      onEnterSelect: () =>
                          setState(() => _selecting = true),
                      onOpenTrash: () => ops?.openTrash(),
                      onSortSelected: (m) =>
                          ref.read(treeSortModeProvider.notifier).set(m),
                      onToggleHidden: () => ref
                          .read(showHiddenFilesProvider.notifier)
                          .toggle(),
                      onRefresh: _refresh,
                      onCollapseAll: _collapseAll,
                    ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Expanded(
              child: root == null
                  ? FileTreeEmpty(
                      theme: theme,
                      onOpen: () => showOpenWorkspaceSheet(context, ref),
                    )
                  : rootLoading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemExtent: _kRowHeight,
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final row = rows[i];
                        if (row.isLoading) {
                          return FileTreeLoadingRow(depth: row.depth);
                        }
                        final entry = row.entry!;
                        return FileTreeRow(
                          entry: entry,
                          depth: row.depth,
                          expanded: row.expanded,
                          selected: selectedPath == entry.path,
                          gitStatus: _gitStatusOf(gitSnap, entry),
                          checked: _selecting
                              ? _selected.containsKey(entry.path)
                              : null,
                          onTap: () {
                            if (_selecting) {
                              _toggleSelected(entry);
                            } else if (entry.isDirectory) {
                              _toggleDir(entry);
                            } else {
                              ref
                                  .read(openWorkspaceFilesProvider.notifier)
                                  .open(
                                    entry,
                                    dirtyPaths: ref.read(dirtyFilesProvider),
                                  );
                            }
                          },
                          onLongPress: ops == null || _selecting
                              ? null
                              : () => ops.showEntryMenu(entry),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Mutable listDir counter shared across a reveal DFS's recursive calls.
class _SearchBudget {
  int used = 0;
}

class _TreeRow {
  const _TreeRow({
    required this.entry,
    required this.depth,
    required this.expanded,
  }) : isLoading = false;

  const _TreeRow.loading(this.depth)
    : entry = null,
      expanded = false,
      isLoading = true;

  final WorkspaceEntry? entry;
  final int depth;
  final bool expanded;
  final bool isLoading;
}

