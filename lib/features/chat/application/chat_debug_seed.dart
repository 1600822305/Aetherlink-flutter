import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

part 'chat_debug_seed.g.dart';

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
