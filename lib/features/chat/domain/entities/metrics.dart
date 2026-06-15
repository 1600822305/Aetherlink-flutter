import 'package:freezed_annotation/freezed_annotation.dart';

part 'metrics.freezed.dart';
part 'metrics.g.dart';

/// Latency metrics for a message response. Mirrors `Metrics`
/// (`src/shared/types/newMessage.ts`). Values are milliseconds.
@freezed
abstract class Metrics with _$Metrics {
  const factory Metrics({required int latency, int? firstTokenLatency}) =
      _Metrics;

  factory Metrics.fromJson(Map<String, dynamic> json) =>
      _$MetricsFromJson(json);
}
