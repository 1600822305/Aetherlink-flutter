import 'package:aetherlink_flutter/features/theming/domain/theme_spec.dart';

/// The built-in "default" theme, ported 1:1 from the original
/// `src/shared/config/themes.ts` `themeConfigs.default` (primary/secondary plus
/// the per-brightness background / paper / text roles). The remaining nine
/// presets and gradient/decoration tokens are deferred (M4.0 ports only the
/// default light+dark core tokens).
///
/// Chat-bubble roles are not defined by `themes.ts`; they are seeded here with
/// palette-consistent values and will be refined when the chat UI lands (M4.1).
const ThemeSpec defaultThemeSpec = ThemeSpec(
  id: 'default',
  name: '默认主题',
  colors: ThemeColors(
    light: ColorRoleSet(
      primary: 0xFF64748B,
      secondary: 0xFF10B981,
      background: 0xFFFFFFFF,
      surface: 0xFFFFFFFF,
      textPrimary: 0xFF1E293B,
      textSecondary: 0xFF64748B,
      bubbleUser: 0xFF64748B,
      bubbleAi: 0xFFF1F5F9,
    ),
    dark: ColorRoleSet(
      primary: 0xFF64748B,
      secondary: 0xFF10B981,
      background: 0xFF1A1A1A,
      surface: 0xFF2A2A2A,
      textPrimary: 0xFFF0F0F0,
      textSecondary: 0xFFB0B0B0,
      bubbleUser: 0xFF334155,
      bubbleAi: 0xFF2A2A2A,
    ),
  ),
  // Roboto is the cross-platform member of the original's system font stack
  // (themes.ts `system`), bundled so every platform renders in the same font.
  typography: ThemeTypography(fontFamily: 'Roboto'),
  shape: ThemeShape(),
  density: ThemeDensity.standard,
);
