import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_content_image.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_tool_call.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'llm_message.freezed.dart';

/// A provider-neutral chat message: an author [role] and plain-text [content].
///
/// Most turns are plain text; the optional fields cover two extras:
/// - [images] carries attached image parts on a user turn for multimodal
///   (vision) requests; each adapter serialises them in its provider's shape.
/// - [toolCalls] / [toolCallId] (+ [toolName]) round-trip MCP 函数调用 mode so the
///   model sees its own call and the matching result: [toolCalls] on an
///   `assistant` turn replays the structured calls (adapters emit OpenAI
///   `tool_calls` / Anthropic `tool_use` / Gemini `functionCall`), and
///   [toolCallId] marks a tool-result turn (OpenAI `role:'tool'`, Anthropic
///   `tool_result` block, Gemini `functionResponse`).
@freezed
abstract class LlmMessage with _$LlmMessage {
  const factory LlmMessage({
    required MessageRole role,
    required String content,
    List<LlmContentImage>? images,
    List<LlmToolCall>? toolCalls,
    String? toolCallId,
    String? toolName,
  }) = _LlmMessage;
}
