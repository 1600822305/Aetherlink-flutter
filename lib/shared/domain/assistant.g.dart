// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assistant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Assistant _$AssistantFromJson(Map<String, dynamic> json) => _Assistant(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  avatar: json['avatar'] as String?,
  emoji: json['emoji'] as String?,
  tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
  engine: json['engine'] as String?,
  model: json['model'] as String?,
  temperature: (json['temperature'] as num?)?.toDouble(),
  maxTokens: (json['maxTokens'] as num?)?.toInt(),
  topP: (json['topP'] as num?)?.toDouble(),
  frequencyPenalty: (json['frequencyPenalty'] as num?)?.toDouble(),
  presencePenalty: (json['presencePenalty'] as num?)?.toDouble(),
  systemPrompt: json['systemPrompt'] as String?,
  prompt: json['prompt'] as String?,
  maxMessagesInContext: (json['maxMessagesInContext'] as num?)?.toInt(),
  isDefault: json['isDefault'] as bool?,
  isSystem: json['isSystem'] as bool?,
  archived: json['archived'] as bool?,
  createdAt: _$JsonConverterFromJson<String, DateTime>(
    json['createdAt'],
    const IsoDateTimeConverter().fromJson,
  ),
  updatedAt: _$JsonConverterFromJson<String, DateTime>(
    json['updatedAt'],
    const IsoDateTimeConverter().fromJson,
  ),
  lastUsedAt: _$JsonConverterFromJson<String, DateTime>(
    json['lastUsedAt'],
    const IsoDateTimeConverter().fromJson,
  ),
  topicIds:
      (json['topicIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  selectedSystemPromptId: json['selectedSystemPromptId'] as String?,
  mcpConfigId: json['mcpConfigId'] as String?,
  tools: (json['tools'] as List<dynamic>?)?.map((e) => e as String).toList(),
  toolChoice: json['tool_choice'] as String?,
  speechModel: json['speechModel'] as String?,
  speechVoice: json['speechVoice'] as String?,
  speechSpeed: (json['speechSpeed'] as num?)?.toDouble(),
  responseFormat: json['responseFormat'] as String?,
  isLocal: json['isLocal'] as bool?,
  localModelName: json['localModelName'] as String?,
  localModelPath: json['localModelPath'] as String?,
  localModelType: json['localModelType'] as String?,
  fileIds: (json['file_ids'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  type: json['type'] as String?,
  regularPhrases: (json['regularPhrases'] as List<dynamic>?)
      ?.map((e) => QuickPhrase.fromJson(e as Map<String, dynamic>))
      .toList(),
  webSearchProviderId: json['webSearchProviderId'] as String?,
  enableWebSearch: json['enableWebSearch'] as bool?,
  customParameters: (json['customParameters'] as List<dynamic>?)
      ?.map((e) => CustomParameter.fromJson(e as Map<String, dynamic>))
      .toList(),
  regexRules: (json['regexRules'] as List<dynamic>?)
      ?.map((e) => AssistantRegex.fromJson(e as Map<String, dynamic>))
      .toList(),
  chatBackground: json['chatBackground'] == null
      ? null
      : AssistantChatBackground.fromJson(
          json['chatBackground'] as Map<String, dynamic>,
        ),
  memoryEnabled: json['memoryEnabled'] as bool?,
  skillIds: (json['skillIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  activeSkillId: json['activeSkillId'] as String?,
);

Map<String, dynamic> _$AssistantToJson(
  _Assistant instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': ?instance.description,
  'avatar': ?instance.avatar,
  'emoji': ?instance.emoji,
  'tags': ?instance.tags,
  'engine': ?instance.engine,
  'model': ?instance.model,
  'temperature': ?instance.temperature,
  'maxTokens': ?instance.maxTokens,
  'topP': ?instance.topP,
  'frequencyPenalty': ?instance.frequencyPenalty,
  'presencePenalty': ?instance.presencePenalty,
  'systemPrompt': ?instance.systemPrompt,
  'prompt': ?instance.prompt,
  'maxMessagesInContext': ?instance.maxMessagesInContext,
  'isDefault': ?instance.isDefault,
  'isSystem': ?instance.isSystem,
  'archived': ?instance.archived,
  'createdAt': ?_$JsonConverterToJson<String, DateTime>(
    instance.createdAt,
    const IsoDateTimeConverter().toJson,
  ),
  'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
    instance.updatedAt,
    const IsoDateTimeConverter().toJson,
  ),
  'lastUsedAt': ?_$JsonConverterToJson<String, DateTime>(
    instance.lastUsedAt,
    const IsoDateTimeConverter().toJson,
  ),
  'topicIds': instance.topicIds,
  'selectedSystemPromptId': ?instance.selectedSystemPromptId,
  'mcpConfigId': ?instance.mcpConfigId,
  'tools': ?instance.tools,
  'tool_choice': ?instance.toolChoice,
  'speechModel': ?instance.speechModel,
  'speechVoice': ?instance.speechVoice,
  'speechSpeed': ?instance.speechSpeed,
  'responseFormat': ?instance.responseFormat,
  'isLocal': ?instance.isLocal,
  'localModelName': ?instance.localModelName,
  'localModelPath': ?instance.localModelPath,
  'localModelType': ?instance.localModelType,
  'file_ids': ?instance.fileIds,
  'type': ?instance.type,
  'regularPhrases': ?instance.regularPhrases?.map((e) => e.toJson()).toList(),
  'webSearchProviderId': ?instance.webSearchProviderId,
  'enableWebSearch': ?instance.enableWebSearch,
  'customParameters': ?instance.customParameters
      ?.map((e) => e.toJson())
      .toList(),
  'regexRules': ?instance.regexRules?.map((e) => e.toJson()).toList(),
  'chatBackground': ?instance.chatBackground?.toJson(),
  'memoryEnabled': ?instance.memoryEnabled,
  'skillIds': ?instance.skillIds,
  'activeSkillId': ?instance.activeSkillId,
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
