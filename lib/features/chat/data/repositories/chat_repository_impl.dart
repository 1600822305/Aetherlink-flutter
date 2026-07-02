import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_version.dart';
import 'package:aetherlink_flutter/features/chat/domain/message_ordering.dart';
import 'package:aetherlink_flutter/features/chat/domain/message_tree_builder.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/chat/domain/search/chat_search.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// Drift-backed [ChatRepository]. Delegates to the per-table DAOs, which store
/// each domain entity as a JSON blob and read it back — so the repository deals
/// purely in domain models and never leaks Drift row types upward.
class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._db);

  final AppDatabase _db;

  // --- Topics ---------------------------------------------------------------

  @override
  Future<List<Topic>> getAllTopics() => _db.topicDao.getAll();

  @override
  Future<Topic?> getTopic(String id) => _db.topicDao.getById(id);

  @override
  Future<List<Topic>> getRecentTopics({int limit = 10}) =>
      _db.topicDao.getRecent(limit: limit);

  @override
  Future<void> saveTopic(Topic topic) => _db.topicDao.upsert(topic);

  @override
  Future<void> deleteTopic(String id) {
    return _db.transaction(() async {
      final messages = await _db.messageDao.getByTopicId(id);
      final blockIds = <String>[];
      for (final message in messages) {
        blockIds.addAll(message.blocks);
        blockIds.addAll(_versionAndSnapshotBlockIds(message));
      }
      if (blockIds.isNotEmpty) {
        await _db.messageBlockDao.deleteByIds(blockIds);
      }
      await _db.messageDao.deleteByTopicId(id);
      await _db.topicDao.deleteById(id);
    });
  }

  // --- Messages -------------------------------------------------------------

  @override
  Future<Message?> getMessage(String id) => _db.messageDao.getById(id);

  @override
  Future<List<Message>> getAllMessages() => _db.messageDao.getAll();

  @override
  Future<List<Message>> getMessagesByIds(List<String> ids) =>
      _db.messageDao.getByIds(ids);

  @override
  Future<List<Message>> getMessagesByTopicId(String topicId) =>
      _db.messageDao.getByTopicId(topicId);

  @override
  Future<List<Message>> getBranchMessages(String topicId) async {
    final content = await _db.messageDao.getByTopicId(topicId);
    if (content.isEmpty) return content;
    final topic = await _db.topicDao.getById(topicId);
    final root = await _db.messageDao.getRootByTopicId(topicId);
    final ordered = orderBranchMessages(
      content,
      rootId: root?.id,
      activeNodeId: topic?.activeNodeId,
    );
    // A non-empty projection is the authoritative active path: it *intentionally*
    // excludes off-path branches (forks created via 从此处分叉, or the unselected
    // members of a multi-model group), so we trust it even when it's shorter than
    // the full content — that's what makes branch switching actually hide the
    // other branch. Only fall back to a chronological sort when projection is
    // impossible (missing root/active node, a cycle, or the active node can't
    // reach the root, e.g. legacy/restored flat data) so a broken tree never
    // silently loses messages.
    if (ordered.isEmpty) {
      return content..sort(compareMessagesChronologically);
    }
    return ordered;
  }

  @override
  Future<List<Message>> getMessagesByAssistantId(String assistantId) =>
      _db.messageDao.getByAssistantId(assistantId);

  @override
  Future<void> saveMessage(Message message) async {
    // The virtual root is written verbatim; updates (a loaded message re-saved
    // via copyWith) already carry their parentId. Only a brand-new content
    // message (no parentId yet) is attached to the tree here — one choke point
    // covering every chat_controller create site (send / combo / resend).
    if (message.role == MessageRole.root || message.parentId != null) {
      await _db.messageDao.upsert(message);
      return;
    }
    final topic = await _db.topicDao.getById(message.topicId);
    // No owning topic row (test fixtures / orphan saves) → store verbatim; the
    // tree is only maintained for real topics (runtime always creates the topic
    // before its messages via _ensureTopic).
    if (topic == null) {
      await _db.messageDao.upsert(message);
      return;
    }
    await _db.transaction(() async {
      final rootId = await _ensureRootMessage(topic);
      final activeLeaf = topic.activeNodeId ?? rootId;
      // An assistant reply hangs off the user message it answers (askId); a new
      // user message hangs off the current active leaf.
      final parentId = message.askId ?? activeLeaf;
      await _db.messageDao.upsert(message.copyWith(parentId: parentId));
      // Advance the active leaf when this message extends the active path.
      if (parentId == activeLeaf) {
        await _db.topicDao.upsert(topic.copyWith(activeNodeId: message.id));
      }
    });
  }

  /// Returns the topic's virtual-root id, lazily creating the root for topics
  /// that don't have one yet (e.g. created at runtime after the v7→v8 backfill).
  Future<String> _ensureRootMessage(Topic topic) async {
    final existing = await _db.messageDao.getRootByTopicId(topic.id);
    if (existing != null) return existing.id;
    final root = Message(
      id: generateId('root'),
      role: MessageRole.root,
      assistantId: topic.assistantId,
      topicId: topic.id,
      createdAt: topic.createdAt,
      status: MessageStatus.success,
    );
    await _db.messageDao.upsert(root);
    return root.id;
  }

  @override
  Future<void> saveMessages(List<Message> messages) =>
      _db.messageDao.upsertAll(messages);

  @override
  Future<void> deleteMessage(String id, {bool cascade = false}) {
    return _db.transaction(() async {
      final message = await _db.messageDao.getById(id);
      if (message == null) return;
      // The virtual root is structural — never removed by a message delete.
      if (message.role == MessageRole.root) return;

      // All content messages of the topic, to walk the tree in memory.
      final all = await _db.messageDao.getByTopicId(message.topicId);
      final childrenByParent = <String, List<Message>>{};
      for (final m in all) {
        (childrenByParent[m.parentId ?? ''] ??= <Message>[]).add(m);
      }

      // Collect the ids to remove: just this node (reparent mode) or the whole
      // subtree (cascade mode).
      final toRemove = <Message>[];
      if (cascade) {
        final stack = <Message>[message];
        while (stack.isNotEmpty) {
          final node = stack.removeLast();
          toRemove.add(node);
          stack.addAll(childrenByParent[node.id] ?? const []);
        }
      } else {
        toRemove.add(message);
        // Reparent direct children onto the deleted node's parent.
        for (final child in childrenByParent[id] ?? const <Message>[]) {
          await _db.messageDao.upsert(child.copyWith(parentId: message.parentId));
        }
      }

      final removedIds = {for (final m in toRemove) m.id};

      // Delete blocks (own + version/snapshot) then the rows.
      for (final m in toRemove) {
        final extraIds = _versionAndSnapshotBlockIds(m);
        if (extraIds.isNotEmpty) {
          await _db.messageBlockDao.deleteByIds(extraIds);
        }
        await _db.messageBlockDao.deleteByMessageId(m.id);
        await _db.messageDao.deleteById(m.id);
      }

      // Fix the active leaf if it pointed at a removed node — fall back to the
      // deleted node's parent (null if that was the root); getBranchMessages
      // tolerates an imperfect leaf via its chronological fallback.
      final topic = await _db.topicDao.getById(message.topicId);
      if (topic != null &&
          topic.activeNodeId != null &&
          removedIds.contains(topic.activeNodeId)) {
        final rootId = await _db.messageDao.getRootByTopicId(message.topicId);
        final fallback = message.parentId == rootId?.id
            ? null
            : message.parentId;
        await _db.topicDao.upsert(topic.copyWith(activeNodeId: fallback));
      }
    });
  }

  @override
  Future<void> setActiveNode(String topicId, String? nodeId) async {
    final topic = await _db.topicDao.getById(topicId);
    if (topic == null) return;
    await _db.topicDao.upsert(topic.copyWith(activeNodeId: nodeId));
  }

  @override
  Future<List<Message>> getChildren(String topicId, String parentId) async {
    final all = await _db.messageDao.getByTopicId(topicId);
    return all.where((m) => m.parentId == parentId).toList()
      ..sort(compareMessagesChronologically);
  }

  @override
  Future<String?> getRootMessageId(String topicId) async =>
      (await _db.messageDao.getRootByTopicId(topicId))?.id;

  @override
  Future<void> clearTopicMessages(String topicId) {
    return _db.transaction(() async {
      final all = await _db.messageDao.getByTopicId(topicId); // excludes root
      final blockIds = <String>[];
      for (final m in all) {
        blockIds.addAll(m.blocks);
        blockIds.addAll(_versionAndSnapshotBlockIds(m));
      }
      if (blockIds.isNotEmpty) {
        await _db.messageBlockDao.deleteByIds(blockIds);
      }
      for (final m in all) {
        await _db.messageDao.deleteById(m.id);
      }
      final topic = await _db.topicDao.getById(topicId);
      if (topic != null) {
        await _db.topicDao.upsert(topic.copyWith(activeNodeId: null));
      }
    });
  }

  // --- Message blocks -------------------------------------------------------

  @override
  Future<MessageBlock?> getMessageBlock(String id) =>
      _db.messageBlockDao.getById(id);

  @override
  Future<List<ChatSearchableText>> getAllMainTexts() =>
      _db.messageBlockDao.getAllMainTexts();

  @override
  Future<List<MessageBlock>> getMessageBlocksByIds(List<String> ids) =>
      _db.messageBlockDao.getByIds(ids);

  @override
  Future<List<MessageBlock>> getMessageBlocksByMessageId(String messageId) =>
      _db.messageBlockDao.getByMessageId(messageId);

  @override
  Future<void> saveMessageBlock(MessageBlock block) =>
      _db.messageBlockDao.upsert(block);

  @override
  Future<void> saveMessageBlocks(List<MessageBlock> blocks) =>
      _db.messageBlockDao.upsertAll(blocks);

  @override
  Future<void> deleteMessageBlock(String id) =>
      _db.messageBlockDao.deleteById(id);

  // --- Assistants -----------------------------------------------------------

  @override
  Future<List<Assistant>> getAllAssistants() => _db.assistantDao.getAll();

  @override
  Future<Assistant?> getAssistant(String id) => _db.assistantDao.getById(id);

  @override
  Future<void> saveAssistant(Assistant assistant) =>
      _db.assistantDao.upsert(assistant);

  @override
  Future<void> deleteAssistant(String id) => _db.assistantDao.deleteById(id);

  // --- Groups ---------------------------------------------------------------

  @override
  Future<List<Group>> getAllGroups() => _db.groupDao.getAll();

  @override
  Future<void> saveGroup(Group group) => _db.groupDao.upsert(group);

  @override
  Future<void> deleteGroup(String id) => _db.groupDao.deleteById(id);

  // --- Settings -------------------------------------------------------------

  @override
  Future<String?> getSetting(String key) => _db.appSettingDao.getValue(key);

  @override
  Future<void> saveSetting(String key, String value) =>
      _db.appSettingDao.setValue(key, value);

  // --- Transactions ---------------------------------------------------------

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) =>
      _db.transaction(action);

  // --- Helpers --------------------------------------------------------------

  /// Collects block IDs from a message's versions and its latest-content
  /// snapshot metadata. These blocks use synthetic messageId values
  /// (e.g. 'version_xxx', 'latest_xxx') that are not caught by a simple
  /// `deleteByMessageId` call.
  List<String> _versionAndSnapshotBlockIds(Message message) {
    final ids = <String>[];
    for (final version in message.versions ?? const <MessageVersion>[]) {
      ids.addAll(version.blocks);
    }
    final snapshot = message.metadata?['latestSnapshot'];
    if (snapshot is Map) {
      final blocks = snapshot['blocks'];
      if (blocks is List) {
        for (final id in blocks) {
          if (id is String) ids.add(id);
        }
      }
    }
    return ids;
  }
}
