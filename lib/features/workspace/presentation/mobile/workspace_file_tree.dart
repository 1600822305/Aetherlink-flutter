import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';

import 'package:aetherlink_flutter/features/workspace/application/file_tree_controller.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_git_status.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_diff_view.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_registry.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/workspace_file_share.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_ops/file_history_sheet.dart';
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
/// Tapping a file opens it in a middle-page tab ([openWorkspaceFilesProvider]);
/// the shell then animates over to the editor. The workspace title in the
/// header opens or switches workspaces.
///
/// 拆分：树状态机（children 缓存 / listGen 竞态防护 / watch 去抖 / reveal /
/// 多选）在 application 层的 [FileTreeController]；行组件在
/// `file_tree/file_tree_row.dart`，工具条在 `file_tree/file_tree_toolbar.dart`，
/// 空状态在 `file_tree/file_tree_empty.dart`；本文件只保留渲染与事件转发。
///
/// The tree follows the active tab like an IDE: whenever the active file
/// changes its ancestor folders are expanded and the row is scrolled into
/// view and highlighted.

/// Fixed row height so scroll-to-index can target the active file precisely.
const double _kRowHeight = 38;

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

  late final FileTreeController _tree = FileTreeController(
    onError: (message) {
      if (mounted) AppToast.error(context, message);
    },
    onGitRefresh: () {
      if (mounted) ref.read(gitStatusProvider.notifier).refresh();
    },
    onReveal: (path) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToPath(path));
    },
  );

  // The flattened rows produced by the last [build], reused by
  // [_scrollToPath] so revealing a file doesn't re-walk the whole tree.
  List<FileTreeRowData> _rows = const [];

  final ScrollController _scroll = ScrollController();

  // Guards the first reveal (no change event fires for the already-set active
  // tab on entry).
  bool _initialRevealDone = false;

  @override
  void initState() {
    super.initState();
    _tree.addListener(_onTreeChanged);
    _tree.bind(
      ref.read(currentWorkspaceProvider)?.root,
      ref.read(workspacePreviewBackendProvider),
    );
  }

  void _onTreeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tree.removeListener(_onTreeChanged);
    _tree.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // Animates the active row to the vertical centre of the viewport.
  void _scrollToPath(String target) {
    if (_tree.root == null || !_scroll.hasClients) return;
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
    final backend = _tree.backend;
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

  void _refresh() {
    _tree.refresh();
    ref.read(gitStatusProvider.notifier).refresh(rediscover: true);
  }

  // Opens the search sheet; a picked file opens in an editor tab (the shell
  // then slides to the middle page — with a 「跳到某行」 request when a content
  // match line was picked), a picked directory is revealed in place.
  Future<void> _openSearch() async {
    final backend = _tree.backend;
    final root = _tree.root;
    if (backend == null || root == null) return;
    final pick = await showWorkspaceSearchSheet(
      context,
      backend: backend,
      rootPath: root,
    );
    if (pick == null || !mounted) return;
    final entry = pick.entry;
    if (entry.isDirectory) {
      await _tree.revealPath(entry.path);
    } else {
      ref.read(openWorkspaceFilesProvider.notifier).open(
            entry,
            dirtyPaths: ref.read(dirtyFilesProvider),
            line: pick.line,
          );
    }
  }

  // The ops instance from the last build, so the paste callback (captured by
  // the entry menu) always uses the current tree wiring.
  WorkspaceFileOps? _ops;

  // Pastes the file-tree clipboard into [dest]; a successful cut-paste
  // consumes the clipboard (copy-paste stays for repeated pastes).
  Future<void> _pasteClipboard(WorkspaceFileOps ops, String dest) async {
    final clip = ref.read(fileTreeClipboardProvider);
    if (clip == null || clip.workspaceRoot != _tree.root) return;
    final cut = clip.mode == FileClipboardMode.cut;
    final done = await ops.pasteEntries(clip.entries, cut: cut, dest: dest);
    if (cut && done) ref.read(fileTreeClipboardProvider.notifier).clear();
  }

  // Runs a batch op over the current selection, then exits select mode.
  Future<void> _batch(
    Future<void> Function(List<WorkspaceEntry> sel) op,
  ) async {
    final sel = _tree.takeSelection();
    if (sel.isEmpty) return;
    await op(sel);
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
      if (next != null) _tree.revealActive(next);
    });

    // Re-bind whenever the opened workspace changes (open / switch / close).
    final workspace = ref.watch(currentWorkspaceProvider);
    if (workspace?.root != _tree.root) {
      _initialRevealDone = false;
      _tree.bind(workspace?.root, ref.read(workspacePreviewBackendProvider));
    }

    // No change event fires for an already-set active tab on entry / restore;
    // kick off the first reveal once the root is bound.
    if (!_initialRevealDone && _tree.root != null && selectedPath != null) {
      _initialRevealDone = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _tree.revealActive(selectedPath),
      );
    }

    final showHidden = ref.watch(showHiddenFilesProvider);
    final sortMode = ref.watch(treeSortModeProvider);
    final gitSnap = ref.watch(gitStatusProvider);
    final root = _tree.root;
    final rows = _tree.buildRows(showHidden, sortMode);
    _rows = rows;
    final rootLoading = _tree.rootLoading && rows.isEmpty;

    final backend = _tree.backend;
    // Ops are built even for read-only backends: the long-press menu still
    // offers the non-mutating actions (复制路径/详情); write actions are gated
    // inside by capabilities.canWrite.
    final clipboard = ref.watch(fileTreeClipboardProvider);
    final canPaste = clipboard != null &&
        clipboard.workspaceRoot == root &&
        (backend?.capabilities.canWrite ?? false);
    final ops = (root != null && backend != null)
        ? WorkspaceFileOps(
            context: context,
            backend: backend,
            rootPath: root,
            rootName: workspace?.name ?? '工作区',
            reloadDir: _tree.reload,
            ensureExpanded: _tree.ensureExpanded,
            parentOf: _tree.parentOf,
            canGitDiff: (entry) =>
                !entry.isDirectory &&
                backend.capabilities.canExec &&
                ref.read(gitStatusProvider)?.statusOf(entry.path) != null,
            onGitDiff: _showGitDiff,
            onFileHistory: (entry) => showFileHistorySheet(
              context,
              ref,
              backend: backend,
              entry: entry,
            ),
            onFileCreated: (entry) =>
                ref.read(openWorkspaceFilesProvider.notifier).open(
                      entry,
                      dirtyPaths: ref.read(dirtyFilesProvider),
                    ),
            canPaste: canPaste,
            onClipboardSet: (entries, {required cut}) =>
                ref.read(fileTreeClipboardProvider.notifier).set(
                      entries,
                      cut ? FileClipboardMode.cut : FileClipboardMode.copy,
                      root,
                    ),
            onPaste: (dest) async {
              final ops = _ops;
              if (ops != null) await _pasteClipboard(ops, dest);
            },
            onShare: (entry) =>
                shareWorkspaceFile(context, ref, entry: entry),
          )
        : null;
    _ops = ops;
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
                  // 标题即工作区切换入口：点名称弹出打开/切换工作区面板。
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => showOpenWorkspaceSheet(context, ref),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.folderTree,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                workspace?.name ?? '工作区',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              LucideIcons.chevronDown,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: _tree.selecting
                  ? FileTreeSelectionToolbar(
                      selectedCount: _tree.selected.length,
                      actionsEnabled: canWrite && _tree.selected.isNotEmpty,
                      onMove: () => _batch((sel) => ops!.moveMany(sel)),
                      onCopy: () => _batch((sel) => ops!.copyMany(sel)),
                      onDelete: () => _batch((sel) => ops!.deleteMany(sel)),
                      onExit: _tree.exitSelect,
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
                      onOpenSearch: _openSearch,
                      onEnterSelect: _tree.enterSelect,
                      onOpenTrash: () => ops?.openTrash(),
                      onSortSelected: (m) =>
                          ref.read(treeSortModeProvider.notifier).set(m),
                      onToggleHidden: () => ref
                          .read(showHiddenFilesProvider.notifier)
                          .toggle(),
                      onRefresh: _refresh,
                      onCollapseAll: _tree.collapseAll,
                      canPaste: canPaste,
                      onPasteToRoot: ops == null
                          ? null
                          : () => _pasteClipboard(ops, ops.rootPath),
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
                          checked: _tree.selecting
                              ? _tree.selected.containsKey(entry.path)
                              : null,
                          onTap: () {
                            if (_tree.selecting) {
                              _tree.toggleSelected(entry);
                            } else if (entry.isDirectory) {
                              _tree.toggleDir(entry);
                            } else {
                              ref
                                  .read(openWorkspaceFilesProvider.notifier)
                                  .open(
                                    entry,
                                    dirtyPaths: ref.read(dirtyFilesProvider),
                                  );
                            }
                          },
                          onLongPress: ops == null || _tree.selecting
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
