// Workspace mobile shell: three full-screen pages swiped horizontally like the
// sidebar's "push" reveal — 文件树 / 起始屏·文件查看 / 待定第三页.
//
// The middle page is the default landing page and the only one with real
// content so far: a 起始屏 (start screen) that lists the workspace backends and
// the "最近打开" history. Swipe left → 文件树 (color placeholder), swipe right →
// 第三页(占位,内容待定). 工作区是纯文件域,不内嵌智能体;智能体是独立模块,
// 仅复用底层能力层(WorkspaceBackend / MCP).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key});

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  // Land on the middle page (起始屏 / 文件查看).
  static const int _initialPage = 1;
  static const int _pageCount = 3;

  // 顶部控制行(返回 + 页码点)的高度,起始屏内容据此留出顶部内边距,避免被遮挡。
  static const double _topBarHeight = 44;

  late final PageController _controller =
      PageController(initialPage: _initialPage);

  int _page = _initialPage;

  // 左/右两页暂为纯色占位,等文件树 / 终端做了再替换。
  static const Color _treeColor = Color(0xFF1E3A5F);
  static const Color _thirdColor = Color(0xFF4A2D5F);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Edge-to-edge: 页面铺满整屏(延伸到状态栏/导航栏后面),不包 SafeArea。
    // 只给顶部控制行单独保留安全区内边距,避免被状态栏遮挡。
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _pageCount,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              switch (i) {
                case 0:
                  return const _ColorPlaceholder(
                    label: '文件树',
                    color: _treeColor,
                  );
                case 1:
                  return const _WorkspaceStartPage(topInset: _topBarHeight);
                default:
                  return const _ColorPlaceholder(
                    label: '第三页(待定)',
                    color: _thirdColor,
                  );
              }
            },
          ),
          // 顶部返回 + 页码指示，方便看清当前停在哪一页。
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: _topBarHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    _CircleButton(
                      icon: LucideIcons.arrowLeft,
                      onTap: () => context.pop(),
                    ),
                    const Spacer(),
                    _PageDots(count: _pageCount, active: _page),
                    const Spacer(),
                    const SizedBox(width: 36),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The middle page: 起始屏. Lists the three workspace backends (only 本地文件夹
/// is interactive in P0) and the "最近打开" history. Once a workspace is open
/// this page becomes the file viewer — that swap lands with the SAF backend.
class _WorkspaceStartPage extends ConsumerWidget {
  const _WorkspaceStartPage({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recent = ref.watch(workspaceStoreProvider);

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top + topInset + 8,
            16,
            24,
          ),
          children: [
            Text(
              '工作区',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '打开一个文件夹开始,或从最近打开里继续。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            const _SectionLabel(text: '打开'),
            const SizedBox(height: 8),
            _BackendCard(
              icon: LucideIcons.folderOpen,
              title: '本地文件夹',
              subtitle: '授权手机上的一个目录 (SAF)',
              onTap: () => _openLocalFolder(context),
            ),
            const SizedBox(height: 10),
            const _BackendCard(
              icon: LucideIcons.terminal,
              title: 'Termux',
              subtitle: '同机 Termux 路径,文件 + 终端',
              comingSoon: true,
            ),
            const SizedBox(height: 10),
            const _BackendCard(
              icon: LucideIcons.server,
              title: 'SSH / 远程',
              subtitle: '远程机器,文件 + 终端 (Remote-SSH)',
              comingSoon: true,
            ),
            const SizedBox(height: 24),
            const _SectionLabel(text: '最近打开'),
            const SizedBox(height: 8),
            recent.when(
              loading: () => const _RecentLoading(),
              error: (_, __) => const _RecentEmpty(),
              data: (list) => list.isEmpty
                  ? const _RecentEmpty()
                  : Column(
                      children: [
                        for (final w in list)
                          _RecentTile(
                            workspace: w,
                            onRemove: () => ref
                                .read(workspaceStoreProvider.notifier)
                                .remove(w.id),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLocalFolder(BuildContext context) {
    // 真正选目录依赖自研 SAF 原生插件 (method channel),目前为「待实现」
    // (见 docs/本地SAF工作区插件-方法规格.md)。插件接好后这里改为调
    // openSystemFilePicker → takePersistableUriPermission → workspaceStore.open。
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('本地 SAF 插件开发中,稍后可用')),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _BackendCard extends StatelessWidget {
  const _BackendCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.comingSoon = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = !comingSoon;
    final fg =
        enabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: enabled
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: enabled ? theme.colorScheme.primary : fg,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (comingSoon)
                const _Chip(text: '敬请期待')
              else
                Icon(
                  LucideIcons.chevronRight,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.workspace, required this.onRemove});

  final Workspace workspace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = workspace.displayPath ?? workspace.root;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  LucideIcons.folder,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workspace.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  color: theme.colorScheme.onSurfaceVariant,
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentEmpty extends StatelessWidget {
  const _RecentEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(
            LucideIcons.folderOpen,
            size: 28,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            '还没有打开过工作区',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentLoading extends StatelessWidget {
  const _RecentLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ColorPlaceholder extends StatelessWidget {
  const _ColorPlaceholder({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.25),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
