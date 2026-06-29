import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_version.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/multi_model_message_style.dart';
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
    /// The model / provider ids of this message's model, used by the 多模型对比
    /// group's model selector to render the per-model logo (the bubble itself
    /// shows the name). Null for user messages or models without an id.
    String? modelId,
    String? providerId,
    // 多模型对比分组：[askId] 指向被回答的用户消息，[siblingsGroupId]>0 表示该助手
    // 消息属于同一父下的多模型兄弟组。消息列表据此把连续的同组兄弟摞进对比控件。
    String? askId,
    @Default(0) int siblingsGroupId,
    /// The group's chosen comparison layout (折叠/水平/垂直/网格), persisted on
    /// each sibling message. The 对比 group widget reads the first member's value
    /// to initialise its layout toggle, falling back to the global setting.
    MultiModelMessageStyle? multiModelMessageStyle,
    /// Whether this is the chosen sibling of its multi-model group (the one the
    /// conversation continues from). Drives the 对比 group's selected highlight.
    @Default(false) bool foldSelected,
    /// When this message sits at a 叉路 (its parent has multiple regular branch
    /// children, e.g. from 从此处分叉 + 发送), the ids of all those branch siblings
    /// in display order — drives the `◀ k/n ▶` branch switcher. Length ≤ 1 means
    /// no fork. Computed in `build()`/`_load`, empty on live streaming views.
    @Default(<String>[]) List<String> branchSiblingIds,
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
