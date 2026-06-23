// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asr_provider_setting.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AsrProviderSetting _$AsrProviderSettingFromJson(Map<String, dynamic> json) =>
    _AsrProviderSetting(
      id: json['id'] as String,
      kind: $enumDecode(_$AsrProviderKindEnumMap, json['kind']),
      name: json['name'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      apiKey: json['apiKey'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      model: json['model'] as String? ?? '',
      language: json['language'] as String? ?? '',
      websocketUrl: json['websocketUrl'] as String? ?? '',
      responseFormat: json['responseFormat'] as String? ?? '',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      vadThreshold: (json['vadThreshold'] as num?)?.toDouble() ?? 0.5,
      silenceDurationMs: (json['silenceDurationMs'] as num?)?.toInt() ?? 500,
    );

Map<String, dynamic> _$AsrProviderSettingToJson(_AsrProviderSetting instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': _$AsrProviderKindEnumMap[instance.kind]!,
      'name': instance.name,
      'enabled': instance.enabled,
      'apiKey': instance.apiKey,
      'baseUrl': instance.baseUrl,
      'model': instance.model,
      'language': instance.language,
      'websocketUrl': instance.websocketUrl,
      'responseFormat': instance.responseFormat,
      'temperature': instance.temperature,
      'vadThreshold': instance.vadThreshold,
      'silenceDurationMs': instance.silenceDurationMs,
    };

const _$AsrProviderKindEnumMap = {
  AsrProviderKind.system: 'system',
  AsrProviderKind.openaiRealtime: 'openai_realtime',
  AsrProviderKind.whisper: 'whisper',
};
