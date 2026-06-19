import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/settings/domain/app_theme_mode.dart';

part 'theme_mode_controller.g.dart';

/// Storage key for the persisted theme mode — a scalar string mirroring the
/// web's `settings.theme` (`'light' | 'dark' | 'system'`).
const String kThemeModeSettingKey = 'theme';

/// Holds the active [AppThemeMode] (the original `settings.theme`) for the
/// application layer, so the appearance page stays a pure view.
///
/// Seeds [AppThemeMode.system] — matching the app shell's prior behaviour of
/// leaving `MaterialApp.themeMode` unset, which defaults to follow-system. The
/// value is hydrated from the Drift key/value store on first build and written
/// through on every change, so the mode survives a full restart (the web kept
/// it under `settings.theme`).
///
/// `keepAlive: true`: an app-level preference that must survive the appearance
/// page being disposed when navigating away, so it is not auto-disposed.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  AppThemeMode build() {
    _hydrate();
    return AppThemeMode.system;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kThemeModeSettingKey);
    if (stored == null || stored.isEmpty) return;
    for (final mode in AppThemeMode.values) {
      if (mode.name == stored) {
        state = mode;
        return;
      }
    }
  }

  /// Switches the active theme mode; the appearance page's 主题 dropdown calls
  /// this.
  void use(AppThemeMode mode) {
    state = mode;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kThemeModeSettingKey, mode.name);
  }
}
