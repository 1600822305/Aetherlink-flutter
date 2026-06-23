import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'llm_chat_request.freezed.dart';

/// A provider-neutral chat-completion request. The app only ever builds this
/// one shape; each protocol adapter translates it into its own wire format.
///
/// [model] carries the endpoint config (baseUrl / apiKey / providerType /
/// extraHeaders / extraBody) the adapter needs. [extraHeaders] / [extraBody]
/// are per-call pass-throughs merged on top of the model's own extras.
///
/// [tools] is set only in MCP 函数调用 mode: adapters translate it into their
/// native function-calling shape (`tools` / `functionDeclarations`) so the
/// model can emit structured `tool_calls`. In 提示词注入 mode it stays null and
/// the tools ride in [system] as an XML protocol instead.
///
/// [useResponsesAPI] flips the OpenAI-compatible adapter from `/chat/completions`
/// to the `/responses` endpoint (different request/stream schema). It is sourced
/// from `ModelProvider.useResponsesAPI` and ignored by non-OpenAI adapters.
@freezed
abstract class LlmChatRequest with _$LlmChatRequest {
  const factory LlmChatRequest({
    required Model model,
    required List<LlmMessage> messages,
    String? system,
    double? temperature,
    int? maxTokens,
    double? topP,
    int? topK,
    double? frequencyPenalty,
    double? presencePenalty,
    int? seed,
    List<String>? stopSequences,
    String? responseFormat,
    bool? parallelToolCalls,
    bool? logprobs,
    String? user,
    String? reasoningEffort,
    int? thinkingBudget,
    bool? includeThoughts,
    bool? cacheControl,
    String? structuredOutputMode,
    bool? webSearchEnabled,
    bool? codeExecutionEnabled,
    bool? useSearchGrounding,
    String? safetyLevel,
    Map<String, dynamic>? customParameters,
    @Default(true) bool stream,
    @Default(false) bool useResponsesAPI,
    List<McpToolDefinition>? tools,
    Map<String, String>? extraHeaders,
    Map<String, dynamic>? extraBody,
  }) = _LlmChatRequest;
}
