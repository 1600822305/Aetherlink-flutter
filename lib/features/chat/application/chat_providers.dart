import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/network_proxy_access.dart';
import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/provider_factory.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway_factory.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/remote_mcp_connection_manager.dart';

part 'chat_providers.g.dart';

/// Application-layer DI seam + read view-models that back the ChatPage.
///
/// The page is a pure view: it watches [chatMessagesProvider] /
/// [currentTopicProvider] / [messageBlocksProvider] and never imports `data`
/// (Rule 1). Everything below is the composition that makes those reads real —
/// the M1 persistence stack (Drift [AppDatabase] → [ChatRepositoryImpl]) wired
/// up behind the [ChatRepository] port, with no mocks. An empty database yields
/// an empty list, which the page renders as its empty state.
///
/// M4.2.1 renders stored `main_text` blocks as bubbles, so this file gains a
/// per-message block read ([messageBlocks]) and a debug-only seed
/// ([debugChatSeed]) so the bubbles are visible before sending/streaming land.
/// Sending, streaming, the other 14 block variants and markdown are later
/// slices; this file intentionally exposes only `Future` reads.

/// The single app-wide Drift database (composition root in `core/database`).
/// Kept alive for the app's lifetime and closed when the container disposes.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
}

/// The chat persistence port, backed by Drift. Upper layers depend on the
/// [ChatRepository] interface; this provider is the one place the `data`
/// implementation is wired in.
@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) =>
    ChatRepositoryImpl(ref.watch(appDatabaseProvider));

/// The LLM gateway factory port, backed by the protocol-selecting
/// `LlmProviderFactory` (M2 `data`) with a runtime `dio`. The [ChatController]
/// depends only on the [LlmGatewayFactory] interface; tests override this with
/// a fake factory (and a fake gateway) so the closed loop runs without a
/// network or a real key.
@Riverpod(keepAlive: true)
LlmGatewayFactory llmGatewayFactory(Ref ref) =>
    LlmProviderFactory(proxy: ref.watch(appNetworkProxyConfigProvider));

/// The live MCP connection pool for remote (sse / streamableHttp) servers,
/// shared across chat turns. Kept alive so connections are reused; closed when
/// the container disposes. The chat tool-call loop and the 设置 详情页「测试」
/// button both dispatch tool discovery / execution through it (the latter via
/// the `app/di` re-export, since settings may not import chat internals).
@Riverpod(keepAlive: true)
RemoteMcpConnectionManager remoteMcpConnectionManager(Ref ref) {
  final manager = RemoteMcpConnectionManager(
    proxy: ref.watch(appNetworkProxyConfigProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
}

/// Debug-only seed so message rendering is visible before send/streaming exist
/// (M4.2.2+). In release builds ([kDebugMode] false) this is a no-op, so the
/// read pipeline behaves exactly as before. It is idempotent — it writes
/// nothing once any topic exists — and it goes through the real
/// [ChatRepository] (no fabricated widget-level bubbles): a topic, a user
/// message + `main_text` block, and an assistant message + `main_text` block,
/// which then flow back out through [getMessageBlocksByMessageId] like any
/// real conversation.
@riverpod
Future<void> debugChatSeed(Ref ref) async {
  if (!kDebugMode) {
    return;
  }
  final repo = ref.watch(chatRepositoryProvider);
  final existing = await repo.getRecentTopics(limit: 1);
  if (existing.isNotEmpty) {
    return;
  }

  const assistantId = 'debug-seed-assistant';
  const topicId = 'debug-seed-topic';
  const userMessageId = 'debug-seed-msg-user';
  const assistantMessageId = 'debug-seed-msg-assistant';
  const userBlockId = 'debug-seed-block-user';
  const assistantBlockId = 'debug-seed-block-assistant';
  final now = DateTime.now();

  await repo.saveTopic(
    Topic(
      id: topicId,
      assistantId: assistantId,
      name: '调试会话（仅 Debug 构建）',
      createdAt: now,
      updatedAt: now,
    ),
  );

  await repo.saveMessage(
    Message(
      id: userMessageId,
      role: MessageRole.user,
      assistantId: assistantId,
      topicId: topicId,
      createdAt: now,
      status: MessageStatus.success,
      blocks: const <String>[userBlockId],
    ),
  );
  await repo.saveMessageBlock(
    MessageBlock.mainText(
      id: userBlockId,
      messageId: userMessageId,
      status: MessageBlockStatus.success,
      createdAt: now,
      content: '你好，请用一句话介绍一下 AetherLink。',
    ),
  );

  final replyTime = now.add(const Duration(seconds: 1));
  await repo.saveMessage(
    Message(
      id: assistantMessageId,
      role: MessageRole.assistant,
      assistantId: assistantId,
      topicId: topicId,
      createdAt: replyTime,
      status: MessageStatus.success,
      blocks: const <String>[assistantBlockId],
    ),
  );
  await repo.saveMessageBlock(
    MessageBlock.mainText(
      id: assistantBlockId,
      messageId: assistantMessageId,
      status: MessageBlockStatus.success,
      createdAt: replyTime,
      content: 'AetherLink 是一个开源的多模型 AI 对话客户端，正在用 Flutter 原生重写。',
    ),
  );
}

/// The topic whose conversation the page shows. [Assistants] is the seed
/// authority — awaiting it guarantees the default assistants and their topics
/// exist on a fresh store before any topic is resolved. The selection (the
/// 话题 tab's [currentTopicIdProvider]) wins; otherwise it falls back to the
/// current assistant's most recent topic, then any recent topic, then `null`.
@riverpod
Future<Topic?> currentTopic(Ref ref) async {
  final assistants = await ref.watch(assistantsProvider.future);
  final repo = ref.watch(chatRepositoryProvider);

  final selectedId = ref.watch(currentTopicIdProvider);
  if (selectedId != null) {
    final selected = await repo.getTopic(selectedId);
    if (selected != null) return selected;
  }

  final selectedAssistantId = ref.watch(currentAssistantIdProvider);
  final assistantId =
      selectedAssistantId ?? (assistants.isEmpty ? null : assistants.first.id);
  if (assistantId != null) {
    final mine =
        (await repo.getAllTopics())
            .where((t) => t.assistantId == assistantId)
            .toList()
          ..sort(compareTopicsByRecency);
    if (mine.isNotEmpty) return mine.first;
  }

  final recent = await repo.getRecentTopics(limit: 1);
  return recent.isEmpty ? null : recent.first;
}

/// Messages for the [currentTopic], as stored. No current topic (empty
/// database) → an empty list → the page's empty state. This is the ChatPage's
/// "About-page moment": proof the presentation → application → repository →
/// Drift pipeline is connected.
@riverpod
Future<List<Message>> chatMessages(Ref ref) async {
  final topic = await ref.watch(currentTopicProvider.future);
  if (topic == null) {
    return const <Message>[];
  }
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getMessagesByTopicId(topic.id);
}

/// The blocks for a single message, in stored order, read through the real
/// [ChatRepository.getMessageBlocksByMessageId]. M4.2.1 renders only the
/// `main_text` blocks among them; the other variants are later slices.
@riverpod
Future<List<MessageBlock>> messageBlocks(Ref ref, String messageId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getMessageBlocksByMessageId(messageId);
}
