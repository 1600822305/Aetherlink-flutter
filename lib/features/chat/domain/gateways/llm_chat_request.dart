import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'llm_chat_request.freezed.dart';

/// A provider-neutral chat-completion request. The app only ever builds this
/// one shape; each protocol adapter translates it into its own wire format.
///
/// [model] carries the endpoint config (baseUrl / apiKey / providerType /
/// extraHeaders / extraBody) the adapter needs. [extraHeaders] / [extraBody]
/// are per-call pass-throughs merged on top of the model's own extras.
@freezed
abstract class LlmChatRequest with _$LlmChatRequest {
  const factory LlmChatRequest({
    required Model model,
    required List<LlmMessage> messages,
    String? system,
    double? temperature,
    int? maxTokens,
    double? topP,
    @Default(true) bool stream,
    Map<String, String>? extraHeaders,
    Map<String, dynamic>? extraBody,
  }) = _LlmChatRequest;
}
