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
      emotion: json['emotion'] as String? ?? '',
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      region: json['region'] as String? ?? '',
      voiceName: json['voiceName'] as String? ?? '',
      outputFormat: json['outputFormat'] as String? ?? '',
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
      'emotion': instance.emotion,
      'speed': instance.speed,
      'region': instance.region,
      'voiceName': instance.voiceName,
      'outputFormat': instance.outputFormat,
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
