import 'package:freezed_annotation/freezed_annotation.dart';

part 'behavior_settings.freezed.dart';
part 'behavior_settings.g.dart';

/// The 触觉反馈 configuration (port of the web `settings.hapticFeedback`).
///
/// [enabled] is the master switch; the rest gate haptics at individual
/// interaction points. Defaults mirror the original `DEFAULT_HAPTIC_FEEDBACK`
/// (everything on except list-item taps).
@freezed
abstract class HapticFeedbackSettings with _$HapticFeedbackSettings {
  const factory HapticFeedbackSettings({
    @Default(true) bool enabled,
    @Default(true) bool enableOnSidebar,
    @Default(true) bool enableOnSwitch,
    @Default(false) bool enableOnListItem,
    @Default(true) bool enableOnNavigation,
  }) = _HapticFeedbackSettings;

  factory HapticFeedbackSettings.fromJson(Map<String, dynamic> json) =>
      _$HapticFeedbackSettingsFromJson(json);
}

/// The 行为 settings (port of the web `settingsSlice` behavior fields).
///
/// [sendWithEnter] / [mobileInputMethodEnterAsNewline] drive the chat
/// composer's Enter-key behavior; [enableNotifications] is UI-only for now (no
/// notification subsystem on Flutter yet); [hapticFeedback] is the nested
/// haptic config. Defaults mirror the original `getInitialState`.
@freezed
abstract class BehaviorSettings with _$BehaviorSettings {
  const factory BehaviorSettings({
    @Default(true) bool sendWithEnter,
    @Default(true) bool enableNotifications,
    @Default(false) bool mobileInputMethodEnterAsNewline,
    @Default(HapticFeedbackSettings()) HapticFeedbackSettings hapticFeedback,
  }) = _BehaviorSettings;

  factory BehaviorSettings.fromJson(Map<String, dynamic> json) =>
      _$BehaviorSettingsFromJson(json);
}
