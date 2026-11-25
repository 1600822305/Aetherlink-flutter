import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/world_book_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/mcp_tools_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/send/llm_history_builder.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_turn.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';

/// A request's history with 世界书 chat-position entries woven in, plus the
/// [turn] whose system-position entries [system] applies. With nothing bound
/// or triggered, [messages] equals `buildLlmMessages` and [system] is the
/// identity.
class WorldBookRequest {
  const WorldBookRequest({required this.messages, required this.turn});

  final List<LlmMessage> messages;
  final WorldBookTurn turn;

  String? system(String? base) => applyWorldBookSystem(base, turn);
}

/// Builds request history for the send / regenerate / resend paths (世界书 P2).
/// Same getter-callback rationale as [LlmHistoryBuilder]: the controller's Ref
/// and repository change across provider rebuilds.
class WorldBookRequestBuilder {
  const WorldBookRequestBuilder(
    this._refOf, {
    required ChatRepository Function() repo,
    required String Function() assistantId,
    required LlmHistoryBuilder history,
  }) : _repoOf = repo,
       _assistantIdOf = assistantId,
       _history = history;

  final Ref Function() _refOf;
  final ChatRepository Function() _repoOf;
  final String Function() _assistantIdOf;
  final LlmHistoryBuilder _history;

  Future<WorldBookRequest> build(
    List<ChatMessageView> views, {
    required String? topicId,
    required Model chatModel,
    List<AssistantRegex>? regexRules,
    required McpMode toolMode,
  }) async {
    final segments = await _history.buildLlmMessageSegments(
      views,
      chatModel: chatModel,
      regexRules: regexRules,
      toolMode: toolMode,
    );
    final repo = _repoOf();
    final turn = await collectWorldBookTurn(
      _refOf(),
      assistant: await repo.getAssistant(_assistantIdOf()),
      topic: topicId == null ? null : await repo.getTopic(topicId),
      scanTexts: scanTextsOf(views, _history),
    );
    return WorldBookRequest(
      messages: applyWorldBookMessages(segments, turn),
      turn: turn,
    );
  }

  /// The keyword scan source: each user / assistant view's request text (main
  /// text + FILE text, without 发送期正则), oldest first. Tool results and
  /// thinking are excluded, like kelivo.
  static List<String> scanTextsOf(
    Iterable<ChatMessageView> views,
    LlmHistoryBuilder history,
  ) => [
    for (final view in views)
      if (view.role == MessageRole.user || view.role == MessageRole.assistant)
        if (history.requestContent(view) case final text
            when text.trim().isNotEmpty)
          text,
  ];
}
