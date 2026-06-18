import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_tool_call.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'llm_message.freezed.dart';

/// A provider-neutral chat message: an author [role] and plain-text [content].
///
/// Most turns are plain text; the two optional fields exist only to round-trip
/// MCP 函数调用 mode so the model sees its own call and the matching result:
/// - [toolCalls] on an `assistant` turn replays the structured calls the model
///   just made (adapters emit OpenAI `tool_calls` / Anthropic `tool_use` /
///   Gemini `functionCall` from it).
/// - [toolCallId] (+ [toolName]) marks a tool-result turn; adapters serialise
///   it as the provider's result message (OpenAI `role:'tool'`, Anthropic
///   `tool_result` block, Gemini `functionResponse`) instead of a chat message.
@freezed
abstract class LlmMessage with _$LlmMessage {
  const factory LlmMessage({
    required MessageRole role,
    required String content,
    List<LlmToolCall>? toolCalls,
    String? toolCallId,
    String? toolName,
  }) = _LlmMessage;
}
