import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';

/// Selection mode for multi-message operations.
enum MessageSelectionMode { share, delete }

/// State for message multi-select mode.
class MessageSelectionState {
  const MessageSelectionState({
    this.isSelecting = false,
    this.mode = MessageSelectionMode.share,
    this.selectedIds = const <String>{},
    this.showThinkingAndTools = false,
    this.expandThinking = false,
  });

  final bool isSelecting;
  final MessageSelectionMode mode;
  final Set<String> selectedIds;
  final bool showThinkingAndTools;
  final bool expandThinking;

  MessageSelectionState copyWith({
    bool? isSelecting,
    MessageSelectionMode? mode,
    Set<String>? selectedIds,
    bool? showThinkingAndTools,
    bool? expandThinking,
  }) {
    return MessageSelectionState(
      isSelecting: isSelecting ?? this.isSelecting,
      mode: mode ?? this.mode,
      selectedIds: selectedIds ?? this.selectedIds,
      showThinkingAndTools: showThinkingAndTools ?? this.showThinkingAndTools,
      expandThinking: expandThinking ?? this.expandThinking,
    );
  }
}

/// Manages message multi-select state for export/delete operations.
///
/// Port of Kelivo's `startMessageSelection` / selection mode. Enters selection
/// mode with an anchor message (auto-selecting the user+assistant pair), then
/// the user can toggle individual messages and confirm to open the export sheet.
class MessageSelectionController extends Notifier<MessageSelectionState> {
  @override
  MessageSelectionState build() => const MessageSelectionState();

  /// Enters selection mode from a message at [anchorIndex] in [messages].
  ///
  /// Like Kelivo, auto-selects the user+assistant pair around the anchor:
  /// - If anchor is assistant → also select the preceding user message
  /// - If anchor is user → also select the following assistant message
  void enterSelectionMode({
    required int anchorIndex,
    required List<ChatMessageView> messages,
    MessageSelectionMode mode = MessageSelectionMode.share,
  }) {
    if (anchorIndex < 0 || anchorIndex >= messages.length) return;

    final selected = <String>{};
    final anchor = messages[anchorIndex];

    if (anchor.role == MessageRole.assistant) {
      selected.add(anchor.id);
      // Find preceding user message.
      for (int i = anchorIndex - 1; i >= 0; i--) {
        if (messages[i].role == MessageRole.user) {
          selected.add(messages[i].id);
          break;
        }
      }
    } else if (anchor.role == MessageRole.user) {
      selected.add(anchor.id);
      // Find following assistant message.
      for (int i = anchorIndex + 1; i < messages.length; i++) {
        if (messages[i].role == MessageRole.assistant) {
          selected.add(messages[i].id);
          break;
        }
      }
    }

    if (selected.isEmpty) {
      selected.add(anchor.id);
    }

    state = MessageSelectionState(
      isSelecting: true,
      mode: mode,
      selectedIds: selected,
    );
  }

  void exitSelectionMode() {
    state = const MessageSelectionState();
  }

  void toggleMessage(String messageId) {
    final ids = Set<String>.of(state.selectedIds);
    if (ids.contains(messageId)) {
      ids.remove(messageId);
    } else {
      ids.add(messageId);
    }
    state = state.copyWith(selectedIds: ids);
  }

  void selectAll(List<ChatMessageView> messages) {
    final ids = <String>{
      for (final msg in messages)
        if (msg.role == MessageRole.user || msg.role == MessageRole.assistant)
          msg.id,
    };
    state = state.copyWith(selectedIds: ids);
  }

  void deselectAll() {
    state = state.copyWith(selectedIds: const <String>{});
  }

  void toggleSelectAll(List<ChatMessageView> messages) {
    final allSelectableIds = <String>{
      for (final msg in messages)
        if (msg.role == MessageRole.user || msg.role == MessageRole.assistant)
          msg.id,
    };
    if (state.selectedIds.length >= allSelectableIds.length) {
      deselectAll();
    } else {
      selectAll(messages);
    }
  }

  void toggleShowThinkingAndTools() {
    final newValue = !state.showThinkingAndTools;
    state = state.copyWith(
      showThinkingAndTools: newValue,
      expandThinking: newValue ? state.expandThinking : false,
    );
  }

  void toggleExpandThinking() {
    if (!state.showThinkingAndTools) return;
    state = state.copyWith(expandThinking: !state.expandThinking);
  }
}

final messageSelectionProvider =
    NotifierProvider<MessageSelectionController, MessageSelectionState>(
      MessageSelectionController.new,
    );
