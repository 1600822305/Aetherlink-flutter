import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/application/behavior_settings_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/behavior_settings.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';

/// The 行为设置 page (基本设置 → 行为), a port of the original
/// `src/pages/Settings/BehaviorSettings.tsx`.
///
/// Two cards — 交互行为 and 触觉反馈 — matching the original, but recomposed into
/// the project's compact settings style (no 40px avatars / p:2 whitespace; a
/// small tinted glyph + tight rows instead). All toggles persist to the Drift
/// KV store via [BehaviorSettingsController].
///
/// What actually takes effect: Enter 发送 / 移动端输入法换行 drive the chat composer
/// (see `chat_input_bar` / `input_box_composer`), and 触觉反馈 (master + the four
/// sub-toggles) gates real haptics at their interaction points via the global
/// [Haptics] service. 通知 is UI + persistence only — Flutter has no notification
/// subsystem yet — so it carries an 「即将支持」 tag.
class BehaviorSettingsPage extends ConsumerWidget {
  const BehaviorSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final config = ref.watch(behaviorSettingsControllerProvider);
    final controller = ref.read(behaviorSettingsControllerProvider.notifier);
    final haptic = config.hapticFeedback;

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
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            color: theme.colorScheme.primary,
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRouter.settingsPath),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text('行为设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _interactionCard(theme, config, controller),
          const SizedBox(height: 16),
          _hapticCard(theme, haptic, config.hapticFeedback.enabled, controller),
        ],
      ),
    );
  }

  Widget _interactionCard(
    ThemeData theme,
    BehaviorSettings config,
    BehaviorSettingsController controller,
  ) {
    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(title: '交互行为', description: '自定义应用的交互方式和通知设置'),
          Divider(height: 1, color: theme.dividerColor),
          _PrimaryRow(
            icon: LucideIcons.send,
            accent: const Color(0xFF06B6D4),
            label: '使用Enter键发送消息',
            description: '按Enter键快速发送消息，使用Shift+Enter添加换行',
            value: config.sendWithEnter,
            onChanged: controller.setSendWithEnter,
          ),
          Divider(height: 1, color: theme.dividerColor),
          _PrimaryRow(
            icon: LucideIcons.bell,
            accent: const Color(0xFF8B5CF6),
            label: '启用通知',
            description: '当AI助手回复完成时，显示系统通知',
            value: config.enableNotifications,
            onChanged: controller.setEnableNotifications,
            comingSoon: true,
          ),
          Divider(height: 1, color: theme.dividerColor),
          _PrimaryRow(
            icon: LucideIcons.smartphone,
            accent: const Color(0xFFF59E0B),
            label: '移动端输入法换行模式',
            description: '开启后，移动端输入法的发送按钮将变为换行功能，需要点击输入框的发送按钮来发送消息',
            value: config.mobileInputMethodEnterAsNewline,
            onChanged: controller.setMobileInputMethodEnterAsNewline,
          ),
        ],
      ),
    );
  }

  Widget _hapticCard(
    ThemeData theme,
    HapticFeedbackSettings haptic,
    bool enabled,
    BehaviorSettingsController controller,
  ) {
    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            title: '触觉反馈',
            description: '自定义应用的触觉反馈设置',
            trailing: _StatusPill(enabled: enabled),
          ),
          Divider(height: 1, color: theme.dividerColor),
          _PrimaryRow(
            icon: LucideIcons.vibrate,
            accent: const Color(0xFFEC4899),
            label: '启用触觉反馈',
            description: '开启后，应用交互将提供触觉反馈',
            value: enabled,
            // The behavior page configures haptics, so its own switches don't
            // self-buzz; instead the master mirrors the original's "buzz on
            // enable" confirmation (`Haptics.medium()`).
            disableHaptics: true,
            onChanged: (v) {
              controller.setHapticEnabled(v);
              if (v) Haptics.instance.medium();
            },
          ),
          if (enabled) ...[
            Divider(height: 1, color: theme.dividerColor),
            _SubSection(
              theme: theme,
              children: [
                _SubRow(
                  label: '侧边栏触觉反馈',
                  description: '打开/关闭侧边栏时启用触觉反馈',
                  value: haptic.enableOnSidebar,
                  onTest: Haptics.instance.drawerPulse,
                  onChanged: (v) {
                    controller.setHapticOnSidebar(v);
                    if (v) Haptics.instance.drawerPulse();
                  },
                ),
                _SubRow(
                  label: '开关触觉反馈',
                  description: '切换开关时启用触觉反馈',
                  value: haptic.enableOnSwitch,
                  onTest: Haptics.instance.soft,
                  onChanged: controller.setHapticOnSwitch,
                ),
                _SubRow(
                  label: '列表项触觉反馈',
                  description: '点击列表项时启用触觉反馈',
                  value: haptic.enableOnListItem,
                  onTest: Haptics.instance.light,
                  onChanged: controller.setHapticOnListItem,
                ),
                _SubRow(
                  label: '导航触觉反馈',
                  description: '使用上下导航按钮时启用触觉反馈',
                  value: haptic.enableOnNavigation,
                  onTest: Haptics.instance.light,
                  onChanged: controller.setHapticOnNavigation,
                ),
              ],
            ),
          ] else ...[
            Divider(height: 1, color: theme.dividerColor),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
              child: Center(
                child: Text(
                  '启用触觉反馈以配置更多选项',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A rounded, bordered surface card with the project's soft shadow (mirrors the
/// original `Paper` panels / the agent-prompts page card).
class _OutlinedCard extends StatelessWidget {
  const _OutlinedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // rgba(0,0,0,0.05)
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A card section header: a faint `rgba(0,0,0,0.015)` strip with a title, a
/// description and an optional trailing widget (the 触觉反馈 status pill).
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.title,
    required this.description,
    this.trailing,
  });

  final String title;
  final String description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: theme.colorScheme.onSurface.withValues(alpha: 0.015),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 3),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A primary toggle row: a small tinted glyph, a label (+ optional 「即将支持」
/// tag) and description on the left, a [CustomSwitch] on the right. Compact —
/// a 30px glyph instead of the original's 40px avatar.
class _PrimaryRow extends StatelessWidget {
  const _PrimaryRow({
    required this.icon,
    required this.accent,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
    this.comingSoon = false,
    this.disableHaptics = false,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool comingSoon;
  final bool disableHaptics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (comingSoon) ...[
                      const SizedBox(width: 6),
                      const _ComingSoonTag(),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    height: 1.3,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CustomSwitch(
            value: value,
            onChanged: onChanged,
            disableHaptics: disableHaptics,
          ),
        ],
      ),
    );
  }
}

/// The primary-tinted, left-accented container holding the 细分设置 sub-toggles
/// (the original's `borderLeft: 3 / primary` block).
class _SubSection extends StatelessWidget {
  const _SubSection({required this.theme, required this.children});

  final ThemeData theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final accent = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, indent: 14, color: theme.dividerColor));
      }
      rows.add(children[i]);
    }

    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.05 : 0.02),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              '细分设置',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: accent,
              ),
            ),
          ),
          ...rows,
        ],
      ),
    );
  }
}

/// A 细分设置 sub-toggle row: label + description on the left, a 测试 button and a
/// [CustomSwitch] on the right. The test button fires its haptic primitive
/// directly and is enabled only while the sub-toggle is on (matching the
/// original's `disabled={!enableOnX}`).
class _SubRow extends StatelessWidget {
  const _SubRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onTest,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final VoidCallback onTest;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _TestButton(enabled: value, onPressed: onTest),
          const SizedBox(width: 10),
          // Configuring haptics shouldn't self-buzz; the master's "buzz on
          // enable" + the per-row 测试 button cover the feedback.
          CustomSwitch(
            value: value,
            onChanged: onChanged,
            disableHaptics: true,
          ),
        ],
      ),
    );
  }
}

/// The small outlined 测试 button (lucide `testTube2`), disabled until its
/// sub-toggle is on.
class _TestButton extends StatelessWidget {
  const _TestButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4);
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Icon(LucideIcons.testTube2, size: 14, color: color),
      ),
    );
  }
}

/// The 启用 / 禁用 status pill in the 触觉反馈 header (the original's `Chip`).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final color = enabled ? accent : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        enabled ? '已启用' : '已禁用',
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// The 「即将支持」 tag shown next to the 通知 row (UI + persistence only — there
/// is no notification subsystem yet).
class _ComingSoonTag extends StatelessWidget {
  const _ComingSoonTag();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        '即将支持',
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 10.5,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
