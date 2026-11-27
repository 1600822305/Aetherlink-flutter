import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/mobile_background_settings.dart';

part 'mobile_background_settings_controller.g.dart';

/// Storage key for the persisted 后台执行 settings (a single JSON blob).
const String kMobileBackgroundSettingsKey = 'mobileBackgroundSettings';

/// Holds the 后台执行 settings; the app shell pushes every change to
/// [MobileBackgroundCoordinator] so the native runtime sees it immediately.
@Riverpod(keepAlive: true)
class MobileBackgroundSettingsController
    extends _$MobileBackgroundSettingsController
    with JsonKvNotifier<MobileBackgroundSettings> {
  @override
  ChatRepository get kvStore => ref.read(appSettingsStoreProvider);

  @override
  String get storageKey => kMobileBackgroundSettingsKey;

  @override
  MobileBackgroundSettings fromStored(Map<String, dynamic> json) =>
      MobileBackgroundSettings.fromJson(json);

  @override
  Map<String, dynamic> toStored(MobileBackgroundSettings value) =>
      value.toJson();

  @override
  MobileBackgroundSettings build() => hydrate(const MobileBackgroundSettings());

  void setEnabled(bool value) =>
      persist(state.copyWith(androidEnabled: value));

  void setNotificationsEnabled(bool value) =>
      persist(state.copyWith(notificationsEnabled: value));

  void setPrivacyMode(bool value) =>
      persist(state.copyWith(privacyMode: value));

  void setOverlayEnabled(bool value) =>
      persist(state.copyWith(overlayEnabled: value));

  void setLiveUpdatesEnabled(bool value) =>
      persist(state.copyWith(liveUpdatesEnabled: value));

  void setCompletionVisibility(BackgroundCompletionVisibility value) =>
      persist(state.copyWith(completionVisibility: value));

  void setOverlayAppearance(BackgroundOverlayAppearance value) =>
      persist(state.copyWith(overlayAppearance: value));

  void setBatteryPromptDismissed(bool value) =>
      persist(state.copyWith(batteryPromptDismissed: value));

  void setTerminalKeepAlive(bool value) =>
      persist(state.copyWith(terminalKeepAlive: value));
}
