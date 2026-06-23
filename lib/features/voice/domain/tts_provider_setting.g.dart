// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_provider_setting.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TtsProviderSetting _$TtsProviderSettingFromJson(Map<String, dynamic> json) =>
    _TtsProviderSetting(
      id: json['id'] as String,
      kind: $enumDecode(_$TtsProviderKindEnumMap, json['kind']),
      name: json['name'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      apiKey: json['apiKey'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      model: json['model'] as String? ?? '',
      voice: json['voice'] as String? ?? '',
      groupId: json['groupId'] as String? ?? '',
      emotion: json['emotion'] as String? ?? '',
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      region: json['region'] as String? ?? '',
      voiceName: json['voiceName'] as String? ?? '',
      outputFormat: json['outputFormat'] as String? ?? '',
      appId: json['appId'] as String? ?? '',
      cluster: json['cluster'] as String? ?? '',
      apiVersion: json['apiVersion'] as String? ?? 'auto',
      resourceId: json['resourceId'] as String? ?? '',
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
      encoding: json['encoding'] as String? ?? 'mp3',
      instructions: json['instructions'] as String? ?? '',
    );

Map<String, dynamic> _$TtsProviderSettingToJson(_TtsProviderSetting instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': _$TtsProviderKindEnumMap[instance.kind]!,
      'name': instance.name,
      'enabled': instance.enabled,
      'apiKey': instance.apiKey,
      'baseUrl': instance.baseUrl,
      'model': instance.model,
      'voice': instance.voice,
      'groupId': instance.groupId,
      'emotion': instance.emotion,
      'speed': instance.speed,
      'region': instance.region,
      'voiceName': instance.voiceName,
      'outputFormat': instance.outputFormat,
      'appId': instance.appId,
      'cluster': instance.cluster,
      'apiVersion': instance.apiVersion,
      'resourceId': instance.resourceId,
      'volume': instance.volume,
      'pitch': instance.pitch,
      'encoding': instance.encoding,
      'instructions': instance.instructions,
    };

const _$TtsProviderKindEnumMap = {
  TtsProviderKind.system: 'system',
  TtsProviderKind.openai: 'openai',
  TtsProviderKind.gemini: 'gemini',
  TtsProviderKind.minimax: 'minimax',
  TtsProviderKind.siliconflow: 'siliconflow',
  TtsProviderKind.azure: 'azure',
  TtsProviderKind.elevenlabs: 'elevenlabs',
  TtsProviderKind.volcano: 'volcano',
};
