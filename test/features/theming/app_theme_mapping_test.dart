import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/theme/app_theme.dart';
import 'package:aetherlink_flutter/app/theme/app_theme_extension.dart';
import 'package:aetherlink_flutter/features/theming/application/default_theme_spec.dart';

void main() {
  group('AppTheme maps ThemeSpec -> ThemeData', () {
    test('light theme uses Material 2 and the default light tokens', () {
      final theme = AppTheme.light(defaultThemeSpec);

      expect(theme.useMaterial3, isFalse);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, const Color(0xFF64748B));
      expect(theme.colorScheme.secondary, const Color(0xFF10B981));
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
    });

    test('dark theme uses the default dark tokens', () {
      final theme = AppTheme.dark(defaultThemeSpec);

      expect(theme.useMaterial3, isFalse);
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF1A1A1A));
      expect(theme.canvasColor, const Color(0xFF2A2A2A));
    });

    test('custom component styles are exposed via AppThemeExtension', () {
      final ext = AppTheme.light(
        defaultThemeSpec,
      ).extension<AppThemeExtension>();

      expect(ext, isNotNull);
      expect(ext!.bubbleUser, const Color(0xFF64748B));
      expect(ext.bubbleAi, const Color(0xFFF1F5F9));
      expect(ext.borderRadius, 8.0);
    });
  });
}
