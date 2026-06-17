// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thinking_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ThinkingSettings _$ThinkingSettingsFromJson(Map<String, dynamic> json) =>
    _ThinkingSettings(
      displayStyle:
          $enumDecodeNullable(
            _$ThinkingDisplayStyleEnumMap,
            json['displayStyle'],
          ) ??
          ThinkingDisplayStyle.compact,
      thoughtAutoCollapse: json['thoughtAutoCollapse'] as bool? ?? true,
      thinkingToolInline: json['thinkingToolInline'] as bool? ?? true,
    );

Map<String, dynamic> _$ThinkingSettingsToJson(_ThinkingSettings instance) =>
    <String, dynamic>{
      'displayStyle': _$ThinkingDisplayStyleEnumMap[instance.displayStyle]!,
      'thoughtAutoCollapse': instance.thoughtAutoCollapse,
      'thinkingToolInline': instance.thinkingToolInline,
    };

const _$ThinkingDisplayStyleEnumMap = {
  ThinkingDisplayStyle.compact: 'compact',
  ThinkingDisplayStyle.full: 'full',
  ThinkingDisplayStyle.minimal: 'minimal',
  ThinkingDisplayStyle.bubble: 'bubble',
  ThinkingDisplayStyle.card: 'card',
  ThinkingDisplayStyle.hidden: 'hidden',
};
