import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_cancel_token.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';

/// The single contract the app uses to talk to any LLM provider.
///
/// Realised in `data` by one adapter per wire protocol (OpenAI-compatible /
/// Anthropic / Gemini); callers depend only on this port and never branch on
/// provider (see ADR-0006). Pure Dart — no dio / IO here, so it stays on the
/// clean side of the domain boundary.
abstract interface class LlmGateway {
  /// Streams a chat completion as normalised [LlmStreamChunk]s. The stream ends
  /// with an [LlmDone] event; transport failures surface as a stream error.
  ///
  /// Pass [cancelToken] to abort the in-flight request: cancelling it tears down
  /// the underlying HTTP connection, which surfaces as a stream error the caller
  /// can treat as a user-initiated stop.
  Stream<LlmStreamChunk> streamChat(
    LlmChatRequest request, {
    LlmCancelToken? cancelToken,
  });
}
