// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assistant_regex.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AssistantRegex _$AssistantRegexFromJson(Map<String, dynamic> json) =>
    _AssistantRegex(
      id: json['id'] as String,
      name: json['name'] as String,
      pattern: json['pattern'] as String,
      replacement: json['replacement'] as String,
      scopes:
          (json['scopes'] as List<dynamic>?)
              ?.map((e) => $enumDecode(_$AssistantRegexScopeEnumMap, e))
              .toList() ??
          const <AssistantRegexScope>[],
      visualOnly: json['visualOnly'] as bool,
      enabled: json['enabled'] as bool,
    );

Map<String, dynamic> _$AssistantRegexToJson(_AssistantRegex instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'pattern': instance.pattern,
      'replacement': instance.replacement,
      'scopes': instance.scopes
          .map((e) => _$AssistantRegexScopeEnumMap[e]!)
          .toList(),
      'visualOnly': instance.visualOnly,
      'enabled': instance.enabled,
    };

const _$AssistantRegexScopeEnumMap = {
  AssistantRegexScope.user: 'user',
  AssistantRegexScope.assistant: 'assistant',
};
