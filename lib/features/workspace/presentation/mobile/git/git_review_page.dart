// 「Git 变更」 page (route /workspace/git)：文件树工具栏的 git 按钮进入。
//
// 两个 Tab：
// - 变更：已暂存 / 未暂存 两组条目（暂存开关、点击看 diff、长按丢弃），
//   底部固定提交区（仅有已暂存条目时可提交）。
// - 历史：最近提交列表，点开看该提交改动的文件，再点文件看 diff。
//
// 仅对 canExec 的后端（SSH / PRoot / Termux）可用——与 gitStatusProvider
// 同前提；入口按钮在没有 git 仓库时不可点，此页只做兜底空态。
// 危险操作（丢弃）一律红色 + 确认弹窗；每次变更后同步刷新
// gitStatusProvider，让文件树染色跟上。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_git_review.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_git_status.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_diff_view.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

class GitReviewPage extends ConsumerStatefulWidget {
  const GitReviewPage({super.key});

  @override
  ConsumerState<GitReviewPage> createState() => _GitReviewPageState();
}

class _GitReviewPageState extends ConsumerState<GitReviewPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _message = TextEditingController();

  /// Every repo discovered under the workspace (多仓库容器式工作区可能不止
  /// 一个)；[_repoRoot] is the currently selected one.
  List<String> _repos = const [];
  String? _repoRoot;
  GitReviewService? _service;
  GitReviewSnapshot? _snapshot;
  List<GitCommitInfo>? _commits;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  // 失效推送：订阅后端的文件变更流，当前仓库内的变更去抖后自动刷新
  // 状态，不用手动点刷新；页面自己的 git 操作在 [_mutate] 里已同步
  // 刷新，busy 期间的事件直接忽略。
  StreamSubscription<WorkspaceChangeEvent>? _watchSub;
  Timer? _watchDebounce;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      // 首次切到「历史」时懒加载提交列表。
      if (_tabs.index == 1 && _commits == null) _loadLog();
    });
    _bind();
  }

  @override
  void dispose() {
    _watchDebounce?.cancel();
    _watchSub?.cancel();
    _tabs.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _bind() async {
    final backend = ref.read(workspacePreviewBackendProvider);
    final workspace = ref.read(currentWorkspaceProvider);
    if (backend == null || workspace == null || !backend.capabilities.canExec) {
      setState(() {
        _loading = false;
        _error = '当前工作区不支持 Git（需要 SSH / 内置终端 / Termux 后端）';
      });
      return;
    }
    // 复用 gitStatusProvider 的发现缓存，进页不再重复扫描。
    final repos = await ref.read(gitStatusProvider.notifier).repoRoots();
    if (!mounted) return;
    if (repos.isEmpty) {
      setState(() {
        _loading = false;
        _error = '工作区内没有找到 Git 仓库';
      });
      return;
    }
    _repos = repos;
    _selectRepo(repos.first);
    if (backend.capabilities.canWatch) {
      _watchSub = backend.watch().listen((event) {
        final root = _repoRoot;
        if (root == null || _busy) return;
        if (event.path != root && !event.path.startsWith('$root/')) return;
        _watchDebounce?.cancel();
        _watchDebounce = Timer(const Duration(milliseconds: 500), () {
          if (!mounted || _busy) return;
          _refreshStatus();
        });
      });
    }
  }

  /// Switches the page onto [repoRoot]: rebuilds the service and drops the
  /// per-repo state before reloading.
  void _selectRepo(String repoRoot) {
    final backend = ref.read(workspacePreviewBackendProvider);
    if (backend == null) return;
    setState(() {
      _repoRoot = repoRoot;
      _service = GitReviewService(backend: backend, repoRoot: repoRoot);
      _snapshot = null;
      _commits = null;
      _loading = true;
      _error = null;
    });
    _refreshStatus();
    if (_tabs.index == 1) _loadLog();
  }

  String get _repoName {
    final root = _repoRoot ?? '';
    final slash = root.lastIndexOf('/');
    return slash < 0 ? root : root.substring(slash + 1);
  }

  Future<void> _refreshStatus() async {
    final service = _service;
    if (service == null) return;
    setState(() => _loading = _snapshot == null);
    try {
      final snapshot = await service.loadStatus();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '读取 Git 状态失败 · $e';
      });
    }
  }

  Future<void> _loadLog() async {
    final service = _service;
    if (service == null) return;
    try {
      final commits = await service.log();
      if (mounted) setState(() => _commits = commits);
    } catch (e) {
      if (mounted) AppToast.error(context, '读取提交历史失败 · $e');
    }
  }

  /// Runs one mutating git op with the shared busy gate, then reloads the
  /// status here and in the file tree's provider. Returns whether it
  /// succeeded.
  Future<bool> _mutate(Future<void> Function(GitReviewService s) op) async {
    final service = _service;
    if (service == null || _busy) return false;
    setState(() => _busy = true);
    var ok = false;
    try {
      await op(service);
      ok = true;
      await _refreshStatus();
      // 提交/丢弃会改变历史与树染色：一并失效。
      _commits = null;
      if (_tabs.index == 1) await _loadLog();
      ref.read(gitStatusProvider.notifier).refresh();
    } on GitCommandException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    } catch (e) {
      if (mounted) AppToast.error(context, '操作失败 · $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return ok;
  }

  Future<void> _commit() async {
    final message = _message.text.trim();
    if (message.isEmpty) {
      AppToast.info(context, '先填写提交信息');
      return;
    }
    final ok = await _mutate((s) => s.commit(message));
    if (ok && mounted) {
      _message.clear();
      AppToast.success(context, '已提交');
    }
  }

  Future<void> _confirmDiscard(GitChangeEntry entry) async {
    final ok = await _confirmDanger(
      title: '丢弃改动？',
      body: entry.status == GitFileStatus.untracked
          ? '将删除未跟踪的「${entry.path}」，此操作不可撤销。'
          : '「${entry.path}」的未暂存改动将恢复为暂存区内容，此操作不可撤销。',
      action: '丢弃',
    );
    if (ok) await _mutate((s) => s.discard(entry));
  }

  Future<void> _confirmDiscardAll() async {
    final ok = await _confirmDanger(
      title: '丢弃全部未暂存改动？',
      body: '所有未暂存的修改将被恢复，未跟踪的文件将被删除，此操作不可撤销。',
      action: '全部丢弃',
    );
    if (ok) await _mutate((s) => s.discardAll());
  }

  Future<bool> _confirmDanger({
    required String title,
    required String body,
    required String action,
  }) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _showEntryDiff(GitChangeEntry entry) async {
    final service = _service;
    if (service == null) return;
    try {
      final (oldText, newText) = await service.diffTexts(entry);
      if (!mounted) return;
      await showReadOnlyDiffSheet(
        context,
        fileName: entry.name,
        subtitle: entry.area == GitChangeArea.staged
            ? '红色 - 为 HEAD 版本，绿色 + 为已暂存内容（${entry.path}）'
            : '红色 - 为暂存区版本，绿色 + 为工作区内容（${entry.path}）',
        oldText: oldText,
        newText: newText,
      );
    } catch (e) {
      if (mounted) AppToast.error(context, '读取 diff 失败 · $e');
    }
  }

  // ===== v2：同步 / 分支 / 回滚 =====

  Future<void> _sync(String action) async {
    switch (action) {
      case 'pull':
        final ok = await _mutate((s) => s.pull());
        if (ok && mounted) AppToast.success(context, '已拉取');
      case 'push':
        final branch = _snapshot?.branch.branch ?? '';
        final ok = await _mutate((s) => s.push(branch));
        if (ok && mounted) AppToast.success(context, '已推送');
      case 'fetch':
        final ok = await _mutate((s) => s.fetch());
        if (ok && mounted) AppToast.success(context, '已获取远端更新');
      case 'branches':
        await _showBranchSheet();
      case 'new-branch':
        await _createBranch();
    }
  }

  Future<void> _showBranchSheet() async {
    final service = _service;
    if (service == null) return;
    List<GitBranchItem> branches;
    try {
      branches = await service.branches();
    } catch (e) {
      if (mounted) AppToast.error(context, '读取分支失败 · $e');
      return;
    }
    if (!mounted) return;
    final theme = Theme.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                '切换分支',
                style: theme.textTheme.titleSmall,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final b in branches)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        LucideIcons.gitBranch,
                        size: 18,
                        color: b.isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        b.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              b.isCurrent ? FontWeight.w600 : null,
                          color: b.isCurrent
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                      trailing: b.isCurrent
                          ? Icon(LucideIcons.check,
                              size: 16,
                              color: theme.colorScheme.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop(b.name),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null ||
        !mounted ||
        branches.any((b) => b.isCurrent && b.name == picked)) {
      return;
    }
    final ok = await _mutate((s) => s.checkout(picked));
    if (ok && mounted) AppToast.success(context, '已切换到 $picked');
  }

  Future<void> _createBranch() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建分支'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '分支名称'),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('创建并切换'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    final ok = await _mutate((s) => s.createBranch(name));
    if (ok && mounted) AppToast.success(context, '已创建并切换到 $name');
  }

  Future<void> _confirmRevert(GitCommitInfo commit) async {
    final ok = await _confirmDanger(
      title: '撤销此提交？',
      body: '将创建一个新提交撤销「${commit.shortSha} ${commit.subject}」的改动，'
          '历史记录不会丢失。',
      action: '撤销',
    );
    if (ok) {
      final done = await _mutate((s) => s.revertCommit(commit.sha));
      if (done && mounted) AppToast.success(context, '已撤销 ${commit.shortSha}');
    }
  }

  Future<void> _confirmResetHard(GitCommitInfo commit) async {
    final ok = await _confirmDanger(
      title: '回退到此提交？',
      body: '当前分支将硬回退到「${commit.shortSha} ${commit.subject}」，'
          '之后的提交和所有未提交改动都会丢失，此操作不可撤销。',
      action: '硬回退',
    );
    if (ok) {
      final done = await _mutate((s) => s.resetHard(commit.sha));
      if (done && mounted) {
        AppToast.success(context, '已回退到 ${commit.shortSha}');
      }
    }
  }

  Future<void> _confirmRestoreFile(
    GitCommitInfo commit,
    GitCommitFile file,
  ) async {
    final ok = await _confirmDanger(
      title: '恢复文件到此版本？',
      body: '「${file.path}」将恢复为 ${commit.shortSha} 时的内容'
          '（写入工作区并暂存），当前未提交的改动会被覆盖。',
      action: '恢复',
    );
    if (ok) {
      final done =
          await _mutate((s) => s.restoreFileAt(commit.sha, file.path));
      if (done && mounted) AppToast.success(context, '已恢复 ${file.path}');
    }
  }

  Future<void> _showCommitDetail(GitCommitInfo commit) async {
    final service = _service;
    if (service == null) return;
    List<GitCommitFile> files;
    try {
      files = await service.commitFiles(commit.sha);
    } catch (e) {
      if (mounted) AppToast.error(context, '读取提交内容失败 · $e');
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CommitDetailSheet(
        commit: commit,
        files: files,
        onRevert: () {
          Navigator.of(context).pop();
          _confirmRevert(commit);
        },
        onResetHard: () {
          Navigator.of(context).pop();
          _confirmResetHard(commit);
        },
        onRestoreFile: (file) {
          Navigator.of(context).pop();
          _confirmRestoreFile(commit, file);
        },
        onOpenFile: (file) async {
          try {
            final (oldText, newText) =
                await service.commitDiffTexts(commit.sha, file);
            if (!context.mounted) return;
            await showReadOnlyDiffSheet(
              context,
              fileName: _fileName(file.path),
              subtitle:
                  '红色 - 为父提交版本，绿色 + 为 ${commit.shortSha} 版本（${file.path}）',
              oldText: oldText,
              newText: newText,
            );
          } catch (e) {
            if (context.mounted) AppToast.error(context, '读取 diff 失败 · $e');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = _snapshot;
    // 顶栏沿用设置页的扁平 HeaderBar 风格（surface 底 + 1px 底边框 +
    // primary 色返回箭头 + 18/600 左对齐标题，settings_page.dart 同款）。
    final title = _repos.length > 1 && _repoName.isNotEmpty
        ? '$_repoName · ${snapshot?.branch.branch ?? '…'}'
        : (snapshot?.branch.branch.isNotEmpty == true
            ? 'Git · ${snapshot!.branch.branch}'
            : 'Git');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          color: theme.colorScheme.primary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(title, overflow: TextOverflow.ellipsis),
            ),
            if (snapshot != null &&
                (snapshot.branch.ahead > 0 || snapshot.branch.behind > 0)) ...[
              const SizedBox(width: 8),
              _AheadBehindChip(
                ahead: snapshot.branch.ahead,
                behind: snapshot.branch.behind,
              ),
            ],
          ],
        ),
        actions: [
          if (_repos.length > 1)
            PopupMenuButton<String>(
              tooltip: '切换仓库',
              icon: const Icon(LucideIcons.folderGit2, size: 20),
              iconColor: theme.colorScheme.onSurfaceVariant,
              onSelected: _busy ? null : _selectRepo,
              itemBuilder: (context) => [
                for (final root in _repos)
                  CheckedPopupMenuItem<String>(
                    value: root,
                    checked: root == _repoRoot,
                    child: Text(
                      root.substring(root.lastIndexOf('/') + 1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            color: theme.colorScheme.onSurfaceVariant,
            onPressed: _busy
                ? null
                : () {
                    _refreshStatus();
                    if (_tabs.index == 1) _loadLog();
                  },
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
            iconColor: theme.colorScheme.onSurfaceVariant,
            enabled: !_busy && _service != null,
            onSelected: _sync,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'pull', child: Text('拉取 (pull)')),
              PopupMenuItem(value: 'push', child: Text('推送 (push)')),
              PopupMenuItem(value: 'fetch', child: Text('获取远端 (fetch)')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'branches', child: Text('切换分支…')),
              PopupMenuItem(value: 'new-branch', child: Text('新建分支…')),
            ],
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          dividerColor: Colors.transparent,
          tabs: const [Tab(text: '变更'), Tab(text: '历史')],
        ),
      ),
      body: _loading
          ? const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : _error != null
              ? _ErrorState(theme: theme, message: _error!)
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildChangesTab(theme, snapshot!),
                    _buildHistoryTab(theme),
                  ],
                ),
    );
  }

  Widget _buildChangesTab(ThemeData theme, GitReviewSnapshot snapshot) {
    if (snapshot.isClean) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.circleCheck,
              size: 40,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              '工作区很干净',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (snapshot.staged.isNotEmpty) ...[
                _ChangeGroupCard(
                  title: '已暂存 · ${snapshot.staged.length}',
                  actionLabel: '全部取消',
                  actionEnabled: !_busy,
                  onAction: () => _mutate((s) => s.unstageAll()),
                  children: [
                    for (final entry in snapshot.staged)
                      _ChangeRow(
                        entry: entry,
                        busy: _busy,
                        onTap: () => _showEntryDiff(entry),
                        onToggle: () => _mutate((s) => s.unstage(entry.path)),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              if (snapshot.unstaged.isNotEmpty)
                _ChangeGroupCard(
                  title: '未暂存 · ${snapshot.unstaged.length}',
                  actionLabel: '全部暂存',
                  actionEnabled: !_busy,
                  onAction: () => _mutate((s) => s.stageAll()),
                  dangerLabel: '全部丢弃',
                  onDanger: _busy ? null : _confirmDiscardAll,
                  children: [
                    for (final entry in snapshot.unstaged)
                      _ChangeRow(
                        entry: entry,
                        busy: _busy,
                        onTap: () => _showEntryDiff(entry),
                        onToggle: () => _mutate((s) => s.stage(entry.path)),
                        onDiscard: () => _confirmDiscard(entry),
                      ),
                  ],
                ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
        Container(
          color: theme.colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: snapshot.staged.isEmpty
                            ? '先暂存要提交的改动'
                            : '提交信息…',
                        isDense: true,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: theme.colorScheme.primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed:
                        snapshot.staged.isEmpty || _busy ? null : _commit,
                    icon:
                        const Icon(LucideIcons.gitCommitHorizontal, size: 16),
                    label: Text('提交 (${snapshot.staged.length})'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab(ThemeData theme) {
    final commits = _commits;
    if (commits == null) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (commits.isEmpty) {
      return Center(
        child: Text(
          '还没有提交记录',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _GroupCard(
          children: [
            for (final commit in commits)
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 15,
                  backgroundColor: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.7),
                  child: Text(
                    commit.author.isEmpty
                        ? '?'
                        : commit.author.characters.first.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                title: Text(
                  commit.subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                subtitle: Text(
                  '${commit.author} · ${_relativeTime(commit.time)} · ${commit.shortSha}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: () => _showCommitDetail(commit),
              ),
          ],
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.theme, required this.message});

  final ThemeData theme;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.gitBranch,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AheadBehindChip extends StatelessWidget {
  const _AheadBehindChip({required this.ahead, required this.behind});

  final int ahead;
  final int behind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        [
          if (ahead > 0) '↑$ahead',
          if (behind > 0) '↓$behind',
        ].join(' '),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A titled bordered group card, matching the settings hub's `SettingGroup`
/// (muted letter-spaced title above a 12-radius bordered surface card), with
/// the group actions on the title row's right side.
class _ChangeGroupCard extends StatelessWidget {
  const _ChangeGroupCard({
    required this.title,
    required this.actionLabel,
    required this.actionEnabled,
    required this.onAction,
    required this.children,
    this.dangerLabel,
    this.onDanger,
  });

  final String title;
  final String actionLabel;
  final bool actionEnabled;
  final VoidCallback onAction;
  final List<Widget> children;
  final String? dangerLabel;
  final VoidCallback? onDanger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 4),
          child: Row(
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (dangerLabel != null)
                TextButton(
                  onPressed: onDanger,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(dangerLabel!),
                ),
              TextButton(
                onPressed: actionEnabled ? onAction : null,
                style:
                    TextButton.styleFrom(visualDensity: VisualDensity.compact),
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
        _GroupCard(children: children),
      ],
    );
  }
}

/// The bordered card body shared by the change groups and the history list
/// (settings `SettingGroup` card: surface fill, 12 radius, divider border,
/// clipped ink, 1px separators between rows).
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, indent: 52, color: theme.dividerColor),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    required this.entry,
    required this.busy,
    required this.onTap,
    required this.onToggle,
    this.onDiscard,
  });

  final GitChangeEntry entry;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staged = entry.area == GitChangeArea.staged;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: _StatusBadge(status: entry.status),
      title: Text(
        entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: entry.directory.isEmpty
          ? null
          : Text(
              entry.directory,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onDiscard != null)
            IconButton(
              tooltip: '丢弃改动',
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              icon: Icon(LucideIcons.undo2, color: theme.colorScheme.error),
              onPressed: busy ? null : onDiscard,
            ),
          IconButton(
            tooltip: staged ? '取消暂存' : '暂存',
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            icon: Icon(
              staged ? LucideIcons.minus : LucideIcons.plus,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: busy ? null : onToggle,
          ),
        ],
      ),
      onTap: onTap,
      onLongPress: onDiscard != null && !busy ? onDiscard : null,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final GitFileStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 与文件树行的染色 / 字母保持一致（file_tree_row.dart）。
    final color = switch (status) {
      GitFileStatus.modified => Colors.orange,
      GitFileStatus.added || GitFileStatus.untracked => Colors.green,
      GitFileStatus.renamed => Colors.blue,
      GitFileStatus.deleted || GitFileStatus.conflicted => scheme.error,
    };
    final letter = switch (status) {
      GitFileStatus.modified => 'M',
      GitFileStatus.added => 'A',
      GitFileStatus.untracked => 'U',
      GitFileStatus.deleted => 'D',
      GitFileStatus.renamed => 'R',
      GitFileStatus.conflicted => 'C',
    };
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _CommitDetailSheet extends StatelessWidget {
  const _CommitDetailSheet({
    required this.commit,
    required this.files,
    required this.onOpenFile,
    required this.onRevert,
    required this.onResetHard,
    required this.onRestoreFile,
  });

  final GitCommitInfo commit;
  final List<GitCommitFile> files;
  final ValueChanged<GitCommitFile> onOpenFile;
  final VoidCallback onRevert;
  final VoidCallback onResetHard;
  final ValueChanged<GitCommitFile> onRestoreFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
            child: Row(
              children: [
                Icon(LucideIcons.gitCommitHorizontal,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    commit.subject,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${commit.author} · ${_relativeTime(commit.time)} · '
              '${commit.shortSha} · ${files.length} 个文件',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: onRevert,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(LucideIcons.undo2, size: 15),
                  label: const Text('撤销此提交'),
                ),
                TextButton.icon(
                  onPressed: onResetHard,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(LucideIcons.history, size: 15),
                  label: const Text('回退到此提交'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Divider(height: 1, color: theme.dividerColor),
          Expanded(
            child: files.isEmpty
                ? Center(
                    child: Text(
                      '该提交没有文件改动',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: files.length,
                    itemBuilder: (context, i) {
                      final file = files[i];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: _StatusBadge(status: file.status),
                        title: Text(
                          _fileName(file.path),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        subtitle: Text(
                          file.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: () => onOpenFile(file),
                        onLongPress: () => onRestoreFile(file),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

String _fileName(String path) {
  final slash = path.lastIndexOf('/');
  return slash < 0 ? path : path.substring(slash + 1);
}

/// Coarse relative time（刚刚 / N分钟前 / N小时前 / N天前 / 日期），与记忆
/// 模块的展示口径一致。
String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
  if (diff.inDays < 1) return '${diff.inHours}小时前';
  if (diff.inDays < 30) return '${diff.inDays}天前';
  return '${time.year}-${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}';
}
