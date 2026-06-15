import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
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
      final blockIds = [for (final message in messages) ...message.blocks];
      await _db.messageBlockDao.deleteByIds(blockIds);
      await _db.messageDao.deleteByTopicId(id);
      await _db.topicDao.deleteById(id);
    });
  }

  // --- Messages -------------------------------------------------------------

  @override
  Future<Message?> getMessage(String id) => _db.messageDao.getById(id);

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
      await _db.messageBlockDao.deleteByMessageId(id);
      await _db.messageDao.deleteById(id);
    });
  }

  // --- Message blocks -------------------------------------------------------

  @override
  Future<MessageBlock?> getMessageBlock(String id) =>
      _db.messageBlockDao.getById(id);

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
}
