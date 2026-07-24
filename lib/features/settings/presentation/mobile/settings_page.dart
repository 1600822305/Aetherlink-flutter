import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/settings/agent_app_settings_body.dart';
import 'package:aetherlink_flutter/features/settings/application/settings_view_mode_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/settings_catalog.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/setting_group.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/setting_item.dart';

/// The settings hub — the top-level grouped list of settings entries, a 1:1
/// reproduction of the original `src/pages/Settings/index.tsx`.
///
/// It is a pure view: the compact/detailed mode comes from
/// [settingsViewModeControllerProvider] in the application layer; the grouped
/// rows come from the static [kSettingsGroups] navigation catalog. It holds no
/// business logic and never touches `data`.
///
/// This milestone builds only the hub. Every row except "关于我们" is a
/// not-yet-implemented placeholder (rendered disabled); their sub-pages are
/// later milestones. "关于我们" pushes the existing [AboutPage] to prove the hub
/// navigates. Header shows the original's back button + 设置 title +
/// compact/detailed toggle. All colors are theme tokens (ADR-0008); icons are
/// lucide (ADR-0009).
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({this.initialAgentMode = false, super.key});

  /// 为 true 时打开即落在「智能体设置」视图（智能体侧入口直达）。
  final bool initialAgentMode;

  static const double _groupSpacing = 24;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  /// 顶栏切换：聊天（通用）设置 ↔ 智能体设置。两侧正文完全独立，
  /// 智能体侧正文由 agent 模块提供（[AgentAppSettingsBody]）。
  late bool _agentMode = widget.initialAgentMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = ref.watch(settingsViewModeControllerProvider);

    return Scaffold(
      // The original HeaderBar is light and flat: `background.paper` fill,
      // elevation 0, a 1px bottom divider and a left-aligned title — matching
      // the restored chat top bar rather than a default Material 2 AppBar.
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          color: theme.colorScheme.primary,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRouter.chatPath),
        ),
        // Match the original HeaderBar title: 1.125rem (18px) at weight 600,
        // left-aligned tight against the back button (SettingComponents.tsx).
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: Text(_agentMode ? '智能体设置' : kSettingsTitle),
        actions: [
          IconButton(
            icon: Icon(
              _agentMode ? LucideIcons.messageSquare : LucideIcons.bot,
            ),
            color: theme.colorScheme.onSurfaceVariant,
            tooltip: _agentMode ? '切到聊天设置' : '切到智能体设置',
            onPressed: () => setState(() => _agentMode = !_agentMode),
          ),
          if (!_agentMode) ...[
            IconButton(
              icon: const Icon(LucideIcons.search),
              color: theme.colorScheme.onSurfaceVariant,
              tooltip: '搜索设置',
              onPressed: () => context.push(AppRouter.settingsSearchPath),
            ),
            IconButton(
              icon: Icon(isCompact ? LucideIcons.list : LucideIcons.layoutGrid),
              color: theme.colorScheme.onSurfaceVariant,
              tooltip: isCompact
                  ? kSettingsDetailedModeLabel
                  : kSettingsCompactModeLabel,
              onPressed: () => ref
                  .read(settingsViewModeControllerProvider.notifier)
                  .toggle(),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      // 懒构建 + 每组一个 RepaintBoundary：首帧只 build 视口内的分组，
      // 滚动时静态卡片不随帧重绘。
      body: _agentMode
          ? const AgentAppSettingsBody()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: kSettingsGroups.length,
              itemBuilder: (context, index) {
                final group = kSettingsGroups[index];
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: SettingsPage._groupSpacing,
                  ),
                  child: RepaintBoundary(
                    child: SettingGroup(
                      title: group.title,
                      children: [
                        for (final item in group.items)
                          SettingItem(
                            icon: item.icon,
                            title: item.title,
                            description: isCompact ? null : item.description,
                            enabled: item.enabled,
                            onTap: item.route == null
                                ? null
                                : () => context.push(item.route!),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
