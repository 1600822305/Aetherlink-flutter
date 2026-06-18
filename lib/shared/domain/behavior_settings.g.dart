// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'behavior_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HapticFeedbackSettings _$HapticFeedbackSettingsFromJson(
  Map<String, dynamic> json,
) => _HapticFeedbackSettings(
  enabled: json['enabled'] as bool? ?? true,
  enableOnSidebar: json['enableOnSidebar'] as bool? ?? true,
  enableOnSwitch: json['enableOnSwitch'] as bool? ?? true,
  enableOnListItem: json['enableOnListItem'] as bool? ?? false,
  enableOnNavigation: json['enableOnNavigation'] as bool? ?? true,
);

Map<String, dynamic> _$HapticFeedbackSettingsToJson(
  _HapticFeedbackSettings instance,
) => <String, dynamic>{
  'enabled': instance.enabled,
  'enableOnSidebar': instance.enableOnSidebar,
  'enableOnSwitch': instance.enableOnSwitch,
  'enableOnListItem': instance.enableOnListItem,
  'enableOnNavigation': instance.enableOnNavigation,
};

_BehaviorSettings _$BehaviorSettingsFromJson(Map<String, dynamic> json) =>
    _BehaviorSettings(
      sendWithEnter: json['sendWithEnter'] as bool? ?? true,
      enableNotifications: json['enableNotifications'] as bool? ?? true,
      mobileInputMethodEnterAsNewline:
          json['mobileInputMethodEnterAsNewline'] as bool? ?? false,
      hapticFeedback: json['hapticFeedback'] == null
          ? const HapticFeedbackSettings()
          : HapticFeedbackSettings.fromJson(
              json['hapticFeedback'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$BehaviorSettingsToJson(
  _BehaviorSettings instance,
) => <String, dynamic>{
  'sendWithEnter': instance.sendWithEnter,
  'enableNotifications': instance.enableNotifications,
  'mobileInputMethodEnterAsNewline': instance.mobileInputMethodEnterAsNewline,
  'hapticFeedback': instance.hapticFeedback.toJson(),
};
