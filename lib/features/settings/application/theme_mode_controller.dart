import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/settings/domain/app_theme_mode.dart';

part 'theme_mode_controller.g.dart';

/// Holds the active [AppThemeMode] (the original `settings.theme`) for the
/// application layer, so the appearance page stays a pure view.
///
/// Seeds [AppThemeMode.system] — matching the app shell's prior behaviour of
/// leaving `MaterialApp.themeMode` unset, which defaults to follow-system. It
/// lives in memory only for now, mirroring the onboarding / view-mode
/// controllers' "seam, not yet persisted" approach: the original persisted
/// `settings.theme`, but where app preferences live (shared_preferences vs a
/// Drift settings table) is a separate decision, so the mode resets to
/// follow-system on each cold start until persistence is wired.
///
/// `keepAlive: true`: an app-level preference that must survive the appearance
/// page being disposed when navigating away, so it is not auto-disposed.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  AppThemeMode build() => AppThemeMode.system;

  /// Switches the active theme mode; the appearance page's 主题 dropdown calls
  /// this.
  // ignore: use_setters_to_change_properties
  void use(AppThemeMode mode) => state = mode;
}
