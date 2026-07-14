// 智能体侧边栏壳：参考普通聊天侧边栏架构——「智能体 / 话题」分段 tab +
// InstantSwitchTabView（常驻不重建）+ 底部「回聊天」入口行。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/app_main_mode.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/sidebar/tabs/agent_profile_tab.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/sidebar/tabs/agent_settings_tab.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/sidebar/tabs/agent_topic_tab.dart';
import 'package:aetherlink_flutter/shared/widgets/instant_switch_tab_view.dart';

const String _profileTabLabel = '智能体';
const String _topicTabLabel = '话题';
const String _settingsTabLabel = '设置';

class AgentSidebar extends ConsumerStatefulWidget {
  const AgentSidebar({super.key});

  @override
  ConsumerState<AgentSidebar> createState() => _AgentSidebarState();
}

class _AgentSidebarState extends ConsumerState<AgentSidebar>
    with SingleTickerProviderStateMixin {
  // 与聊天侧边栏同款的 tab 记忆（AgentSidebarTabIndex，持久化）：
  // 重开抽屉、重启 app 都保持上次 tab。
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
    initialIndex: ref.read(agentSidebarTabIndexProvider).clamp(0, 2),
  )..addListener(_onTabChanged);

  void _onTabChanged() {
    final index = _tabController.index;
    if (ref.read(agentSidebarTabIndexProvider) != index) {
      ref.read(agentSidebarTabIndexProvider.notifier).set(index);
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 持久化的 tab 索引是异步 hydrate 的：冷启动后第一次开抽屉时存储值可能
    // 晚于控制器创建才到，监听到后补一次跳转。
    ref.listen(agentSidebarTabIndexProvider, (_, next) {
      if (next != _tabController.index && next < _tabController.length) {
        _tabController.animateTo(next);
      }
    });

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      // 与聊天侧边栏同款：`border-radius: 0 16px 16px 0`。
      shape: const RoundedRectangleBorder(
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
              child: InstantSwitchTabView(
                controller: _tabController,
                enableSwipe: false,
                children: [
                  AgentProfileTab(
                    onGoToTopics: () => _tabController.animateTo(1),
                  ),
                  const AgentTopicTab(),
                  const AgentSettingsTab(),
                ],
              ),
            ),
            const _BottomActionRow(),
          ],
        ),
      ),
    );
  }
}

/// 顶部关闭行：与聊天侧边栏同款（右对齐 X、min-height 48）。
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
        onPressed: () => Navigator.of(context).pop(),
        iconSize: 20,
        color: theme.colorScheme.onSurface,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        icon: const Icon(LucideIcons.x),
      ),
    );
  }
}

/// 分段式 tab 条：与聊天侧边栏同款（浅底胶囊 + 白底浮起指示器）。
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
          _SidebarTab(icon: LucideIcons.bot, label: _profileTabLabel),
          _SidebarTab(icon: LucideIcons.messagesSquare, label: _topicTabLabel),
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

/// 底部入口行：回聊天（与聊天侧边栏底部行同款按钮样式）。
class _BottomActionRow extends ConsumerWidget {
  const _BottomActionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                ref
                    .read(appMainModeControllerProvider.notifier)
                    .use(AppMainMode.chat);
                context.go(AppRouter.chatPath);
              },
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  LucideIcons.messageCircle,
                  size: 22,
                  color: textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
