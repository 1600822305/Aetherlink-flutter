import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'llm_message.freezed.dart';

/// A provider-neutral chat message: an author [role] and plain-text [content].
///
/// M2 streams text only, so block-structured content is intentionally out of
/// scope — adapters translate this into each provider's message shape.
@freezed
abstract class LlmMessage with _$LlmMessage {
  const factory LlmMessage({
    required MessageRole role,
    required String content,
  }) = _LlmMessage;
}
