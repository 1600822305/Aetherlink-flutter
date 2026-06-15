// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assistant_chat_background.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AssistantChatBackground _$AssistantChatBackgroundFromJson(
  Map<String, dynamic> json,
) => _AssistantChatBackground(
  enabled: json['enabled'] as bool,
  imageUrl: json['imageUrl'] as String,
  opacity: (json['opacity'] as num?)?.toDouble(),
  size: json['size'] as String?,
  position: json['position'] as String?,
  repeat: json['repeat'] as String?,
  showOverlay: json['showOverlay'] as bool?,
);

Map<String, dynamic> _$AssistantChatBackgroundToJson(
  _AssistantChatBackground instance,
) => <String, dynamic>{
  'enabled': instance.enabled,
  'imageUrl': instance.imageUrl,
  'opacity': ?instance.opacity,
  'size': ?instance.size,
  'position': ?instance.position,
  'repeat': ?instance.repeat,
  'showOverlay': ?instance.showOverlay,
};
