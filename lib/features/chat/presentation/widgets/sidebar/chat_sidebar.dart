// Chat sidebar shell: the 助 / 话 / 设 tab scaffold plus the bottom 翻 button.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/tabs/assistant_tab.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/tabs/settings_tab.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/tabs/topic_tab.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar_host.dart';

const String _assistantTabLabel = '助手';
const String _topicTabLabel = '话题';
const String _settingsTabLabel = '设置';

class ChatSidebar extends ConsumerStatefulWidget {
  const ChatSidebar({super.key});

  @override
  ConsumerState<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends ConsumerState<ChatSidebar>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Open on the session's last tab (in-memory [SidebarTabIndex]); it is not
    // persisted, so a fresh app launch starts on the default 助手 tab.
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: ref.read(sidebarTabIndexProvider),
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // Remember the active tab for this session so reopening the drawer keeps it
    // (in-memory only — a restart resets to the default tab).
    final index = _tabController.index;
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showTranslate = _tabController.index != 2;
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
            _SidebarTabBar(controller: _tabController),
            Expanded(
              // IndexedStack keeps all three tabs alive permanently so
              // switching tabs never triggers an async reload — the "共 N 个"
              // footer and all list content render instantly.
              // Swipe between tabs is already disabled, so TabBarView's page
              // animation is unnecessary.
              child: IndexedStack(
                index: _tabController.index,
                children: [
                  AssistantTab(onGoToTopics: () => _tabController.animateTo(1)),
                  const TopicTab(),
                  const SettingsTab(),
                ],
              ),
            ),
            Visibility(
              visible: showTranslate,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: const _TranslateButton(),
            ),
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
  const _SidebarTabBar({required this.controller});

  final TabController controller;

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
        tabs: const [
          _SidebarTab(icon: LucideIcons.sparkles, label: _assistantTabLabel),
          _SidebarTab(
              icon: LucideIcons.messagesSquare, label: _topicTabLabel),
          _SidebarTab(icon: LucideIcons.sliders, label: _settingsTabLabel),
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
      height: 32,
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

class _TranslateButton extends StatelessWidget {
  const _TranslateButton();

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => context.push(AppRouter.translatePath),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(LucideIcons.languages, size: 22, color: textPrimary),
          ),
        ),
      ),
    );
  }
}
