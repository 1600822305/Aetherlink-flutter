import 'package:flutter/material.dart';

/// Application theme assembly (placeholder).
///
/// Material 3 is intentionally disabled because the target look is a 1:1 port
/// of the original MUI v7 design; the real design tokens will be extracted from
/// the original `themes.ts` in a later milestone (see `docs/ARCHITECTURE.md`).
abstract final class AppTheme {
  static ThemeData get light => ThemeData(useMaterial3: false);
}
