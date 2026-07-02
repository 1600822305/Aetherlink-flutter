import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/search/chat_search.dart';
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

  /// The topic's messages in **display order**, derived from the message tree:
  /// the active path (from `topic.activeNodeId` up to the virtual root) with each
  /// path node's multi-model sibling group inlined. The virtual root is excluded.
  /// Falls back to a chronological sort if the tree can't produce a faithful
  /// projection, so the displayed set never loses a message.
  Future<List<Message>> getBranchMessages(String topicId);

  Future<List<Message>> getMessagesByAssistantId(String assistantId);

  Future<void> saveMessage(Message message);

  Future<void> saveMessages(List<Message> messages);

  /// Deletes a message together with its blocks. Tree-aware (message-tree
  /// model): with [cascade] false (default) the node's children are reparented
  /// onto its parent so the conversation stays connected; with [cascade] true
  /// the whole subtree is removed. `topic.activeNodeId` is fixed up if it
  /// pointed at a removed node. The virtual root cannot be deleted this way.
  Future<void> deleteMessage(String id, {bool cascade = false});

  /// Sets the topic's active leaf (the displayed branch). Pass null to clear.
  Future<void> setActiveNode(String topicId, String? nodeId);

  /// Content children of [parentId] within a topic (excludes the virtual root),
  /// chronologically ordered.
  Future<List<Message>> getChildren(String topicId, String parentId);

  /// The topic's virtual-root message id, or null if it has none.
  Future<String?> getRootMessageId(String topicId);

  /// Deletes every non-root message of the topic and clears `activeNodeId`,
  /// keeping the content-less virtual root.
  Future<void> clearTopicMessages(String topicId);

  // --- Message blocks -------------------------------------------------------

  Future<MessageBlock?> getMessageBlock(String id);

  /// Every `main_text` block's (messageId, content), across all messages —
  /// filtered and projected at the SQL layer so 聊天搜索's full-database scan
  /// never loads image/file 块（含内联 base64）into memory.
  Future<List<ChatSearchableText>> getAllMainTexts();

  /// Blocks for the given ids, in the requested order (missing ids skipped).
  Future<List<MessageBlock>> getMessageBlocksByIds(List<String> ids);

  Future<List<MessageBlock>> getMessageBlocksByMessageId(String messageId);

  Future<void> saveMessageBlock(MessageBlock block);

  Future<void> saveMessageBlocks(List<MessageBlock> blocks);

  /// Atomically replaces every block of [messageId] with [blocks] (in order)
  /// and saves [message] (when given), all in one transaction — a mid-write
  /// crash can never leave the reply with deleted-but-not-rewritten blocks.
  Future<void> replaceMessageBlocks({
    required String messageId,
    required List<MessageBlock> blocks,
    Message? message,
  });

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

  // --- Transactions ---------------------------------------------------------

  /// Runs [action] inside a single database transaction.
  Future<T> runInTransaction<T>(Future<T> Function() action);
}
