import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/theming/application/default_theme_spec.dart';
import 'package:aetherlink_flutter/features/theming/application/theme_presets.dart';
import 'package:aetherlink_flutter/features/theming/domain/theme_spec.dart';

part 'theme_controller.g.dart';

/// Storage key for the persisted 主题风格 selection — a single style id string
/// (the port of the web `settings.themeStyle`).
const String kThemeStyleSettingKey = 'themeStyle';

/// Holds the currently active [ThemeSpec] and supports hot-swapping it at
/// runtime (ADR-0008: Riverpod `themeSpecProvider` drives `MaterialApp`).
///
/// The app shell watches this and rebuilds its `ThemeData` whenever [use] /
/// [useStyle] is called, so switching themes is instant and side-effect free.
///
/// The selected built-in preset is persisted through the Drift key/value store
/// (the port of the web `dexieStorage.saveSetting('themeStyle', …)`): [build]
/// seeds with [defaultThemeSpec] and hydrates the last-applied style on first
/// build, and [useStyle] writes the choice through so it survives a restart.
@riverpod
class ThemeController extends _$ThemeController {
  @override
  ThemeSpec build() {
    _hydrate();
    return defaultThemeSpec;
  }

  /// Restores the last-applied style from the KV store on first build. A no-op
  /// when nothing was persisted (keeps the [defaultThemeSpec] seed).
  Future<void> _hydrate() async {
    final stored = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kThemeStyleSettingKey);
    if (stored == null || stored.isEmpty) return;
    state = themeSpecForStyle(stored);
  }

  /// Switches to the built-in preset [id] and persists the choice. Unknown ids
  /// fall back to the default theme (mirrors the web `getValidThemeStyle`).
  void useStyle(String id) {
    state = themeSpecForStyle(id);
    ref.read(appSettingsStoreProvider).saveSetting(kThemeStyleSettingKey, id);
  }

  /// Hot-swap the active theme. The app shell rebuilds its `ThemeData` from the
  /// new spec on the next frame.
  void use(ThemeSpec spec) => state = spec;

  /// Revert to the built-in default theme (and persist the reset).
  void reset() => useStyle('default');

  /// Seam for persistence: loads a [ThemeSpec] directly (e.g. an imported custom
  /// theme) without going through the preset registry. Built-in style selection
  /// goes through [useStyle].
  // ignore: use_setters_to_change_properties
  void restore(ThemeSpec persisted) => state = persisted;
}
