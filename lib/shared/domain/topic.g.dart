// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'topic.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Topic _$TopicFromJson(Map<String, dynamic> json) => _Topic(
  id: json['id'] as String,
  assistantId: json['assistantId'] as String,
  name: json['name'] as String,
  createdAt: const IsoDateTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: const IsoDateTimeConverter().fromJson(json['updatedAt'] as String),
  isNameManuallyEdited: json['isNameManuallyEdited'] as bool? ?? false,
  messageIds:
      (json['messageIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  lastMessageTime: json['lastMessageTime'] as String?,
  lastMessagePreview: json['lastMessagePreview'] as String?,
  inputTemplate: json['inputTemplate'] as String?,
  messageCount: (json['messageCount'] as num?)?.toInt(),
  tokenCount: (json['tokenCount'] as num?)?.toInt(),
  isDefault: json['isDefault'] as bool?,
  pinned: json['pinned'] as bool? ?? false,
);

Map<String, dynamic> _$TopicToJson(_Topic instance) => <String, dynamic>{
  'id': instance.id,
  'assistantId': instance.assistantId,
  'name': instance.name,
  'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
  'updatedAt': const IsoDateTimeConverter().toJson(instance.updatedAt),
  'isNameManuallyEdited': instance.isNameManuallyEdited,
  'messageIds': instance.messageIds,
  'lastMessageTime': ?instance.lastMessageTime,
  'lastMessagePreview': ?instance.lastMessagePreview,
  'inputTemplate': ?instance.inputTemplate,
  'messageCount': ?instance.messageCount,
  'tokenCount': ?instance.tokenCount,
  'isDefault': ?instance.isDefault,
  'pinned': instance.pinned,
};
