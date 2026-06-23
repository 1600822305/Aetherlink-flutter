// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VoiceSettings _$VoiceSettingsFromJson(
  Map<String, dynamic> json,
) => _VoiceSettings(
  enableTts: json['enableTts'] as bool? ?? true,
  activeTtsProviderId: json['activeTtsProviderId'] as String? ?? 'system',
  ttsProviders:
      (json['ttsProviders'] as List<dynamic>?)
          ?.map((e) => TtsProviderSetting.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <TtsProviderSetting>[],
  enableAsr: json['enableAsr'] as bool? ?? true,
  activeAsrProviderId: json['activeAsrProviderId'] as String? ?? 'system',
  asrProviders:
      (json['asrProviders'] as List<dynamic>?)
          ?.map((e) => AsrProviderSetting.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <AsrProviderSetting>[],
  defaultSpeed: (json['defaultSpeed'] as num?)?.toDouble() ?? 1.0,
);

Map<String, dynamic> _$VoiceSettingsToJson(_VoiceSettings instance) =>
    <String, dynamic>{
      'enableTts': instance.enableTts,
      'activeTtsProviderId': instance.activeTtsProviderId,
      'ttsProviders': instance.ttsProviders.map((e) => e.toJson()).toList(),
      'enableAsr': instance.enableAsr,
      'activeAsrProviderId': instance.activeAsrProviderId,
      'asrProviders': instance.asrProviders.map((e) => e.toJson()).toList(),
      'defaultSpeed': instance.defaultSpeed,
    };
