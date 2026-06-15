// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_parameter.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CustomParameter _$CustomParameterFromJson(Map<String, dynamic> json) =>
    _CustomParameter(
      name: json['name'] as String,
      value: json['value'],
      type: $enumDecode(_$CustomParameterTypeEnumMap, json['type']),
    );

Map<String, dynamic> _$CustomParameterToJson(_CustomParameter instance) =>
    <String, dynamic>{
      'name': instance.name,
      'value': ?instance.value,
      'type': _$CustomParameterTypeEnumMap[instance.type]!,
    };

const _$CustomParameterTypeEnumMap = {
  CustomParameterType.string: 'string',
  CustomParameterType.number: 'number',
  CustomParameterType.boolean: 'boolean',
  CustomParameterType.json: 'json',
};
