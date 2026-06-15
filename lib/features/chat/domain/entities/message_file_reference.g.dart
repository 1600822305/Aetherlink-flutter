// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_file_reference.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MessageFileReference _$MessageFileReferenceFromJson(
  Map<String, dynamic> json,
) => _MessageFileReference(
  id: json['id'] as String,
  name: json['name'] as String,
  originName: json['origin_name'] as String,
  size: (json['size'] as num).toInt(),
  mimeType: json['mimeType'] as String,
  base64Data: json['base64Data'] as String?,
  type: json['type'] as String?,
);

Map<String, dynamic> _$MessageFileReferenceToJson(
  _MessageFileReference instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'origin_name': instance.originName,
  'size': instance.size,
  'mimeType': instance.mimeType,
  'base64Data': ?instance.base64Data,
  'type': ?instance.type,
};
