import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/app/theme/app_theme_extension.dart';
import 'package:aetherlink_flutter/features/theming/domain/theme_spec.dart';

/// Pure mapping from the data-only [ThemeSpec] (domain) to Flutter `ThemeData`
/// + `ThemeExtension` (ADR-0008 line-rule one). This is the only place the
/// token data meets the framework; it imports Flutter and therefore lives in
/// the app/presentation layer, never in `domain`.
///
/// `useMaterial3` is intentionally `false` to keep a 1:1 port of the original
/// MUI v7 look (see `docs/CONTEXT.md`).
abstract final class AppTheme {
  static ThemeData light(ThemeSpec spec) =>
      _build(spec, spec.colors.light, Brightness.light);

  static ThemeData dark(ThemeSpec spec) =>
      _build(spec, spec.colors.dark, Brightness.dark);

  static ThemeData _build(
    ThemeSpec spec,
    ColorRoleSet roles,
    Brightness brightness,
  ) {
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
    );

    final baseTypography = brightness == Brightness.dark
        ? Typography.material2018().white
        : Typography.material2018().black;
    final textTheme = baseTypography
        .apply(
          fontFamily: spec.typography.fontFamily,
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
      fontFamily: spec.typography.fontFamily,
      textTheme: textTheme,
      visualDensity: _density(spec.density),
      extensions: <ThemeExtension<dynamic>>[
        AppThemeExtension(
          bubbleUser: Color(roles.bubbleUser),
          bubbleAi: Color(roles.bubbleAi),
          borderRadius: spec.shape.borderRadius,
        ),
      ],
    );
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
