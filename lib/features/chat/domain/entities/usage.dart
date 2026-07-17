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

    /// Prompt tokens served from the provider's prompt cache
    /// (Anthropic `cache_read_input_tokens`, OpenAI
    /// `prompt_tokens_details.cached_tokens`, DeepSeek
    /// `prompt_cache_hit_tokens`).
    int? cachedTokens,

    /// Prompt tokens written to the cache this turn (Anthropic
    /// `cache_creation_input_tokens`).
    int? cacheCreationTokens,
  }) = _Usage;

  factory Usage.fromJson(Map<String, dynamic> json) => _$UsageFromJson(json);
}
