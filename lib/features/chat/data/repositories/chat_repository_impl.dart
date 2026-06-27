import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_version.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
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
  Future<List<Message>> getMessagesByAssistantId(String assistantId) =>
      _db.messageDao.getByAssistantId(assistantId);

  @override
  Future<void> saveMessage(Message message) => _db.messageDao.upsert(message);

  @override
  Future<void> saveMessages(List<Message> messages) =>
      _db.messageDao.upsertAll(messages);

  @override
  Future<void> deleteMessage(String id) {
    return _db.transaction(() async {
      // Also delete blocks belonging to versions and the latest-content
      // snapshot so they do not remain as orphaned rows.
      final message = await _db.messageDao.getById(id);
      if (message != null) {
        final extraIds = _versionAndSnapshotBlockIds(message);
        if (extraIds.isNotEmpty) {
          await _db.messageBlockDao.deleteByIds(extraIds);
        }
      }
      await _db.messageBlockDao.deleteByMessageId(id);
      await _db.messageDao.deleteById(id);
    });
  }

  // --- Message blocks -------------------------------------------------------

  @override
  Future<MessageBlock?> getMessageBlock(String id) =>
      _db.messageBlockDao.getById(id);

  @override
  Future<List<MessageBlock>> getAllMessageBlocks() =>
      _db.messageBlockDao.getAll();

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
