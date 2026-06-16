import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';

part 'chat_state.freezed.dart';

/// A single rendered message in the chat view.
///
/// Flattens a [Message] and its blocks into the two text channels the page
/// renders this milestone: [text] (the `main_text` block) and [thinking] (the
/// `thinking` block). [status] drives the streaming indicator and [errorText]
/// carries a transport/stream failure to show in place of the bubble.
@freezed
abstract class ChatMessageView with _$ChatMessageView {
  const factory ChatMessageView({
    required String id,
    required MessageRole role,
    required MessageStatus status,
    @Default('') String text,
    @Default('') String thinking,
    String? errorText,
  }) = _ChatMessageView;
}

/// The chat feature's application state: the ordered conversation [messages]
/// (oldest first) plus whether a streaming reply is currently in flight.
@freezed
abstract class ChatState with _$ChatState {
  const factory ChatState({
    @Default(<ChatMessageView>[]) List<ChatMessageView> messages,
    @Default(false) bool isStreaming,
  }) = _ChatState;

  const ChatState._();

  /// Empty conversation, nothing streaming.
  factory ChatState.initial() => const ChatState();
}
