import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// Contract for chat persistence, owned by the `domain` layer and implemented
/// in `data` (dependency inversion; see `docs/ARCHITECTURE.md`).
///
/// Pure Dart: this file must not import Flutter / dio / drift / riverpod. It
/// covers the four chat-core stores carried over from the original IndexedDB
/// schema (topics, messages, message blocks, assistants). Streaming replies and
/// the LLM client land in M2; UI-facing orchestration in M4.
abstract interface class ChatRepository {
  // --- Topics ---------------------------------------------------------------

  Future<List<Topic>> getAllTopics();

  Future<Topic?> getTopic(String id);

  /// Most recently active topics first.
  Future<List<Topic>> getRecentTopics({int limit = 10});

  Future<void> saveTopic(Topic topic);

  /// Deletes a topic together with its messages and their blocks.
  Future<void> deleteTopic(String id);

  // --- Messages -------------------------------------------------------------

  Future<Message?> getMessage(String id);

  /// Every stored message, across all topics. Used by full-database scans such
  /// as 聊天搜索 (port of the web `dexieStorage.messages.toArray()`).
  Future<List<Message>> getAllMessages();

  Future<List<Message>> getMessagesByIds(List<String> ids);

  Future<List<Message>> getMessagesByTopicId(String topicId);

  Future<List<Message>> getMessagesByAssistantId(String assistantId);

  Future<void> saveMessage(Message message);

  Future<void> saveMessages(List<Message> messages);

  /// Deletes a message together with its blocks.
  Future<void> deleteMessage(String id);

  // --- Message blocks -------------------------------------------------------

  Future<MessageBlock?> getMessageBlock(String id);

  /// Every stored message block, across all messages. Used by full-database
  /// scans such as 聊天搜索 (port of the web
  /// `dexieStorage.message_blocks.toArray()`).
  Future<List<MessageBlock>> getAllMessageBlocks();

  /// Blocks for the given ids, in the requested order (missing ids skipped).
  Future<List<MessageBlock>> getMessageBlocksByIds(List<String> ids);

  Future<List<MessageBlock>> getMessageBlocksByMessageId(String messageId);

  Future<void> saveMessageBlock(MessageBlock block);

  Future<void> saveMessageBlocks(List<MessageBlock> blocks);

  Future<void> deleteMessageBlock(String id);

  // --- Assistants -----------------------------------------------------------

  Future<List<Assistant>> getAllAssistants();

  Future<Assistant?> getAssistant(String id);

  Future<void> saveAssistant(Assistant assistant);

  Future<void> deleteAssistant(String id);

  // --- Groups ---------------------------------------------------------------

  /// All sidebar groups (assistant folders and topic folders), ascending by
  /// display order.
  Future<List<Group>> getAllGroups();

  Future<void> saveGroup(Group group);

  Future<void> deleteGroup(String id);

  // --- Settings (key/value) -------------------------------------------------

  /// Reads a persisted preference value, or `null` if unset. Port of the web
  /// `dexieStorage.getSetting` (e.g. `currentAssistant`, the sidebar tab
  /// index).
  Future<String?> getSetting(String key);

  /// Persists a single preference value under [key]. Port of the web
  /// `dexieStorage.saveSetting`.
  Future<void> saveSetting(String key, String value);
}
