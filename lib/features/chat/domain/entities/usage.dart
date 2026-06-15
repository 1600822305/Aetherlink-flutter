import 'package:freezed_annotation/freezed_annotation.dart';

part 'usage.freezed.dart';
part 'usage.g.dart';

/// Token usage for a message. Mirrors `Usage`
/// (`src/shared/types/newMessage.ts`).
@freezed
abstract class Usage with _$Usage {
  const factory Usage({
    required int promptTokens,
    required int completionTokens,
    required int totalTokens,
  }) = _Usage;

  factory Usage.fromJson(Map<String, dynamic> json) => _$UsageFromJson(json);
}
