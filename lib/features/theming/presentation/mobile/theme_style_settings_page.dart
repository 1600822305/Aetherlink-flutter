import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/theme_mode_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/domain/app_theme_mode.dart';
import 'package:aetherlink_flutter/features/theming/application/theme_controller.dart';
import 'package:aetherlink_flutter/features/theming/application/theme_presets.dart';
import 'package:aetherlink_flutter/features/theming/domain/theme_preset.dart';
import 'package:aetherlink_flutter/features/theming/domain/theme_spec.dart';

/// 「主题风格」页（外观设置 → 主题风格）：顶部「跟随系统 / 浅色 / 深色」
/// 分段切换，下面三列迷你界面卡片——每张卡用该主题真实的色板画一个小
/// 手机界面（顶栏 + 用户 / AI 气泡 + 输入条），并跟随当前明暗模式取
/// light / dark 色板，选之前就能看到实际效果。点卡片即时换主题并持久化。
class ThemeStyleSettingsPage extends ConsumerWidget {
  const ThemeStyleSettingsPage({super.key});

  static const String _title = '主题风格';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

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
                : context.go(AppRouter.appearancePath),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text(_title),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: const [ThemeStyleSelector()],
      ),
    );
  }
}

/// 页面主体（明暗切换 + 主题网格），不带外层卡片，可嵌入其他页面。
class ThemeStyleSelector extends ConsumerWidget {
  const ThemeStyleSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeControllerProvider);
    final currentStyleId = ref.watch(themeControllerProvider).id;
    // 迷你界面按实际生效的明暗模式取色板。
    final dark = switch (mode) {
      AppThemeMode.dark => true,
      AppThemeMode.light => false,
      AppThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModeSwitch(
          value: mode,
          onChanged: ref.read(themeModeControllerProvider.notifier).use,
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '主题风格',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        _ThemeGrid(currentStyleId: currentStyleId, dark: dark),
      ],
    );
  }
}

/// 跟随系统 / 浅色 / 深色 分段切换。
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.value, required this.onChanged});

  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  static const _items = [
    (AppThemeMode.system, '跟随系统', LucideIcons.monitorSmartphone),
    (AppThemeMode.light, '浅色', LucideIcons.sun),
    (AppThemeMode.dark, '深色', LucideIcons.moon),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final (mode, label, icon) in _items)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: mode == value ? cs.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: mode == value
                        ? [
                            BoxShadow(
                              color: cs.shadow.withValues(alpha: 0.08),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: mode == value
                            ? cs.onSurface
                            : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: mode == value
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: mode == value
                              ? cs.onSurface
                              : cs.onSurfaceVariant,
                        ),
                      ),
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

/// 三列网格（宽屏自动增列，单格最小约 100px）。
class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({required this.currentStyleId, required this.dark});

  final String currentStyleId;
  final bool dark;

  static const double _gap = 9;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.maxWidth + _gap) / (100 + _gap))
            .floor()
            .clamp(3, 6);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: themePresets.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: _gap,
            crossAxisSpacing: _gap,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, i) => _ThemeTile(
            preset: themePresets[i],
            selected: themePresets[i].id == currentStyleId,
            dark: dark,
          ),
        );
      },
    );
  }
}

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile({
    required this.preset,
    required this.selected,
    required this.dark,
  });

  final ThemePreset preset;
  final bool selected;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ring = theme.colorScheme.primary;
    final colors = dark ? preset.spec.colors.dark : preset.spec.colors.light;
    return Semantics(
      button: true,
      selected: selected,
      label: preset.spec.name,
      child: GestureDetector(
        onTap: () =>
            ref.read(themeControllerProvider.notifier).useStyle(preset.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? ring : theme.dividerColor,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _MiniUi(
                      colors: colors,
                      gradientStart: Color(preset.gradientStart),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 7),
                    child: Text(
                      preset.spec.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: ring,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      LucideIcons.check,
                      size: 11,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 用主题真实色板画的迷你手机界面：顶栏 + AI 气泡 + 用户气泡 + 输入条。
class _MiniUi extends StatelessWidget {
  const _MiniUi({required this.colors, required this.gradientStart});

  final ColorRoleSet colors;
  final Color gradientStart;

  @override
  Widget build(BuildContext context) {
    final primary = Color(colors.primary);
    final bg = Color(colors.background);
    final surface = Color(colors.surface);
    final aiBubble = Color(colors.bubbleAi);
    final userBubble = Color(colors.bubbleUser);
    final muted = Color(colors.textSecondary);

    Widget pill(double widthFactor, Color color, {bool right = false}) =>
        Align(
          alignment: right ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: widthFactor,
            child: Container(
              height: 9,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        );

    return ColoredBox(
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 14,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [gradientStart, primary]),
            ),
            child: Container(
              width: 18,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  pill(0.72, aiBubble),
                  pill(0.5, userBubble, right: true),
                  pill(0.6, aiBubble),
                  Container(
                    height: 11,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: muted.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: muted.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
