import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';

part 'settings_view_mode_controller.g.dart';

/// Storage key for the persisted settings-hub view mode — the web's
/// `settings-compact-mode` flag.
const String kSettingsViewModeKey = 'settings-compact-mode';

/// Holds the settings hub's "compact ↔ detailed" view mode for the application
/// layer (the page stays a pure view — no business logic, see
/// PROJECT_STRUCTURE / ADR-0009).
///
/// `true` = compact (titles only), `false` = detailed (titles + descriptions).
/// It seeds `false` (detailed is the default, matching the original), then
/// hydrates from the Drift key/value store on first build and writes through on
/// every toggle, so the choice survives a full restart (the web persisted this
/// under the `settings-compact-mode` localStorage key).
///
/// `keepAlive: true`: this is an app-level UI preference, not screen-scoped
/// state — it must survive the settings page being disposed when navigating
/// into a sub-page and back, so it is not auto-disposed.
@Riverpod(keepAlive: true)
class SettingsViewModeController extends _$SettingsViewModeController {
  @override
  bool build() {
    _hydrate();
    return false;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kSettingsViewModeKey);
    if (stored == null || stored.isEmpty) return;
    state = stored == 'true';
  }

  /// Flips between compact and detailed; the header toggle calls this.
  void toggle() {
    state = !state;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kSettingsViewModeKey, state.toString());
  }
}
