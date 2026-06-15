import 'package:aetherlink_flutter/features/chat/domain/entities/usage.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'llm_stream_chunk.freezed.dart';

/// One event from a streaming chat completion, normalised across providers.
///
/// Adapters map their own wire events onto this union; downstream layers turn
/// [LlmTextDelta] into a `main_text` block and [LlmReasoningDelta] into a
/// `thinking` block. Modelled `sealed` so consumers handle every case.
@freezed
sealed class LlmStreamChunk with _$LlmStreamChunk {
  /// Incremental assistant answer text (→ `main_text`).
  const factory LlmStreamChunk.textDelta(String text) = LlmTextDelta;

  /// Incremental reasoning / thinking text (→ `thinking`).
  const factory LlmStreamChunk.reasoningDelta(String text) = LlmReasoningDelta;

  /// Terminal event carrying optional token [usage] and provider
  /// [finishReason].
  const factory LlmStreamChunk.done({Usage? usage, String? finishReason}) =
      LlmDone;
}
