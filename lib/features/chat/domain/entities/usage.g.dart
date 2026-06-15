// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'usage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Usage _$UsageFromJson(Map<String, dynamic> json) => _Usage(
  promptTokens: (json['promptTokens'] as num).toInt(),
  completionTokens: (json['completionTokens'] as num).toInt(),
  totalTokens: (json['totalTokens'] as num).toInt(),
);

Map<String, dynamic> _$UsageToJson(_Usage instance) => <String, dynamic>{
  'promptTokens': instance.promptTokens,
  'completionTokens': instance.completionTokens,
  'totalTokens': instance.totalTokens,
};
