import 'package:aetherlink_flutter/features/theming/domain/theme_spec.dart';

/// A built-in theme option shown in the 主题风格 selector — a [ThemeSpec] plus the
/// presentation-only metadata the original `ThemeStyleSelector` rendered next to
/// it (a one-line [description] and the card's preview [gradientStart] →
/// [gradientEnd] sweep).
///
/// Ported 1:1 from `src/shared/config/themes.ts` `ThemeConfig`: the spec carries
/// the color roles (the original `colors`), while [description] / the gradient
/// mirror the original `description` / `gradients.primary`. Pure Dart (no Flutter
/// import) so it stays in `domain`; the gradient is stored as two `0xAARRGGBB`
/// ints which the presentation layer wraps in `Color`.
class ThemePreset {
  const ThemePreset({
    required this.spec,
    required this.description,
    required this.gradientStart,
    required this.gradientEnd,
  });

  /// The theme this card applies; [ThemeSpec.id] is the stable style key (the
  /// original `ThemeStyle`, e.g. `claude`) and [ThemeSpec.name] its display name.
  final ThemeSpec spec;

  /// The card's secondary line (the original `themeConfigs[x].description`).
  final String description;

  /// The preview swatch gradient start (the original `gradients.primary` from).
  final int gradientStart;

  /// The preview swatch gradient end (the original `gradients.primary` to).
  final int gradientEnd;

  /// Convenience accessor for the style key used for persistence / selection.
  String get id => spec.id;
}
