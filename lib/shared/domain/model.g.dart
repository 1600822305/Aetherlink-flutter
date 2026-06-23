// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Model _$ModelFromJson(Map<String, dynamic> json) => _Model(
  id: json['id'] as String,
  name: json['name'] as String,
  provider: json['provider'] as String,
  description: json['description'] as String?,
  providerType: json['providerType'] as String?,
  apiKey: json['apiKey'] as String?,
  baseUrl: json['baseUrl'] as String?,
  maxTokens: (json['maxTokens'] as num?)?.toInt(),
  temperature: (json['temperature'] as num?)?.toDouble(),
  enabled: json['enabled'] as bool?,
  isDefault: json['isDefault'] as bool?,
  iconUrl: json['iconUrl'] as String?,
  presetModelId: json['presetModelId'] as String?,
  group: json['group'] as String?,
  capabilities: json['capabilities'] == null
      ? null
      : ModelCapabilities.fromJson(
          json['capabilities'] as Map<String, dynamic>,
        ),
  multimodal: json['multimodal'] as bool?,
  imageGeneration: json['imageGeneration'] as bool?,
  videoGeneration: json['videoGeneration'] as bool?,
  modelTypes: (json['modelTypes'] as List<dynamic>?)
      ?.map((e) => $enumDecode(_$ModelTypeEnumMap, e))
      .toList(),
  apiVersion: json['apiVersion'] as String?,
  extraHeaders: (json['extraHeaders'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  extraBody: json['extraBody'] as Map<String, dynamic>?,
  providerExtraHeaders: (json['providerExtraHeaders'] as Map<String, dynamic>?)
      ?.map((k, e) => MapEntry(k, e as String)),
  providerExtraBody: json['providerExtraBody'] as Map<String, dynamic>?,
  parameterScope: json['parameterScope'] as String?,
);

Map<String, dynamic> _$ModelToJson(_Model instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'provider': instance.provider,
  'description': ?instance.description,
  'providerType': ?instance.providerType,
  'apiKey': ?instance.apiKey,
  'baseUrl': ?instance.baseUrl,
  'maxTokens': ?instance.maxTokens,
  'temperature': ?instance.temperature,
  'enabled': ?instance.enabled,
  'isDefault': ?instance.isDefault,
  'iconUrl': ?instance.iconUrl,
  'presetModelId': ?instance.presetModelId,
  'group': ?instance.group,
  'capabilities': ?instance.capabilities?.toJson(),
  'multimodal': ?instance.multimodal,
  'imageGeneration': ?instance.imageGeneration,
  'videoGeneration': ?instance.videoGeneration,
  'modelTypes': ?instance.modelTypes
      ?.map((e) => _$ModelTypeEnumMap[e]!)
      .toList(),
  'apiVersion': ?instance.apiVersion,
  'extraHeaders': ?instance.extraHeaders,
  'extraBody': ?instance.extraBody,
  'providerExtraHeaders': ?instance.providerExtraHeaders,
  'providerExtraBody': ?instance.providerExtraBody,
  'parameterScope': ?instance.parameterScope,
};

const _$ModelTypeEnumMap = {
  ModelType.chat: 'chat',
  ModelType.vision: 'vision',
  ModelType.audio: 'audio',
  ModelType.embedding: 'embedding',
  ModelType.tool: 'tool',
  ModelType.reasoning: 'reasoning',
  ModelType.imageGen: 'image_gen',
  ModelType.videoGen: 'video_gen',
  ModelType.functionCalling: 'function_calling',
  ModelType.webSearch: 'web_search',
  ModelType.rerank: 'rerank',
  ModelType.codeGen: 'code_gen',
  ModelType.translation: 'translation',
  ModelType.transcription: 'transcription',
};
