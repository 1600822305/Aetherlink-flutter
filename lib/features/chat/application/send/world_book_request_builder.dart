import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/world_book_access.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/mcp_tools_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/send/llm_history_builder.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message_segment.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/chat/domain/token_estimate.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_turn.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';

/// A request's history with 世界书 chat-position entries woven in, plus the
/// evaluated [turn]. With nothing bound or triggered, [messages] equals
/// `buildLlmMessages` and the system prompt is untouched.
class WorldBookRequest {
  const WorldBookRequest({required this.messages, required this.turn});

  final List<LlmMessage> messages;
  final WorldBookTurn turn;
}

/// Evaluates 世界书 once per user turn and builds request history for the
/// send / regenerate / resend / continue / multi-model paths.
///
/// Timer state (P3) lives on the turn's **user message** metadata: [evaluate]
/// resolves the clock from that message's ancestors on the tree (one walk),
/// runs the timed selection, and writes the new state back onto the user
/// message. Re-evaluating the same user message (regenerate, multi-model
/// siblings) therefore starts from the same ancestor state and is idempotent.
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

  /// Evaluates the turn owned by user message [userMessageId] (null → no
  /// timer state, e.g. a topic-less preview). Persists the timer state.
  Future<WorldBookTurn> evaluate(
    List<ChatMessageView> views, {
    required String? topicId,
    required String? userMessageId,
  }) async {
    final repo = _repoOf();
    final topic = topicId == null ? null : await repo.getTopic(topicId);
    final assistant = await repo.getAssistant(_assistantIdOf());
    final binding = worldBookBindingFor(assistant, topic);
    if (binding.ids.isEmpty) return WorldBookTurn.none;
    final owner = userMessageId == null
        ? null
        : await repo.getMessage(userMessageId);
    final clock = owner == null || topicId == null
        ? null
        : worldBookClockFor(await _ancestorsOf(owner, topicId));
    final turn = await collectWorldBookTurn(
      _refOf(),
      assistant: assistant,
      topic: topic,
      scanTexts: scanTextsOf(views, _history),
      clock: clock,
    );
    if (owner != null) {
      final metadata = worldBookMetadataFor(owner.metadata, turn);
      if (metadata != null) {
        await repo.saveMessage(owner.copyWith(metadata: metadata));
      }
    }
    return turn;
  }

  /// [evaluate] + segment building + injection, for single-model paths.
  Future<WorldBookRequest> build(
    List<ChatMessageView> views, {
    required String? topicId,
    required String? userMessageId,
    required Model chatModel,
    List<AssistantRegex>? regexRules,
    required McpMode toolMode,
    bool dropEmptyAssistant = true,
  }) async {
    final turn = await evaluate(
      views,
      topicId: topicId,
      userMessageId: userMessageId,
    );
    return WorldBookRequest(
      messages: await inject(
        views,
        turn,
        chatModel: chatModel,
        regexRules: regexRules,
        toolMode: toolMode,
        dropEmptyAssistant: dropEmptyAssistant,
      ),
      turn: turn,
    );
  }

  /// Builds [views]' segments for [chatModel] and weaves an already-evaluated
  /// [turn] in — the per-model half used by multi-model siblings.
  Future<List<LlmMessage>> inject(
    List<ChatMessageView> views,
    WorldBookTurn turn, {
    required Model chatModel,
    List<AssistantRegex>? regexRules,
    required McpMode toolMode,
    bool dropEmptyAssistant = true,
  }) async {
    final List<LlmMessageSegment> segments = await _history
        .buildLlmMessageSegments(
          views,
          chatModel: chatModel,
          regexRules: regexRules,
          toolMode: toolMode,
          dropEmptyAssistant: dropEmptyAssistant,
        );
    return applyWorldBookMessages(segments, turn);
  }

  /// The 本轮注入 block for an assistant message (empty when nothing fired).
  static List<MessageBlock> injectionBlocks(
    WorldBookTurn turn, {
    required String messageId,
    required DateTime createdAt,
  }) {
    if (turn.isEmpty) return const <MessageBlock>[];
    return <MessageBlock>[
      MessageBlock.worldBookInjection(
        id: generateId('block'),
        messageId: messageId,
        status: MessageBlockStatus.success,
        createdAt: createdAt,
        count: turn.triggered.length,
        entries: [
          for (final e in turn.triggered)
            e.name.trim().isEmpty ? '未命名条目' : e.name.trim(),
        ],
        estimatedTokens: estimateTokens(worldBookInjectedText(turn)),
      ),
    ];
  }

  /// The user message that owns the turn answered by assistant [askId] /
  /// the latest user view — the timer-state carrier.
  static String? ownerUserId(List<ChatMessageView> views) {
    for (var i = views.length - 1; i >= 0; i--) {
      if (views[i].role == MessageRole.user) return views[i].id;
    }
    return null;
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

  /// [owner]'s ancestors on the tree, oldest first, root excluded — one pass
  /// over the topic's messages indexed by id (O(n), cycle-guarded).
  Future<List<({bool isUserTurn, bool isSummary, Map<String, dynamic>? metadata})>>
  _ancestorsOf(Message owner, String topicId) async {
    final all = await _repoOf().getMessagesByTopicId(topicId);
    final byId = {for (final m in all) m.id: m};
    final path = <Message>[];
    final seen = <String>{owner.id};
    var parentId = owner.parentId;
    while (parentId != null && seen.add(parentId)) {
      final parent = byId[parentId];
      if (parent == null) break;
      path.add(parent);
      parentId = parent.parentId;
    }
    return [
      for (final m in path.reversed)
        (
          isUserTurn: m.role == MessageRole.user,
          isSummary: m.metadata?['isSummary'] == true,
          metadata: m.metadata,
        ),
    ];
  }
}
