// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Group _$GroupFromJson(Map<String, dynamic> json) => _Group(
  id: json['id'] as String,
  name: json['name'] as String,
  type: $enumDecode(_$GroupTypeEnumMap, json['type']),
  assistantId: json['assistantId'] as String?,
  items:
      (json['items'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  order: (json['order'] as num?)?.toInt() ?? 0,
  expanded: json['expanded'] as bool? ?? true,
);

Map<String, dynamic> _$GroupToJson(_Group instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$GroupTypeEnumMap[instance.type]!,
  'assistantId': ?instance.assistantId,
  'items': instance.items,
  'order': instance.order,
  'expanded': instance.expanded,
};

const _$GroupTypeEnumMap = {
  GroupType.assistant: 'assistant',
  GroupType.topic: 'topic',
};
