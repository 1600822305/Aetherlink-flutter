// Chat sidebar shell: the 助 / 话 / 设 tab scaffold plus the bottom 翻 button.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/app_main_mode.dart';
import 'package:aetherlink_flutter/app/di/notes_sidebar_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/tabs/assistant_tab.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/tabs/settings_tab.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/tabs/topic_tab.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar_host.dart';
import 'package:aetherlink_flutter/shared/widgets/instant_switch_tab_view.dart';

const String _assistantTabLabel = '助手';
const String _topicTabLabel = '话题';
const String _notesTabLabel = '笔记';
const String _settingsTabLabel = '设置';

class ChatSidebar extends ConsumerStatefulWidget {
  const ChatSidebar({super.key});

  @override
  ConsumerState<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends ConsumerState<ChatSidebar>
    with TickerProviderStateMixin {
  TabController? _tabController;

  /// (Re)creates the tab controller when the tab count changes (the 笔记 Tab is
  /// added/removed by the [SidebarSettings.showNotesSidebarTab] toggle). The
  /// previous index is preserved (clamped) so toggling keeps the active tab.
  void _syncController(int length) {
    final existing = _tabController;
    if (existing != null && existing.length == length) return;
    // Open on the last tab ([SidebarTabIndex], persisted — survives an app
    // restart).
    final int prevIndex = existing?.index ?? ref.read(sidebarTabIndexProvider);
    existing?.removeListener(_onTabChanged);
    existing?.dispose();
    _tabController = TabController(
      length: length,
      vsync: this,
      initialIndex: prevIndex.clamp(0, length - 1),
    )..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // Remember the active tab (persisted) so reopening the drawer — and
    // relaunching the app — keeps it.
    final index = _tabController!.index;
    if (ref.read(sidebarTabIndexProvider) != index) {
      ref.read(sidebarTabIndexProvider.notifier).set(index);
    }
    // Rebuild immediately (no indexIsChanging guard) so the translate button
    // visibility updates the instant the user taps a tab, not after the
    // animation finishes — prevents a visible layout delay.
    setState(() {});
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showNotes = ref.watch(
      sidebarSettingsControllerProvider.select((s) => s.showNotesSidebarTab),
    );
    final tabCount = showNotes ? 4 : 3;
    _syncController(tabCount);
    final tabController = _tabController!;
    // 持久化的 tab 索引是异步 hydrate 的：冷启动后第一次开抽屉时存储值可能
    // 晚于控制器创建才到，监听到后补一次跳转。
    ref.listen(sidebarTabIndexProvider, (_, next) {
      if (next != tabController.index && next < tabController.length) {
        tabController.animateTo(next);
      }
    });
    final settingsIndex = tabCount - 1;
    final showTranslate = tabController.index != settingsIndex;
    // 设置 tab 的「侧边栏宽度」对话框驱动这里；按当前屏宽 clamp 到安全范围
    // (`getSafeMaxSidebarWidth`)，对话框拖动时实时预览。
    final rawWidth = ref.watch(
      sidebarSettingsControllerProvider.select((s) => s.sidebarWidth),
    );
    final maxWidth = safeMaxSidebarWidth(MediaQuery.sizeOf(context).width);
    final drawerWidth = rawWidth.clamp(kSidebarWidthMin, maxWidth);
    // 推开模式下聊天页紧贴抽屉右边缘，圆角会露出深色遮罩（黑缺口），故改直角；
    // 覆盖模式保留原版 `0 16px 16px 0` 圆角。
    final pushed = ref.watch(
      sidebarSettingsControllerProvider.select(
        (s) => s.sidebarDisplayMode == SidebarDisplayMode.push,
      ),
    );

    return Drawer(
      width: drawerWidth,
      backgroundColor: theme.colorScheme.surface,
      // Original mobile drawer: `border-radius: 0 16px 16px 0` (覆盖模式)。
      shape: pushed
          ? const RoundedRectangleBorder()
          : const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const _CloseRow(),
            _SidebarTabBar(controller: tabController, showNotes: showNotes),
            Expanded(
              // Uses the shared [InstantSwitchTabView] (IndexedStack under the
              // hood) so every tab is built once and stays alive — switching
              // never triggers a reload, and the "共 N 个" footer + list
              // content render instantly. Swipe is disabled because the
              // drawer-close gesture already owns horizontal drags here.
              child: InstantSwitchTabView(
                controller: tabController,
                enableSwipe: false,
                children: [
                  AssistantTab(onGoToTopics: () => tabController.animateTo(1)),
                  const TopicTab(),
                  if (showNotes) ref.watch(notesSidebarPanelProvider),
                  const SettingsTab(),
                ],
              ),
            ),
            if (showTranslate) const _BottomActionRow(),
          ],
        ),
      ),
    );
  }
}

/// The drawer's top close affordance: `justify-content: flex-end; padding: 8px;
/// min-height: 48px` with a lucide `X` (size 20) button.
class _CloseRow extends StatelessWidget {
  const _CloseRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      alignment: Alignment.centerRight,
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.all(8),
      child: IconButton(
        onPressed: () => SidebarScope.maybeOf(context)?.closeSidebar(),
        iconSize: 20,
        color: theme.colorScheme.onSurface,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        icon: const Icon(LucideIcons.x),
      ),
    );
  }
}

class _SidebarTabBar extends StatelessWidget {
  const _SidebarTabBar({required this.controller, this.showNotes = false});

  final TabController controller;
  final bool showNotes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        labelColor: cs.onSurface,
        unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.08),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        labelPadding: EdgeInsets.zero,
        tabs: [
          const _SidebarTab(
              icon: LucideIcons.sparkles, label: _assistantTabLabel),
          const _SidebarTab(
              icon: LucideIcons.messagesSquare, label: _topicTabLabel),
          if (showNotes)
            const _SidebarTab(
                icon: LucideIcons.fileText, label: _notesTabLabel),
          const _SidebarTab(icon: LucideIcons.sliders, label: _settingsTabLabel),
        ],
      ),
    );
  }
}

class _SidebarTab extends StatelessWidget {
  const _SidebarTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }
}

/// Bottom action row: 工作区 + 翻译 + 宠物 + 智能体 入口，并排居中。整行随
/// [showTranslate] 一起在设置 tab 时隐藏。
class _BottomActionRow extends StatelessWidget {
  const _BottomActionRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BottomIconButton(
            icon: LucideIcons.folderTree,
            destination: AppRouter.workspacePath,
          ),
          SizedBox(width: 8),
          _BottomIconButton(
            icon: LucideIcons.languages,
            destination: AppRouter.translatePath,
          ),
          SizedBox(width: 8),
          _BottomIconButton(
            icon: LucideIcons.pawPrint,
            destination: AppRouter.buddyPath,
          ),
          SizedBox(width: 8),
          _AgentModeButton(),
        ],
      ),
    );
  }
}

/// 智能体模式入口：切换主界面模式并持久化（冷启动回到退出前的模式），
/// 用 go 而非 push：两个主界面是同级平行关系，不压栈。
class _AgentModeButton extends ConsumerWidget {
  const _AgentModeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          ref
              .read(appMainModeControllerProvider.notifier)
              .use(AppMainMode.agent);
          context.go(AppRouter.agentPath);
        },
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(LucideIcons.bot, size: 22, color: textPrimary),
        ),
      ),
    );
  }
}

class _BottomIconButton extends StatelessWidget {
  const _BottomIconButton({required this.icon, required this.destination});

  final IconData icon;
  final String destination;

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.push(destination),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: textPrimary),
        ),
      ),
    );
  }
}
