import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/app/theme/app_chinese_fonts.dart';
import 'package:aetherlink_flutter/app/theme/app_theme_extension.dart';
import 'package:aetherlink_flutter/features/theming/domain/theme_spec.dart';

/// Pure mapping from the data-only [ThemeSpec] (domain) to Flutter `ThemeData`
/// + `ThemeExtension` (ADR-0008 line-rule one). This is the only place the
/// token data meets the framework; it imports Flutter and therefore lives in
/// the app/presentation layer, never in `domain`.
///
/// `useMaterial3` is intentionally `false` to keep a 1:1 port of the original
/// MUI v7 look (see `docs/CONTEXT.md`).
///
/// Page transition animations are globally disabled via [_NoTransitionsBuilder]
/// so route changes are instant.
abstract final class AppTheme {
  /// [appFontFamily] overrides [ThemeSpec.typography] with the user's 全局应用字体
  /// (system / Google / local). `null` keeps the spec / platform default.
  static ThemeData light(ThemeSpec spec, {String? appFontFamily}) =>
      _build(spec, spec.colors.light, Brightness.light, appFontFamily);

  static ThemeData dark(ThemeSpec spec, {String? appFontFamily}) =>
      _build(spec, spec.colors.dark, Brightness.dark, appFontFamily);

  static ThemeData _build(
    ThemeSpec spec,
    ColorRoleSet roles,
    Brightness brightness,
    String? appFontFamily,
  ) {
    final fontFamily = appFontFamily ?? spec.typography.fontFamily;
    final primary = Color(roles.primary);
    final secondary = Color(roles.secondary);
    final surface = Color(roles.surface);
    final background = Color(roles.background);
    final textPrimary = Color(roles.textPrimary);
    final textSecondary = Color(roles.textSecondary);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: _onColor(primary),
      secondary: secondary,
      onSecondary: _onColor(secondary),
      error: const Color(0xFFB00020),
      onError: const Color(0xFFFFFFFF),
      surface: surface,
      onSurface: textPrimary,
      // Map the muted role to the original's `text.secondary` token so every
      // secondary label / trailing icon reads in the slate-gray it expects,
      // instead of Material's darker default (ADR-0008).
      onSurfaceVariant: textSecondary,
    );

    final baseTypography = brightness == Brightness.dark
        ? Typography.material2018().white
        : Typography.material2018().black;
    final textTheme = baseTypography
        .apply(
          fontFamily: fontFamily,
          fontSizeFactor: spec.typography.textScale,
          displayColor: textPrimary,
          bodyColor: textPrimary,
        )
        .copyWith(
          bodySmall: baseTypography.bodySmall?.copyWith(color: textSecondary),
        );

    return ThemeData(
      useMaterial3: false,
      brightness: brightness,
      colorScheme: colorScheme,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      fontFamily: fontFamily,
      textTheme: textTheme,
      visualDensity: _density(spec.density),
      // 下拉菜单（PopupMenuButton/showMenu）跟随主题 surface。默认取
      // surfaceContainer 且 M2 暗色下 elevation 8 会叠加 onSurface 高程
      // 罩层（ElevationOverlay），菜单显示成偏灰的"非主题色"；这里用
      // 与面板一致的 3% onSurface 混色（同时避开 color == surface 才触发
      // 的高程罩层），圆角对齐主题 borderRadius。
      popupMenuTheme: PopupMenuThemeData(
        color: Color.alphaBlend(
          textPrimary.withValues(alpha: 0.03),
          surface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(spec.shape.borderRadius),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _NoTransitionsBuilder(),
          TargetPlatform.iOS: _NoTransitionsBuilder(),
        },
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppThemeExtension(
          bubbleUser: Color(roles.bubbleUser),
          bubbleAi: Color(roles.bubbleAi),
          borderRadius: spec.shape.borderRadius,
        ),
      ],
    ).useSystemChineseFallback();
  }

  static VisualDensity _density(ThemeDensity density) => switch (density) {
    ThemeDensity.compact => VisualDensity.compact,
    ThemeDensity.standard => VisualDensity.standard,
    ThemeDensity.comfortable => VisualDensity.comfortable,
  };

  /// Picks black/white foreground based on the background luminance so text on
  /// [color] stays legible.
  static Color _onColor(Color color) =>
      color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

/// A [PageTransitionsBuilder] that returns the page instantly with no animation.
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
