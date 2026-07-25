import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

part 'chat_view_providers.g.dart';

/// The topic whose conversation the page shows. [Assistants] is the seed
/// authority — awaiting it guarantees the default assistants and their topics
/// exist on a fresh store before any topic is resolved. The selection (the
/// 话题 tab's [currentTopicIdProvider]) wins; otherwise it falls back to the
/// current assistant's most recent topic, then any recent topic, then `null`.
@riverpod
Future<Topic?> currentTopic(Ref ref) async {
  final assistants = await ref.watch(assistantsProvider.future);
  final repo = ref.watch(chatRepositoryProvider);
  // Re-fetch when an in-place topic mutation (切换分支 / 选择多模型回复 / 清空消息)
  // bumps the refresh signal — otherwise this returns the cached Topic with a
  // stale activeNodeId, so 分支管理 的「当前」节点固化、点节点没反应。
  ref.watch(chatRefreshProvider);

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
