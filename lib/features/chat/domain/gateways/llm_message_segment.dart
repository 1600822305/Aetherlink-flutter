import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';

/// The [LlmMessage]s serialised from one rendered conversation view, kept
/// together so callers that splice extra turns into the history (世界书注入)
/// only ever insert between views — never between an assistant `toolCalls`
/// turn and its tool-result turns, or inside a 提示词注入 `<tool_use>` round,
/// which share a view. [role] is the source view's role.
class LlmMessageSegment {
  const LlmMessageSegment({required this.role, required this.messages});

  final MessageRole role;
  final List<LlmMessage> messages;
}
