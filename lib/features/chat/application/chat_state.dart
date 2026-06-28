import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_version.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/metrics.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/usage.dart';

part 'chat_state.freezed.dart';

/// A single rendered message in the chat view.
///
/// Carries the ordered [blocks] so the bubble can dispatch per-block-type
/// rendering (Markdown, thinking, code, image, error, …) like the original
/// `MessageBlockRenderer`. [text] / [thinking] are kept as flattened channels:
/// [text] still feeds the outgoing request builder and both remain a fallback.
/// [status] drives the streaming indicator and [errorText] carries a
/// transport/stream failure to show in place of the bubble.
///
/// [versions] / [currentVersionId] mirror the message's saved version history
/// (`MessageVersion`) so the toolbar can show the 版本历史 button and popover;
/// [currentVersionId] is `null` while the newest (live) content is displayed.
@freezed
abstract class ChatMessageView with _$ChatMessageView {
  const factory ChatMessageView({
    required String id,
    required MessageRole role,
    required MessageStatus status,
    @Default(<MessageBlock>[]) List<MessageBlock> blocks,
    @Default('') String text,
    @Default('') String thinking,
    String? errorText,
    DateTime? createdAt,
    String? modelName,
    String? providerName,
    @Default(<MessageVersion>[]) List<MessageVersion> versions,
    String? currentVersionId,
    Usage? usage,
    Metrics? metrics,
  }) = _ChatMessageView;
}

/// The chat feature's application state: the ordered conversation [messages]
/// (oldest first) plus whether a streaming reply is currently in flight.
@freezed
abstract class ChatState with _$ChatState {
  const factory ChatState({
    @Default(<ChatMessageView>[]) List<ChatMessageView> messages,
    @Default(false) bool isStreaming,

    /// In-memory follow-up question suggestions for the latest assistant reply
    /// (建议模型). Generated after a reply finishes and cleared when the next
    /// message is sent; never persisted.
    @Default(<String>[]) List<String> suggestions,
  }) = _ChatState;

  const ChatState._();

  /// Empty conversation, nothing streaming.
  factory ChatState.initial() => const ChatState();
}
