import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';

part 'onboarding_controller.g.dart';

/// Storage key for the persisted first-time-user flag — the exact key the web
/// used (`getStorageItem('first-time-user')`), so existing installs read back
/// correctly. The web only checks *presence*: a missing key means a first-time
/// user; once onboarding is done it writes the string `'false'`.
const String kFirstTimeUserSettingKey = 'first-time-user';

/// Tracks whether the first-time welcome page still needs to be shown.
///
/// The state is `true` for a first-time user (show the welcome page) and `false`
/// once onboarding is done. It hydrates from the Drift key/value store: the web
/// gated `/welcome` on whether `first-time-user` was absent
/// (`firstTimeUserValue === null`), so a missing key → still needs onboarding,
/// and any stored value → done.
///
/// `keepAlive: true`: this is an app-level flag, not screen-scoped state — it
/// must survive the welcome page being disposed after navigation, so it is not
/// auto-disposed.
@Riverpod(keepAlive: true)
class OnboardingController extends _$OnboardingController {
  @override
  Future<bool> build() async {
    final stored = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kFirstTimeUserSettingKey);
    return stored == null;
  }

  /// Marks onboarding done and persists it; the welcome page calls this before
  /// navigating to the chat home, so the welcome page does not reappear on the
  /// next launch. Mirrors the web's `setStorageItem('first-time-user', 'false')`
  /// — the write is fire-and-forget (matching the scalar controllers), but the
  /// in-memory state flips immediately so the gate is consistent this session.
  void markStarted() {
    state = const AsyncData(false);
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kFirstTimeUserSettingKey, 'false');
  }
}
