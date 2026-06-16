import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/application/font_size_controller.dart';
import 'package:aetherlink_flutter/features/settings/application/theme_mode_controller.dart';
import 'package:aetherlink_flutter/features/settings/domain/app_theme_mode.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// The "外观设置" second-level page (hub "外观" → this page), a 1:1 reproduction
/// of the layout of the original `src/pages/Settings/AppearanceSettings.tsx`.
///
/// The page mirrors the original's exact metrics (font sizes, card radius,
/// paddings, spacing, colors). The 主题 dropdown is fully wired — it drives the
/// app's [ThemeModeController], so picking 浅色/深色/跟随系统 switches
/// `MaterialApp.themeMode` live. Per the milestone scope, the third-level
/// destinations are not built yet, so the "界面定制" rows render greyed and carry
/// no navigation (置灰). The 全局字体大小 slider is also wired — it drives the
/// app's [FontSizeController], so dragging it rescales every text style live
/// (matching the original theme's `fontScale = fontSize / 16`). The remaining
/// controls (语言 / 全局字体 / 添加本地字体 / 开发者工具 switches / import + share)
/// render at full visual fidelity but are non-interactive, since their backing
/// features (i18n / custom-font infra / a perf monitor / appearance-config
/// import-export) don't exist on Flutter yet.
///
/// To match the original pixel-for-pixel, the per-action avatar brand hues and
/// the slider's `#9333EA → #754AB4` gradient are taken verbatim from the
/// original CSS (the only literal colors on the page; everything else is a
/// theme token).
class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  static const String _title = '外观设置';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(themeModeControllerProvider);
    final fontSize = ref.watch(fontSizeControllerProvider);

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
        // Original back IconButton: a 40x40 hit target sitting 4px from the
        // edge (16px gutter − the 12px `edge="start"` overhang), so its 24px
        // glyph lands 16px in and the title butts up at x=44.
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
        // Original HeaderBar title: the themed h6 (1.125rem = 18px) at weight
        // 600, left-aligned tight against the back button.
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text(_title),
        actions: [
          // 导入 / 分享: primary-colored 20px lucide glyphs. Rendered at full
          // fidelity but non-interactive — appearance-config import/export needs
          // a settings store that doesn't exist on Flutter yet.
          Icon(LucideIcons.upload, size: 20, color: theme.colorScheme.primary),
          const SizedBox(
            width: 8 + 12,
          ), // original `mr: 1` + icon-button gutter
          Icon(LucideIcons.share2, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 16), // toolbar right gutter (mobile breakpoint)
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          // The original `paddingBottom: var(--content-bottom-padding)` plus the
          // device safe-area inset, so the last card clears the home indicator.
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _ThemeAndFontCard(
            mode: mode,
            onModeChanged: (next) =>
                ref.read(themeModeControllerProvider.notifier).use(next),
            fontSize: fontSize,
            onFontSizeChanged: (next) =>
                ref.read(fontSizeControllerProvider.notifier).use(next),
          ),
          const SizedBox(height: 16), // original card `mb: 2`
          const _CustomizationCard(),
          const SizedBox(height: 16),
          const _DeveloperToolsCard(),
        ],
      ),
    );
  }
}

/// The original inline `Paper`: `borderRadius: 2` (= 16px), a 1px
/// divider-colored border and a soft `0 4px 12px rgba(0,0,0,0.05)` shadow,
/// clipped so children (header tints, dividers, list rows) honor the rounded
/// corners. Shared by all three cards on this page.
class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({required this.child});

  final Widget child;

  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // rgba(0,0,0,0.05)
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [child],
          ),
        ),
      ),
    );
  }
}

/// A card's tinted header (`Box p:2 bgcolor rgba(0,0,0,0.01)`): a subtitle1
/// title over a body2 description.
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, required this.description});

  final String title;
  final String description;

  // The original header `bgcolor: 'rgba(0,0,0,0.01)'`.
  static const Color _headerTint = Color(0x03000000);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: _headerTint,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              // subtitle1: not overridden in the theme, so it keeps MUI's
              // default scaled by the `typography.fontSize:16` coef (16/14) →
              // 18.29px, line-height 1.75.
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 128 / 7,
                height: 1.75,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "主题和字体" card: theme + language selects, the global font-size slider
/// and the font-family field. Only the theme select is wired this milestone.
class _ThemeAndFontCard extends StatelessWidget {
  const _ThemeAndFontCard({
    required this.mode,
    required this.onModeChanged,
    required this.fontSize,
    required this.onFontSizeChanged,
  });

  final AppThemeMode mode;
  final ValueChanged<AppThemeMode> onModeChanged;
  final int fontSize;
  final ValueChanged<int> onFontSizeChanged;

  static const String _title = '主题和字体';
  static const String _description = '自定义应用的外观主题和全局字体大小设置';
  static const String _themeLabel = '主题';
  static const String _themeHelper = '选择应用的外观主题，跟随系统将自动适配设备的深色/浅色模式';
  static const String _languageLabel = '语言';
  static const String _languageHelper = '选择应用的显示语言，更改后界面将立即更新';
  static const String _fontSizeLabel = '全局字体大小';
  static const String _fontSizeHelper = '调整应用中所有文本的基础字体大小，影响聊天消息、界面文字等全局显示效果';
  static const String _fontFamilyLabel = '全局字体';
  static const String _fontFamilyValue = '系统默认';
  static const String _fontFamilyHelper = '选择应用的全局字体，将影响所有界面文字的显示效果';
  static const String _addLocalFont = '添加本地字体';

  // The original theme `MenuItem` labels (`settings.{light,dark,system}`).
  static const List<(AppThemeMode, String)> _themeOptions = [
    (AppThemeMode.light, '浅色'),
    (AppThemeMode.dark, '深色'),
    (AppThemeMode.system, '跟随系统'),
  ];

  @override
  Widget build(BuildContext context) {
    return _AppearanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _CardHeader(title: _title, description: _description),
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 主题选择 — the one wired control: drives MaterialApp.themeMode.
                _ThemeSelect(
                  label: _themeLabel,
                  helper: _themeHelper,
                  value: mode,
                  options: _themeOptions,
                  onChanged: onModeChanged,
                ),
                const SizedBox(height: 24), // original `mb: 3`
                // 语言选择 — static display (Flutter has no i18n yet).
                const _LanguageSelect(
                  label: _languageLabel,
                  helper: _languageHelper,
                ),
                const SizedBox(height: 24),
                // 全局字体大小 — wired: drives the app-wide text scale.
                _FontSizeSection(
                  label: _fontSizeLabel,
                  helper: _fontSizeHelper,
                  value: fontSize,
                  onChanged: onFontSizeChanged,
                ),
                const SizedBox(height: 16), // original `mb: 2`
                // 全局字体 + 添加本地字体 — static (font selector sub-page /
                // custom-font infra don't exist yet).
                const _FontFamilySection(
                  label: _fontFamilyLabel,
                  value: _fontFamilyValue,
                  helper: _fontFamilyHelper,
                  addLabel: _addLocalFont,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The original 主题 `Select`: an outlined `borderRadius: 2` (16px) dropdown with
/// a floating label and a helper line. Wired to [onChanged].
class _ThemeSelect extends StatelessWidget {
  const _ThemeSelect({
    required this.label,
    required this.helper,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String helper;
  final AppThemeMode value;
  final List<(AppThemeMode, String)> options;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropdownButtonFormField<AppThemeMode>(
      initialValue: value,
      isExpanded: true,
      icon: Icon(
        LucideIcons.chevronDown,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      // The original `.MuiSelect-select` `fontSize: 0.9rem` on mobile (14.4px).
      style: theme.textTheme.bodyLarge?.copyWith(
        fontSize: 14.4,
        color: theme.colorScheme.onSurface,
      ),
      decoration: _selectDecoration(theme, label: label, helper: helper),
      items: [
        for (final (mode, text) in options)
          DropdownMenuItem<AppThemeMode>(value: mode, child: Text(text)),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

/// The original 语言 `Select`'s closed state: a globe + native name on the left,
/// the English name (caption) pushed to the right, then the dropdown arrow.
/// Rendered as a static, non-interactive field (Flutter has no i18n yet), so it
/// always shows the only available language — 简体中文.
class _LanguageSelect extends StatelessWidget {
  const _LanguageSelect({required this.label, required this.helper});

  final String label;
  final String helper;

  static const String _nativeName = '简体中文';
  static const String _englishName = '简体中文';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InputDecorator(
      decoration: _selectDecoration(theme, label: label, helper: helper),
      child: Row(
        children: [
          Icon(LucideIcons.globe, size: 16, color: theme.colorScheme.onSurface),
          const SizedBox(width: 8),
          Text(
            _nativeName,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 14.4,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          Text(
            _englishName,
            // The original caption (0.75rem = 12px), `text.secondary`.
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            LucideIcons.chevronDown,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

/// The shared outlined-select decoration: a floating label, a `borderRadius: 2`
/// (16px) outline and a 12px helper line, sized to the MUI ~56px field height.
InputDecoration _selectDecoration(
  ThemeData theme, {
  required String label,
  required String helper,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: theme.dividerColor),
  );
  return InputDecoration(
    labelText: label,
    helperText: helper,
    helperMaxLines: 3,
    helperStyle: theme.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      color: theme.colorScheme.onSurfaceVariant,
    ),
    labelStyle: theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
    ),
  );
}

/// The 全局字体大小 section: a label + value chip row over the gradient preset
/// slider and a helper line. Wired to [onChanged] — dragging the slider sets
/// the global font size, which the app shell folds into the active theme's
/// text scale.
class _FontSizeSection extends StatelessWidget {
  const _FontSizeSection({
    required this.label,
    required this.helper,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String helper;
  final int value;
  final ValueChanged<int> onChanged;

  // The original slider bounds (`min={12} max={24}`).
  static const int _min = 12;
  static const int _max = 24;

  // The original `fontSizePresets` (value, preset label), verbatim.
  static const List<(int, String)> _presets = [
    (12, '极小'),
    (14, '小'),
    (16, '标准'),
    (18, '大'),
    (20, '极大'),
    (24, '超大'),
  ];

  // The original `custom` label, shown for any value off a preset.
  static const String _customLabel = '自定义';

  // Mirrors the original `getCurrentFontSizeLabel`: the preset label if [size]
  // matches one, else 自定义.
  static String _labelFor(int size) {
    for (final (v, label) in _presets) {
      if (v == size) return label;
    }
    return _customLabel;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              // body1 with the original `fontSize: 0.9rem` on mobile (14.4px).
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 14.4,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            _FontSizeChip(label: '${value}px (${_labelFor(value)})'),
          ],
        ),
        const SizedBox(height: 16), // original `mb: 2` between row and slider
        _PresetSlider(
          value: value,
          min: _min,
          max: _max,
          presets: _presets,
          onChanged: onChanged,
        ),
        const SizedBox(height: 8), // original helper `mt: 1`
        Text(
          helper,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The original value `Chip` (`size="small" color="primary" variant="outlined"`):
/// a 24px-tall pill with a primary outline and primary 0.7rem (11.2px) weight-500
/// label.
class _FontSizeChip extends StatelessWidget {
  const _FontSizeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11.2,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// A reproduction of the original preset `Slider`: a 0.3-opacity primary rail, a
/// `#9333EA → #754AB4` gradient active track up to the current value, a solid
/// primary thumb and slate preset marks with `text.secondary` 10.4px labels.
///
/// When [onChanged] is non-null the whole track row is draggable/tappable (any
/// integer step in `[min, max]`, like the original `step={1}`); the value is
/// derived from the touch x-position. A null [onChanged] renders it as a static
/// preview.
class _PresetSlider extends StatelessWidget {
  const _PresetSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.presets,
    this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final List<(int, String)> presets;
  final ValueChanged<int>? onChanged;

  // The original `MuiSlider-track` gradient.
  static const Color _gradientStart = Color(0xFF9333EA);
  static const Color _gradientEnd = Color(0xFF754AB4);

  static const double _railHeight = 4;
  static const double _thumbSize = 20;
  static const double _trackRowHeight = 24;

  double _fraction(int v) => (v - min) / (max - min);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final railColor = theme.colorScheme.primary.withValues(alpha: 0.3);
    final thumbColor = theme.colorScheme.primary;
    final activeFraction = _fraction(value);

    final cb = onChanged;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Map a touch x-position to the nearest integer step (original
        // `step={1}`) and report it if it changed.
        void emit(double dx) {
          if (cb == null || width <= 0) return;
          final fraction = (dx / width).clamp(0.0, 1.0);
          final next = (min + fraction * (max - min)).round();
          if (next != value) cb(next);
        }

        final track = SizedBox(
          height: _trackRowHeight,
          width: width,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Rail (full width).
              Positioned(
                left: 0,
                right: 0,
                top: (_trackRowHeight - _railHeight) / 2,
                child: Container(
                  height: _railHeight,
                  decoration: BoxDecoration(
                    color: railColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Active gradient track (0 → current value).
              Positioned(
                left: 0,
                top: (_trackRowHeight - _railHeight) / 2,
                child: Container(
                  width: width * activeFraction,
                  height: _railHeight,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_gradientStart, _gradientEnd],
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
              // Preset marks (2x8 slate ticks).
              for (final (v, _) in presets)
                Positioned(
                  left: (width * _fraction(v) - 1).clamp(0.0, width - 2),
                  top: (_trackRowHeight - 8) / 2,
                  child: Container(width: 2, height: 8, color: thumbColor),
                ),
              // Thumb.
              Positioned(
                left: (width * activeFraction - _thumbSize / 2).clamp(
                  0.0,
                  width - _thumbSize,
                ),
                top: (_trackRowHeight - _thumbSize) / 2,
                child: Container(
                  width: _thumbSize,
                  height: _thumbSize,
                  decoration: BoxDecoration(
                    color: thumbColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cb == null)
              track
            else
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => emit(d.localPosition.dx),
                onHorizontalDragStart: (d) => emit(d.localPosition.dx),
                onHorizontalDragUpdate: (d) => emit(d.localPosition.dx),
                child: track,
              ),
            const SizedBox(height: 8),
            // Preset labels, centered under their marks (the ends align to the
            // track edges, matching the original's `translateX(-50%)` clamped at
            // the rail bounds).
            SizedBox(
              height: 16,
              width: width,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < presets.length; i++)
                    _markLabel(theme, width, i),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _markLabel(ThemeData theme, double width, int index) {
    final (v, label) = presets[index];
    final text = Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        fontSize: 10.4,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    if (index == 0) return Positioned(left: 0, top: 0, child: text);
    if (index == presets.length - 1) {
      return Positioned(right: 0, top: 0, child: text);
    }
    return Positioned(
      left: width * _fraction(v),
      top: 0,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: text,
      ),
    );
  }
}

/// The 全局字体 field + 添加本地字体 button. A readOnly outlined field showing the
/// current font with a trailing chevron, over an outlined "添加本地字体" button.
/// Both are static this milestone (the font selector sub-page / custom-font
/// import don't exist yet), so the whole block ignores pointer input.
class _FontFamilySection extends StatelessWidget {
  const _FontFamilySection({
    required this.label,
    required this.value,
    required this.helper,
    required this.addLabel,
  });

  final String label;
  final String value;
  final String helper;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: theme.dividerColor),
    );

    return IgnorePointer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              helperText: helper,
              helperMaxLines: 3,
              helperStyle: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              labelStyle: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
              border: border,
              enabledBorder: border,
              suffixIcon: Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8), // original button `mt: 1`
          // MUI outlined small Button: a 1px primary outline, primary weight-500
          // label, `borderRadius: 2` (16px).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              addLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "界面定制" card: a tinted header over six brand-tinted avatar rows that,
/// in the original, navigate to third-level appearance sub-pages. Those pages
/// aren't built yet, so every row renders greyed (置灰) and carries no handler.
class _CustomizationCard extends StatelessWidget {
  const _CustomizationCard();

  static const String _title = '界面定制';
  static const String _description = '自定义聊天界面、消息气泡和工具栏的外观设置';

  // The six rows, in the original's order, with their verbatim brand-hue avatars.
  static const List<_CustomizationItem> _items = [
    _CustomizationItem(
      icon: LucideIcons.palette,
      accent: Color(0xFF9333EA), // purple
      title: '主题风格',
      description: '选择应用的整体设计风格和色彩主题',
    ),
    _CustomizationItem(
      icon: LucideIcons.layoutDashboard,
      accent: Color(0xFF10B981), // emerald
      title: '顶部工具栏设置',
      description: '自定义顶部工具栏的组件和布局，支持拖拽DIY布局',
    ),
    _CustomizationItem(
      icon: LucideIcons.messageSquare,
      accent: Color(0xFF6366F1), // indigo
      title: '聊天界面设置',
      description: '自定义聊天界面布局和显示选项',
    ),
    _CustomizationItem(
      icon: LucideIcons.sparkles,
      accent: Color(0xFFF59E0B), // amber
      title: '思考过程设置',
      description: '自定义AI思考过程的显示方式和自动折叠行为',
    ),
    _CustomizationItem(
      icon: LucideIcons.messageCircle,
      accent: Color(0xFF8B5CF6), // violet
      title: '信息气泡管理',
      description: '调整消息气泡的样式和宽度设置',
    ),
    _CustomizationItem(
      icon: LucideIcons.edit3,
      accent: Color(0xFFEC4899), // pink
      title: '输入框管理设置',
      description: '自定义输入框的风格和布局样式',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _AppearanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _CardHeader(title: _title, description: _description),
          const Divider(height: 1, thickness: 1),
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1),
            _CustomizationRow(item: _items[i]),
          ],
        ],
      ),
    );
  }
}

/// One "界面定制" row's data.
class _CustomizationItem {
  const _CustomizationItem({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String description;
}

/// A single "界面定制" row: the original `ListItemButton` (8px×16px padding) with
/// a 40px brand-tinted avatar, body1 title, body2 description and a trailing
/// 20px chevron. Greyed at 0.5 opacity and non-interactive — its third-level
/// destination isn't built yet (置灰).
class _CustomizationRow extends StatelessWidget {
  const _CustomizationRow({required this.item});

  final _CustomizationItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.accent.withValues(alpha: 0.12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000), // rgba(0,0,0,0.05)
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(item.icon, size: 20, color: item.accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// The "开发者工具" card: a tinted header over two title/description rows, each
/// with a trailing [CustomSwitch]. The switches render off and non-interactive —
/// the perf monitor / devtools floating button don't exist on Flutter yet.
class _DeveloperToolsCard extends StatelessWidget {
  const _DeveloperToolsCard();

  static const String _title = '开发者工具';
  static const String _description = '用于调试和性能监控的开发者工具设置';
  static const String _perfTitle = '显示性能监控';
  static const String _perfDesc = '在聊天界面显示实时性能监控面板，包括FPS、滚动事件、渲染时间和内存使用情况';
  static const String _floatTitle = '显示开发者工具悬浮按钮';
  static const String _floatDesc = '在聊天界面显示一个悬浮按钮，点击可快速进入开发者工具页面';

  @override
  Widget build(BuildContext context) {
    return const _AppearanceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CardHeader(title: _title, description: _description),
          Divider(height: 1, thickness: 1),
          Padding(
            padding: EdgeInsets.all(24), // original `Box p:3`
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DevToolRow(title: _perfTitle, description: _perfDesc),
                Divider(height: 32), // original divider `my: 2` (16 + 16)
                _DevToolRow(title: _floatTitle, description: _floatDesc),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One developer-tools row: a body1 title over a body2 description on the left,
/// with a top-aligned [CustomSwitch] on the right (off, non-interactive).
class _DevToolRow extends StatelessWidget {
  const _DevToolRow({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                // body1 with the original `fontSize: 0.9rem` on mobile (14.4px).
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 14.4,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4), // original `mb: 0.5`
              Text(
                description,
                // body2 with the original `fontSize: 0.8rem` (12.8px), lh 1.5.
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12.8,
                  height: 1.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16), // original `gap: 2`
        const Padding(
          padding: EdgeInsets.only(top: 4), // original right box `pt: 0.5`
          child: CustomSwitch(value: false),
        ),
      ],
    );
  }
}
