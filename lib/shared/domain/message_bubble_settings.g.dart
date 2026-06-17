// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_bubble_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CustomBubbleColors _$CustomBubbleColorsFromJson(Map<String, dynamic> json) =>
    _CustomBubbleColors(
      userBubbleColor: json['userBubbleColor'] as String? ?? '',
      userTextColor: json['userTextColor'] as String? ?? '',
      aiBubbleColor: json['aiBubbleColor'] as String? ?? '',
      aiTextColor: json['aiTextColor'] as String? ?? '',
    );

Map<String, dynamic> _$CustomBubbleColorsToJson(_CustomBubbleColors instance) =>
    <String, dynamic>{
      'userBubbleColor': instance.userBubbleColor,
      'userTextColor': instance.userTextColor,
      'aiBubbleColor': instance.aiBubbleColor,
      'aiTextColor': instance.aiTextColor,
    };

_MessageBubbleSettings _$MessageBubbleSettingsFromJson(
  Map<String, dynamic> json,
) => _MessageBubbleSettings(
  messageActionMode:
      $enumDecodeNullable(
        _$MessageActionModeEnumMap,
        json['messageActionMode'],
      ) ??
      MessageActionMode.bubbles,
  showMicroBubbles: json['showMicroBubbles'] as bool? ?? true,
  showTTSButton: json['showTTSButton'] as bool? ?? true,
  versionSwitchStyle:
      $enumDecodeNullable(
        _$VersionSwitchStyleEnumMap,
        json['versionSwitchStyle'],
      ) ??
      VersionSwitchStyle.popup,
  messageBubbleMaxWidth: (json['messageBubbleMaxWidth'] as num?)?.toInt() ?? 99,
  userMessageMaxWidth: (json['userMessageMaxWidth'] as num?)?.toInt() ?? 80,
  messageBubbleMinWidth: (json['messageBubbleMinWidth'] as num?)?.toInt() ?? 50,
  showUserAvatar: json['showUserAvatar'] as bool? ?? true,
  showUserName: json['showUserName'] as bool? ?? true,
  showModelAvatar: json['showModelAvatar'] as bool? ?? true,
  showModelName: json['showModelName'] as bool? ?? true,
  hideUserBubble: json['hideUserBubble'] as bool? ?? false,
  hideAIBubble: json['hideAIBubble'] as bool? ?? false,
  customBubbleColors: json['customBubbleColors'] == null
      ? const CustomBubbleColors()
      : CustomBubbleColors.fromJson(
          json['customBubbleColors'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$MessageBubbleSettingsToJson(
  _MessageBubbleSettings instance,
) => <String, dynamic>{
  'messageActionMode': _$MessageActionModeEnumMap[instance.messageActionMode]!,
  'showMicroBubbles': instance.showMicroBubbles,
  'showTTSButton': instance.showTTSButton,
  'versionSwitchStyle':
      _$VersionSwitchStyleEnumMap[instance.versionSwitchStyle]!,
  'messageBubbleMaxWidth': instance.messageBubbleMaxWidth,
  'userMessageMaxWidth': instance.userMessageMaxWidth,
  'messageBubbleMinWidth': instance.messageBubbleMinWidth,
  'showUserAvatar': instance.showUserAvatar,
  'showUserName': instance.showUserName,
  'showModelAvatar': instance.showModelAvatar,
  'showModelName': instance.showModelName,
  'hideUserBubble': instance.hideUserBubble,
  'hideAIBubble': instance.hideAIBubble,
  'customBubbleColors': instance.customBubbleColors.toJson(),
};

const _$MessageActionModeEnumMap = {
  MessageActionMode.bubbles: 'bubbles',
  MessageActionMode.toolbar: 'toolbar',
};

const _$VersionSwitchStyleEnumMap = {
  VersionSwitchStyle.popup: 'popup',
  VersionSwitchStyle.arrows: 'arrows',
};
