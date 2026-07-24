import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar/assistants_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar/groups_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar/sidebar_selection_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar/topic_defaults.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

part 'topics_providers.g.dart';

/// All topics, persisted via Drift. Depends on [Assistants] so seeding (which
/// creates the default topics) always runs first.
@Riverpod(keepAlive: true)
class Topics extends _$Topics {
  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  Future<List<Topic>> build() async {
    await ref.watch(assistantsProvider.future);
    return _repo.getAllTopics();
  }

  Future<void> _reload() async {
    state = AsyncData<List<Topic>>(await _repo.getAllTopics());
  }

  List<Topic> _topicsOf(String assistantId, List<Topic> all) {
    final mine = all.where((t) => t.assistantId == assistantId).toList();
    mine.sort(compareTopicsByRecency);
    return mine;
  }

  /// Creates a fresh "新的对话" for [assistantId] and selects it — the port of
  /// `handleCreateTopic` (which unshifts; our views sort by recency so the new
  /// topic naturally surfaces at the top).
  Future<Topic> create(String assistantId) async {
    final now = DateTime.now();
    final topic = newDefaultTopic(
      id: generateId('topic'),
      assistantId: assistantId,
      now: now,
    );
    await _repo.saveTopic(topic);
    final assistant = await _repo.getAssistant(assistantId);
    if (assistant != null) {
      await _repo.saveAssistant(
        assistant.copyWith(topicIds: <String>[topic.id, ...assistant.topicIds]),
      );
    }
    await _reload();
    ref.read(currentTopicIdProvider.notifier).set(topic.id);
    return topic;
  }

  /// Forks the conversation into a new topic, cloning the **tree path** from the
  /// root up to and including [branchPointMessageId], then selects the new
  /// topic — the port of `TopicService.duplicate` / `getPathRowsToNodeTx`
  /// (分支管理 复制为新对话 / 工具栏 创建分支). The prefix is taken by walking
  /// `parentId` ancestors (not a flat chronological slice): a chronological
  /// `sublist` mis-orders and drops messages whenever timestamps tie — which
  /// clones themselves cause (every cloned row used to share `createdAt`), so
  /// re-cloning or cloning imported/tied histories lost the conversation. Each
  /// cloned message/block gets a fresh id and a distinct increasing timestamp,
  /// `askId` is remapped to the cloned user message so intra-branch links
  /// survive, and version history is dropped (the branch is a new starting
  /// point). A no-op (returns null) when the branch-point message or its topic
  /// can't be resolved.
  Future<Topic?> createBranch(String branchPointMessageId) async {
    final branchMessage = await _repo.getMessage(branchPointMessageId);
    if (branchMessage == null) return null;
    final source = await _repo.getTopic(branchMessage.topicId);
    if (source == null) return null;

    final content = await _repo.getMessagesByTopicId(source.id);
    final byId = {for (final m in content) m.id: m};
    if (!byId.containsKey(branchPointMessageId)) return null;

    // A topic built by the app has a message tree (every content message has a
    // parentId); 旧版 web 迁移 / 未建树的导入 leaves it flat (all parentId null).
    final hasTree = content.any((m) => m.parentId != null);

    final List<Message> toClone;
    if (hasTree) {
      // Collect the path from the branch point up to the root via parentId, then
      // reverse to root→leaf order. Robust to tied/equal createdAt and, unlike a
      // chronological prefix, never pulls in off-path sibling branches.
      final pathLeafFirst = <Message>[];
      final visited = <String>{};
      String? cursor = branchPointMessageId;
      while (cursor != null && byId.containsKey(cursor)) {
        if (!visited.add(cursor)) break; // cycle guard
        final node = byId[cursor]!;
        pathLeafFirst.add(node);
        cursor = node.parentId;
      }
      toClone = pathLeafFirst.reversed.toList();
    } else {
      // Flat/legacy topic: clone the prefix in the *displayed* order (the same
      // projection the chat list uses, so the clone matches what the user sees)
      // up to and including the branch point. The cloned rows are re-chained
      // into a proper tree below so the new topic isn't flat in turn.
      final displayed = await _repo.getBranchMessages(source.id);
      final idx = displayed.indexWhere((m) => m.id == branchPointMessageId);
      toClone = idx == -1 ? const [] : displayed.sublist(0, idx + 1);
    }
    if (toClone.isEmpty) return null;

    final now = DateTime.now();
    final newTopicId = generateId('topic');

    // The new topic needs its own content-less virtual root, exactly like a
    // freshly-created topic — without it getRootMessageId is null, so
    // orderBranchMessages / the 分支管理 canvas can't project an active path and
    // fall back to a flat chronological list (点节点切分支看起来没反应).
    final rootId = generateId('root');
    final rootMessage = Message(
      id: rootId,
      role: MessageRole.root,
      assistantId: source.assistantId,
      topicId: newTopicId,
      createdAt: now,
      status: MessageStatus.success,
    );

    // Pass 1: map every cloned message's old id to a fresh one so intra-branch
    // references (askId / parentId) can be remapped in pass 2.
    final idMap = <String, String>{
      for (final message in toClone) message.id: generateId('msg'),
    };

    // The cloned parentId for each message: a real tree keeps its shape (remap
    // via idMap); a flat topic is re-chained linearly (each row hangs off the
    // previous one) so the new topic becomes a connected tree instead of every
    // message dangling off the root (分支管理 变一长行).
    String parentForCloned(int index) {
      if (!hasTree) {
        return index == 0 ? rootId : idMap[toClone[index - 1].id]!;
      }
      final original = toClone[index].parentId;
      return original == null ? rootId : (idMap[original] ?? rootId);
    }

    // Pass 2: clone each message with its blocks (fresh ids), remap askId, and
    // drop version history. Each row gets a distinct increasing timestamp
    // (now + index µs) so the clone never inherits the tied-timestamp hazard.
    final clonedMessages = <Message>[];
    final clonedBlocks = <MessageBlock>[];
    for (var i = 0; i < toClone.length; i++) {
      final message = toClone[i];
      final stamp = now.add(Duration(microseconds: i));
      final newId = idMap[message.id]!;
      final originalBlocks = await _repo.getMessageBlocksByIds(message.blocks);
      final newBlocks = originalBlocks
          .map(
            (block) => block.copyWith(
              id: generateId('block'),
              messageId: newId,
              createdAt: stamp,
              updatedAt: stamp,
            ),
          )
          .toList();
      clonedBlocks.addAll(newBlocks);
      clonedMessages.add(
        message.copyWith(
          id: newId,
          topicId: newTopicId,
          parentId: parentForCloned(i),
          askId: message.askId == null ? null : idMap[message.askId],
          blocks: newBlocks.map((b) => b.id).toList(),
          versions: null,
          currentVersionId: null,
          createdAt: stamp,
          updatedAt: stamp,
        ),
      );
    }

    final newTopic =
        newDefaultTopic(
          id: newTopicId,
          assistantId: source.assistantId,
          now: now,
        ).copyWith(
          name: '${source.name} (分支)',
          messageIds: clonedMessages.map((m) => m.id).toList(),
          // Make the cloned branch point the active leaf so the new topic opens
          // on that path (branch manager shows 当前) and the next reply appends
          // to it instead of forking off the root.
          activeNodeId: clonedMessages.isEmpty ? null : clonedMessages.last.id,
          lastMessageTime: clonedMessages.isEmpty
              ? now.toIso8601String()
              : clonedMessages.last.createdAt.toIso8601String(),
        );

    await _repo.saveTopic(newTopic);
    if (clonedBlocks.isNotEmpty) {
      await _repo.saveMessageBlocks(clonedBlocks);
    }
    await _repo.saveMessages([rootMessage, ...clonedMessages]);

    final assistant = await _repo.getAssistant(source.assistantId);
    if (assistant != null) {
      await _repo.saveAssistant(
        assistant.copyWith(
          topicIds: <String>[newTopic.id, ...assistant.topicIds],
        ),
      );
    }

    await _reload();
    ref.read(currentTopicIdProvider.notifier).set(newTopic.id);
    return newTopic;
  }

  /// Selects [assistantId]'s most recent topic, creating one if it has none.
  Future<void> selectFirstOrCreate(String assistantId) async {
    final mine = _topicsOf(assistantId, await _repo.getAllTopics());
    if (mine.isNotEmpty) {
      ref.read(currentTopicIdProvider.notifier).set(mine.first.id);
    } else {
      await create(assistantId);
    }
  }

  /// Deletes [id]; if it was the current topic, selects the adjacent sibling
  /// (next, else previous, else none) — the port of `handleDeleteTopic`.
  Future<void> delete(String id) async {
    final all = await _repo.getAllTopics();
    Topic? target;
    for (final t in all) {
      if (t.id == id) {
        target = t;
        break;
      }
    }
    final wasCurrent = ref.read(currentTopicIdProvider) == id;
    await _repo.deleteTopic(id);
    await ref.read(groupsProvider.notifier).purgeItem(id, GroupType.topic);

    if (wasCurrent && target != null) {
      final siblings = _topicsOf(target.assistantId, all);
      final idx = siblings.indexWhere((t) => t.id == id);
      String? next;
      if (siblings.length > 1 && idx != -1) {
        next = idx < siblings.length - 1
            ? siblings[idx + 1].id
            : siblings[idx - 1].id;
      }
      ref.read(currentTopicIdProvider.notifier).set(next);
    }
    await _reload();
  }

  /// Toggles 固定/取消固定; pinned topics sort first.
  Future<void> togglePin(String id) async {
    final topic = await _repo.getTopic(id);
    if (topic == null) return;
    await _repo.saveTopic(
      topic.copyWith(pinned: !topic.pinned, updatedAt: DateTime.now()),
    );
    await _reload();
  }

  /// Saves [prompt] as a 话题提示词 (`topic.prompt`) — the port of
  /// `SystemPromptDialog.handleSaveToTopic`. With no [topicId], creates a new
  /// topic for [assistantId] first (`TopicService.createNewTopic`), then writes
  /// the prompt onto it. Returns the saved topic. [_reload] refreshes the
  /// topic-backed views so the bubble re-renders.
  Future<Topic> setPrompt({
    String? topicId,
    String? assistantId,
    required String prompt,
  }) async {
    if (topicId == null) {
      if (assistantId == null) {
        throw StateError('创建话题失败');
      }
      // `create` already saves, selects and reloads; layer the prompt on top.
      final created = await create(assistantId);
      final withPrompt = created.copyWith(
        prompt: prompt,
        updatedAt: DateTime.now(),
      );
      await _repo.saveTopic(withPrompt);
      await _reload();
      return withPrompt;
    }
    final topic = await _repo.getTopic(topicId);
    if (topic == null) {
      throw StateError('话题不存在');
    }
    final updated = topic.copyWith(prompt: prompt, updatedAt: DateTime.now());
    await _repo.saveTopic(updated);
    await _reload();
    return updated;
  }

  /// Renames [id] (编辑话题, name only — the prompt is edited via
  /// `SystemPromptDialog` → [setPrompt]).
  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final topic = await _repo.getTopic(id);
    if (topic == null) return;
    await _repo.saveTopic(
      topic.copyWith(
        name: trimmed,
        isNameManuallyEdited: true,
        updatedAt: DateTime.now(),
      ),
    );
    await _reload();
  }

  /// Clears every message of [id] (清空消息). Tree-aware: deletes all non-root
  /// messages and clears `activeNodeId` while keeping the virtual root
  /// ([ChatRepository.clearTopicMessages]).
  Future<void> clearMessages(String id) async {
    await _repo.clearTopicMessages(id);
    final topic = await _repo.getTopic(id);
    if (topic != null) {
      await _repo.saveTopic(
        topic.copyWith(
          messageIds: const <String>[],
          lastMessagePreview: null,
          updatedAt: DateTime.now(),
        ),
      );
    }
    await _reload();
    if (ref.read(currentTopicIdProvider) == id) {
      ref.read(chatRefreshProvider.notifier).bump();
    }
  }

  /// Moves [topicId] to [targetAssistantId] (移动到…). If it was current, the
  /// selection falls back to the current assistant's recent topic.
  Future<void> move(String topicId, String targetAssistantId) async {
    final topic = await _repo.getTopic(topicId);
    if (topic == null || topic.assistantId == targetAssistantId) return;
    final source = await _repo.getAssistant(topic.assistantId);
    if (source != null) {
      await _repo.saveAssistant(
        source.copyWith(
          topicIds: source.topicIds.where((t) => t != topicId).toList(),
        ),
      );
    }
    await _repo.saveTopic(
      topic.copyWith(assistantId: targetAssistantId, updatedAt: DateTime.now()),
    );
    final target = await _repo.getAssistant(targetAssistantId);
    if (target != null && !target.topicIds.contains(topicId)) {
      await _repo.saveAssistant(
        target.copyWith(topicIds: <String>[topicId, ...target.topicIds]),
      );
    }
    // 话题分组按助手作用域，移动后从原助手的分组里清掉，避免残留成员。
    await ref.read(groupsProvider.notifier).purgeItem(topicId, GroupType.topic);
    if (ref.read(currentTopicIdProvider) == topicId) {
      // 打开中的会话跟随话题到目标助手（composer/模型按新助手解析），
      // 而不是清空选中。
      ref.read(currentAssistantIdProvider.notifier).set(targetAssistantId);
    }
    await _reload();
  }
}
