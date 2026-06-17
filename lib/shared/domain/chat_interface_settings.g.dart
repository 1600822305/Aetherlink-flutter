// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_interface_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatBackgroundSettings _$ChatBackgroundSettingsFromJson(
  Map<String, dynamic> json,
) => _ChatBackgroundSettings(
  enabled: json['enabled'] as bool? ?? false,
  imageUrl: json['imageUrl'] as String? ?? '',
  opacity: (json['opacity'] as num?)?.toDouble() ?? 0.7,
  size:
      $enumDecodeNullable(_$ChatBackgroundSizeEnumMap, json['size']) ??
      ChatBackgroundSize.cover,
  position:
      $enumDecodeNullable(_$ChatBackgroundPositionEnumMap, json['position']) ??
      ChatBackgroundPosition.center,
  repeat:
      $enumDecodeNullable(_$ChatBackgroundRepeatEnumMap, json['repeat']) ??
      ChatBackgroundRepeat.noRepeat,
  showOverlay: json['showOverlay'] as bool? ?? true,
);

Map<String, dynamic> _$ChatBackgroundSettingsToJson(
  _ChatBackgroundSettings instance,
) => <String, dynamic>{
  'enabled': instance.enabled,
  'imageUrl': instance.imageUrl,
  'opacity': instance.opacity,
  'size': _$ChatBackgroundSizeEnumMap[instance.size]!,
  'position': _$ChatBackgroundPositionEnumMap[instance.position]!,
  'repeat': _$ChatBackgroundRepeatEnumMap[instance.repeat]!,
  'showOverlay': instance.showOverlay,
};

const _$ChatBackgroundSizeEnumMap = {
  ChatBackgroundSize.cover: 'cover',
  ChatBackgroundSize.contain: 'contain',
  ChatBackgroundSize.auto: 'auto',
};

const _$ChatBackgroundPositionEnumMap = {
  ChatBackgroundPosition.center: 'center',
  ChatBackgroundPosition.top: 'top',
  ChatBackgroundPosition.bottom: 'bottom',
  ChatBackgroundPosition.left: 'left',
  ChatBackgroundPosition.right: 'right',
};

const _$ChatBackgroundRepeatEnumMap = {
  ChatBackgroundRepeat.noRepeat: 'noRepeat',
  ChatBackgroundRepeat.repeat: 'repeat',
  ChatBackgroundRepeat.repeatX: 'repeatX',
  ChatBackgroundRepeat.repeatY: 'repeatY',
};

_ChatInterfaceSettings _$ChatInterfaceSettingsFromJson(
  Map<String, dynamic> json,
) => _ChatInterfaceSettings(
  multiModelDisplayStyle:
      $enumDecodeNullable(
        _$MultiModelDisplayStyleEnumMap,
        json['multiModelDisplayStyle'],
      ) ??
      MultiModelDisplayStyle.horizontal,
  showToolDetails: json['showToolDetails'] as bool? ?? true,
  showCitationDetails: json['showCitationDetails'] as bool? ?? true,
  showSystemPromptBubble: json['showSystemPromptBubble'] as bool? ?? true,
  background: json['background'] == null
      ? const ChatBackgroundSettings()
      : ChatBackgroundSettings.fromJson(
          json['background'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$ChatInterfaceSettingsToJson(
  _ChatInterfaceSettings instance,
) => <String, dynamic>{
  'multiModelDisplayStyle':
      _$MultiModelDisplayStyleEnumMap[instance.multiModelDisplayStyle]!,
  'showToolDetails': instance.showToolDetails,
  'showCitationDetails': instance.showCitationDetails,
  'showSystemPromptBubble': instance.showSystemPromptBubble,
  'background': instance.background.toJson(),
};

const _$MultiModelDisplayStyleEnumMap = {
  MultiModelDisplayStyle.horizontal: 'horizontal',
  MultiModelDisplayStyle.vertical: 'vertical',
  MultiModelDisplayStyle.single: 'single',
};
