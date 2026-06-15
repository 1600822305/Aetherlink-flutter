// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Message _$MessageFromJson(Map<String, dynamic> json) => _Message(
  id: json['id'] as String,
  role: $enumDecode(_$MessageRoleEnumMap, json['role']),
  assistantId: json['assistantId'] as String,
  topicId: json['topicId'] as String,
  createdAt: const IsoDateTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: _$JsonConverterFromJson<String, DateTime>(
    json['updatedAt'],
    const IsoDateTimeConverter().fromJson,
  ),
  status: $enumDecode(_$MessageStatusEnumMap, json['status']),
  modelId: json['modelId'] as String?,
  model: json['model'] == null
      ? null
      : Model.fromJson(json['model'] as Map<String, dynamic>),
  type: json['type'] as String?,
  isPreset: json['isPreset'] as bool?,
  useful: json['useful'] as bool?,
  askId: json['askId'] as String?,
  mentions: (json['mentions'] as List<dynamic>?)
      ?.map((e) => Model.fromJson(e as Map<String, dynamic>))
      .toList(),
  usage: json['usage'] == null
      ? null
      : Usage.fromJson(json['usage'] as Map<String, dynamic>),
  metrics: json['metrics'] == null
      ? null
      : Metrics.fromJson(json['metrics'] as Map<String, dynamic>),
  blocks:
      (json['blocks'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  versions: (json['versions'] as List<dynamic>?)
      ?.map((e) => MessageVersion.fromJson(e as Map<String, dynamic>))
      .toList(),
  currentVersionId: json['currentVersionId'] as String?,
  metadata: json['metadata'] as Map<String, dynamic>?,
  multiModelMessageStyle: $enumDecodeNullable(
    _$MultiModelMessageStyleEnumMap,
    json['multiModelMessageStyle'],
  ),
  foldSelected: json['foldSelected'] as bool?,
);

Map<String, dynamic> _$MessageToJson(_Message instance) => <String, dynamic>{
  'id': instance.id,
  'role': _$MessageRoleEnumMap[instance.role]!,
  'assistantId': instance.assistantId,
  'topicId': instance.topicId,
  'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
  'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
    instance.updatedAt,
    const IsoDateTimeConverter().toJson,
  ),
  'status': _$MessageStatusEnumMap[instance.status]!,
  'modelId': ?instance.modelId,
  'model': ?instance.model?.toJson(),
  'type': ?instance.type,
  'isPreset': ?instance.isPreset,
  'useful': ?instance.useful,
  'askId': ?instance.askId,
  'mentions': ?instance.mentions?.map((e) => e.toJson()).toList(),
  'usage': ?instance.usage?.toJson(),
  'metrics': ?instance.metrics?.toJson(),
  'blocks': instance.blocks,
  'versions': ?instance.versions?.map((e) => e.toJson()).toList(),
  'currentVersionId': ?instance.currentVersionId,
  'metadata': ?instance.metadata,
  'multiModelMessageStyle':
      ?_$MultiModelMessageStyleEnumMap[instance.multiModelMessageStyle],
  'foldSelected': ?instance.foldSelected,
};

const _$MessageRoleEnumMap = {
  MessageRole.user: 'user',
  MessageRole.assistant: 'assistant',
  MessageRole.system: 'system',
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

const _$MessageStatusEnumMap = {
  MessageStatus.sending: 'sending',
  MessageStatus.pending: 'pending',
  MessageStatus.processing: 'processing',
  MessageStatus.searching: 'searching',
  MessageStatus.streaming: 'streaming',
  MessageStatus.success: 'success',
  MessageStatus.error: 'error',
  MessageStatus.paused: 'paused',
};

const _$MultiModelMessageStyleEnumMap = {
  MultiModelMessageStyle.horizontal: 'horizontal',
  MultiModelMessageStyle.vertical: 'vertical',
  MultiModelMessageStyle.fold: 'fold',
  MultiModelMessageStyle.grid: 'grid',
};

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
