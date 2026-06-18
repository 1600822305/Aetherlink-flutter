import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/theming/application/theme_controller.dart';
import 'package:aetherlink_flutter/features/theming/application/theme_presets.dart';
import 'package:aetherlink_flutter/features/theming/domain/theme_preset.dart';

/// The "主题风格" sub-page (外观设置 → this page), a port of the original
/// `src/pages/Settings/ThemeStyleSettings.tsx` + `ThemeStyleSelector.tsx`.
///
/// Renders the ten built-in presets ([themePresets]) as a responsive grid of
/// preview cards (gradient swatch + simulated UI bars, icon, name, description,
/// color dots and a "当前" chip on the active one). Tapping a card hot-swaps the
/// whole app theme via [ThemeController.useStyle] and persists the choice.
class ThemeStyleSettingsPage extends ConsumerWidget {
  const ThemeStyleSettingsPage({super.key});

  static const String _title = '主题风格';
  static const String _description = '选择您喜欢的界面设计风格，每种风格都有独特的色彩搭配和视觉效果';
  static const String _tip =
      '💡 提示：主题风格会影响整个应用的色彩搭配、按钮样式和视觉效果。您可以随时在设置中更改主题风格，更改会立即生效。';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentStyleId = ref.watch(themeControllerProvider).id;

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
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          // The original wraps the selector in a Paper (radius 3, divider border,
          // subtle shadow) with `p: { xs: 2 }` inner padding.
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.dividerColor),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000), // rgba(0,0,0,0.05)
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12.8,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ThemeGrid(currentStyleId: currentStyleId),
                  const SizedBox(height: 24),
                  // 主题特性说明 tip box.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _tip,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12.8,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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

/// Lucide icon per style id (the original `themeIcons` map).
const Map<String, IconData> _themeIcons = {
  'default': LucideIcons.palette,
  'claude': LucideIcons.sparkles,
  'nature': LucideIcons.leaf,
  'tech': LucideIcons.zap,
  'soft': LucideIcons.heart,
  'ocean': LucideIcons.waves,
  'sunset': LucideIcons.sunrise,
  'cinnamonSlate': LucideIcons.coffee,
  'horizonGreen': LucideIcons.mountain,
  'cherryCoded': LucideIcons.cherry,
};

/// The responsive card grid. Ports the original CSS
/// `grid-template-columns: repeat(auto-fill, minmax(160px, 1fr))` — the column
/// count is the most 160px-wide tiles (plus 16px gaps) that fit, and cards in a
/// row stretch to equal width.
class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({required this.currentStyleId});

  final String currentStyleId;

  static const double _minTile = 160;
  static const double _gap = 16;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(
          1,
          ((constraints.maxWidth + _gap) / (_minTile + _gap)).floor(),
        );

        final rows = <Widget>[];
        for (var start = 0; start < themePresets.length; start += columns) {
          final end = math.min(start + columns, themePresets.length);
          final rowItems = themePresets.sublist(start, end);
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) const SizedBox(width: _gap),
                  Expanded(
                    child: column < rowItems.length
                        ? _ThemeCard(
                            preset: rowItems[column],
                            isSelected: rowItems[column].id == currentStyleId,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
          if (end < themePresets.length) {
            rows.add(const SizedBox(height: _gap));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

/// A single theme preview card (the original `ThemePreviewCard`).
class _ThemeCard extends ConsumerWidget {
  const _ThemeCard({required this.preset, required this.isSelected});

  final ThemePreset preset;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // The original previews each theme in its light variant regardless of the
    // current mode (`getThemePreviewColors`).
    final light = preset.spec.colors.light;
    final previewPrimary = Color(light.primary);
    final previewSecondary = Color(light.secondary);
    final previewPaper = Color(light.surface);
    final accent = light.accent;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            ref.read(themeControllerProvider.notifier).useStyle(preset.id),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? primary : theme.dividerColor,
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PreviewSwatch(
                      gradientStart: Color(preset.gradientStart),
                      gradientEnd: Color(preset.gradientEnd),
                      primary: previewPrimary,
                      secondary: previewSecondary,
                      paper: previewPaper,
                    ),
                    const SizedBox(height: 10), // mb 1.2
                    Row(
                      children: [
                        Icon(
                          _themeIcons[preset.id] ?? LucideIcons.palette,
                          size: 20,
                          color: previewPrimary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            preset.spec.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 15.2, // 0.95rem
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6), // mb 0.8
                    // The original clamps the description to two lines and always
                    // reserves their height (`minHeight: 2.7em`).
                    SizedBox(
                      height: 12.8 * 1.35 * 2,
                      child: Text(
                        preset.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12.8, // 0.8rem
                          height: 1.35,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8), // mb 1
                    Row(
                      children: [
                        _ColorDot(color: previewPrimary),
                        const SizedBox(width: 4),
                        _ColorDot(color: previewSecondary),
                        if (accent != null) ...[
                          const SizedBox(width: 4),
                          _ColorDot(color: Color(accent)),
                        ],
                        if (isSelected) ...[
                          const Spacer(),
                          _CurrentChip(primary: primary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    LucideIcons.circleCheck,
                    size: 20,
                    color: primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The gradient swatch with the two simulated UI bars at the top of each card.
class _PreviewSwatch extends StatelessWidget {
  const _PreviewSwatch({
    required this.gradientStart,
    required this.gradientEnd,
    required this.primary,
    required this.secondary,
    required this.paper,
  });

  final Color gradientStart;
  final Color gradientEnd;
  final Color primary;
  final Color secondary;
  final Color paper;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientStart, gradientEnd],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000), // rgba(0,0,0,0.1)
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top "title bar": a dot + a faded line.
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            height: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom "toolbar": two pills.
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            height: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: paper.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 8,
                    decoration: BoxDecoration(
                      color: secondary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 20,
                    height: 8,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
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

/// A 12px color dot with a paper-colored ring (the original color preview dot).
class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000), // rgba(0,0,0,0.15)
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

/// The "当前" chip shown on the active card.
class _CurrentChip extends StatelessWidget {
  const _CurrentChip({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '当前',
        style: TextStyle(
          fontSize: 10.4, // 0.65rem
          fontWeight: FontWeight.w600,
          color: primary,
          height: 1,
        ),
      ),
    );
  }
}
