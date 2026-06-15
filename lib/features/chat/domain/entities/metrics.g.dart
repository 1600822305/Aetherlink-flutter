// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'metrics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Metrics _$MetricsFromJson(Map<String, dynamic> json) => _Metrics(
  latency: (json['latency'] as num).toInt(),
  firstTokenLatency: (json['firstTokenLatency'] as num?)?.toInt(),
);

Map<String, dynamic> _$MetricsToJson(_Metrics instance) => <String, dynamic>{
  'latency': instance.latency,
  'firstTokenLatency': ?instance.firstTokenLatency,
};
