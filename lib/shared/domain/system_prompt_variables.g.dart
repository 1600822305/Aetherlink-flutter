// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_prompt_variables.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SystemPromptVariables _$SystemPromptVariablesFromJson(
  Map<String, dynamic> json,
) => _SystemPromptVariables(
  enableTimeVariable: json['enableTimeVariable'] as bool? ?? false,
  enableLocationVariable: json['enableLocationVariable'] as bool? ?? false,
  customLocation: json['customLocation'] as String? ?? '',
  enableOSVariable: json['enableOSVariable'] as bool? ?? false,
);

Map<String, dynamic> _$SystemPromptVariablesToJson(
  _SystemPromptVariables instance,
) => <String, dynamic>{
  'enableTimeVariable': instance.enableTimeVariable,
  'enableLocationVariable': instance.enableLocationVariable,
  'customLocation': instance.customLocation,
  'enableOSVariable': instance.enableOSVariable,
};
