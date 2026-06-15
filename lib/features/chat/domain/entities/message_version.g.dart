// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_version.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MessageVersion _$MessageVersionFromJson(
  Map<String, dynamic> json,
) => _MessageVersion(
  id: json['id'] as String,
  messageId: json['messageId'] as String,
  blocks:
      (json['blocks'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  createdAt: const IsoDateTimeConverter().fromJson(json['createdAt'] as String),
  modelId: json['modelId'] as String?,
  model: json['model'] == null
      ? null
      : Model.fromJson(json['model'] as Map<String, dynamic>),
  isActive: json['isActive'] as bool?,
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$MessageVersionToJson(_MessageVersion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'messageId': instance.messageId,
      'blocks': instance.blocks,
      'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
      'modelId': ?instance.modelId,
      'model': ?instance.model?.toJson(),
      'isActive': ?instance.isActive,
      'metadata': ?instance.metadata,
    };
