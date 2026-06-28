// Workspace mobile shell: three full-screen pages swiped horizontally like the
// sidebar's "push" reveal — 文件树 / 多文件编辑器 / 终端 (SSH/Termux PTY).
//
// Entering the workspace auto-restores the last session (workspace + open file
// tabs + active tab) like an IDE, landing on the middle editor page. Opening or
// switching workspaces now happens from the 「打开文件夹」 button in the file-tree
// header — there is no separate start screen anymore. Each page owns its own
// back affordance instead of a single floating button.
//
// 工作区是纯文件域,不内嵌智能体;智能体是独立模块,仅复用底层能力层
// (WorkspaceBackend / MCP).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/workspace_file_tree.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/workspace_file_viewer.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/workspace_terminal_page.dart';

class WorkspacePage extends ConsumerStatefulWidget {
  const WorkspacePage({super.key});

  @override
  ConsumerState<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends ConsumerState<WorkspacePage> {
  // Land on the middle page (多文件编辑器).
  static const int _initialPage = 1;
  static const int _pageCount = 3;

  // 各页头部行内边距据此留出顶部安全区,避免被状态栏遮挡。
  static const double _topBarHeight = 0;

  late final PageController _controller = PageController(
    initialPage: _initialPage,
  );

  int _page = _initialPage;
  bool _restoreAttempted = false;

  // 中间页返回容易误触,改成「点两次才退出」:第一次只弹提示并在此窗口内武装,
  // 窗口内再点一次才真正退出工作区。侧页返回(回到中间页)不受影响。
  DateTime? _exitArmedAt;
  static const Duration _exitConfirmWindow = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoRestore());
  }

  // 进工作区自动恢复上次会话(工作区 + 所有打开的文件 tab + 活动 tab),最像 IDE。
  // SAF 的 content:// 授权可能被系统回收,恢复前先探一下根目录可读;失效则提示
  // 并停在空文件树,不卡死。
  Future<void> _autoRestore() async {
    if (_restoreAttempted) return;
    _restoreAttempted = true;

    final settings = ref.read(appSettingsStoreProvider);
    // 用户可在「工作区管理」里关掉自动恢复;关掉后停在空文件树,由用户手动打开。
    if (await settings.getSetting(kWorkspaceAutoRestoreKey) == 'false') return;

    final raw = await settings.getSetting(kWorkspaceSessionKey);
    final session = WorkspaceSession.decode(raw);
    if (session == null) return;

    final recent = await ref.read(workspaceStoreProvider.future);
    Workspace? workspace;
    for (final w in recent) {
      if (w.id == session.workspaceId) {
        workspace = w;
        break;
      }
    }
    if (workspace == null) return;

    try {
      final backend = ref.read(workspaceBackendProvider(workspace));
      await backend.listDir(workspace.root);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('上次授权已失效,请重新打开文件夹')));
      }
      return;
    }

    ref.read(currentWorkspaceProvider.notifier).open(workspace);
    if (session.tabs.isNotEmpty) {
      ref
          .read(openWorkspaceFilesProvider.notifier)
          .restore(session.tabs, session.activePath);
    }
  }

  void _goToMiddle() {
    if (!_controller.hasClients) return;
    _controller.animateToPage(
      _initialPage,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  // 在侧页(文件树 / 第三页)按返回时,先回到中间页;已在中间页才真正退出工作区,
  // 且需在 [_exitConfirmWindow] 内点两次(第一次仅提示),避免误触退出。
  void _onBack() {
    if (_page != _initialPage) {
      _goToMiddle();
      return;
    }
    final now = DateTime.now();
    final armed = _exitArmedAt;
    if (armed != null && now.difference(armed) < _exitConfirmWindow) {
      _exitArmedAt = null;
      context.pop();
      return;
    }
    _exitArmedAt = now;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('再点一次返回退出工作区'),
          duration: _exitConfirmWindow,
        ),
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 在文件树点开文件(活动 tab 变化)后,把 PageView 滑到中间页让编辑器可见。
    ref.listen<WorkspaceTabsState>(openWorkspaceFilesProvider, (prev, next) {
      if (next.activePath != null &&
          next.activePath != prev?.activePath &&
          _controller.hasClients &&
          _page != _initialPage) {
        _goToMiddle();
      }
    });

    // 页面锁开启时禁用横向翻页,避免编辑器内捏合缩放/拖动误触翻页。
    final locked = ref.watch(workspacePageLockProvider);

    // Edge-to-edge: 页面铺满整屏(延伸到状态栏/导航栏后面)。每页头部行各自留安全区。
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: PageView.builder(
          controller: _controller,
          itemCount: _pageCount,
          physics: locked
              ? const NeverScrollableScrollPhysics()
              : null,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) {
            switch (i) {
              case 0:
                return WorkspaceFileTree(
                  topInset: _topBarHeight,
                  onBack: _onBack,
                );
              case 1:
                return _WorkspaceMiddlePage(
                  topInset: _topBarHeight,
                  onBack: _onBack,
                );
              default:
                return WorkspaceTerminalPage(
                  topInset: _topBarHeight,
                  onBack: _onBack,
                );
            }
          },
        ),
      ),
    );
  }
}

/// The middle page: an IDE-style multi-file editor once tabs are open, or an
/// empty placeholder pointing at the file tree when nothing is open.
class _WorkspaceMiddlePage extends ConsumerWidget {
  const _WorkspaceMiddlePage({required this.topInset, required this.onBack});

  final double topInset;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(openWorkspaceFilesProvider);
    if (tabs.isEmpty) {
      return _EmptyEditor(topInset: topInset, onBack: onBack);
    }
    return WorkspaceFileViewer(tabs: tabs, onBack: onBack, topInset: topInset);
  }
}

/// Shown on the middle page when no file is open.
class _EmptyEditor extends StatelessWidget {
  const _EmptyEditor({required this.topInset, required this.onBack});

  final double topInset;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPad = MediaQuery.paddingOf(context).top + topInset + 4;
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(top: topPad, left: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '返回',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(LucideIcons.arrowLeft, size: 20),
                    onPressed: onBack,
                  ),
                  Text(
                    '编辑器',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.fileText,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '还没有打开文件',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '左滑到文件树,点一个文件即可在这里打开',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


