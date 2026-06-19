import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/behavior_settings.dart';

part 'behavior_settings_controller.g.dart';

/// Storage key for the persisted 行为 settings (a single JSON blob, mirroring
/// how the web kept the behavior fields inside `settings`).
const String kBehaviorSettingsKey = 'behaviorSettings';

/// Holds the 行为 settings (the original `settingsSlice` behavior fields), so
/// the 行为 page stays a pure view and the chat composer / haptic service can
/// read them.
///
/// `keepAlive: true`: an app-level preference shared by the settings page, the
/// chat composer (Enter-to-send) and the global haptic service. Hydrated from
/// the Drift key/value store on first build and written through on every change
/// so the configuration survives a full restart.
@Riverpod(keepAlive: true)
class BehaviorSettingsController extends _$BehaviorSettingsController
    with JsonKvNotifier<BehaviorSettings> {
  @override
  ChatRepository get kvStore => ref.read(appSettingsStoreProvider);

  @override
  String get storageKey => kBehaviorSettingsKey;

  @override
  BehaviorSettings fromStored(Map<String, dynamic> json) =>
      BehaviorSettings.fromJson(json);

  @override
  Map<String, dynamic> toStored(BehaviorSettings value) => value.toJson();

  @override
  BehaviorSettings build() => hydrate(const BehaviorSettings());

  /// Toggles Enter 发送消息.
  void setSendWithEnter(bool value) =>
      persist(state.copyWith(sendWithEnter: value));

  /// Toggles 通知 (UI-only for now).
  void setEnableNotifications(bool value) =>
      persist(state.copyWith(enableNotifications: value));

  /// Toggles 输入法回车换行 (mobile soft-keyboard Enter inserts a newline).
  void setMobileInputMethodEnterAsNewline(bool value) =>
      persist(state.copyWith(mobileInputMethodEnterAsNewline: value));

  /// Toggles the 触觉反馈 master switch.
  void setHapticEnabled(bool value) => persist(
    state.copyWith(
      hapticFeedback: state.hapticFeedback.copyWith(enabled: value),
    ),
  );

  /// Toggles 侧边栏 haptics.
  void setHapticOnSidebar(bool value) => persist(
    state.copyWith(
      hapticFeedback: state.hapticFeedback.copyWith(enableOnSidebar: value),
    ),
  );

  /// Toggles 开关 haptics.
  void setHapticOnSwitch(bool value) => persist(
    state.copyWith(
      hapticFeedback: state.hapticFeedback.copyWith(enableOnSwitch: value),
    ),
  );

  /// Toggles 列表项 haptics.
  void setHapticOnListItem(bool value) => persist(
    state.copyWith(
      hapticFeedback: state.hapticFeedback.copyWith(enableOnListItem: value),
    ),
  );

  /// Toggles 导航 haptics.
  void setHapticOnNavigation(bool value) => persist(
    state.copyWith(
      hapticFeedback: state.hapticFeedback.copyWith(enableOnNavigation: value),
    ),
  );
}
