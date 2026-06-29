import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/messages_table.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';

part 'message_dao.g.dart';

/// Data-access object for the [MessageRows] table. Reads/writes whole [Message]
/// entities stored as a JSON blob, keyed by id and indexed by topic/assistant.
@DriftAccessor(tables: [MessageRows])
class MessageDao extends DatabaseAccessor<AppDatabase> with _$MessageDaoMixin {
  MessageDao(super.db);

  Future<List<Message>> getAll() async {
    final rows = await select(messageRows).get();
    return rows.map((row) => row.data).toList();
  }

  Future<Message?> getById(String id) async {
    final row = await (select(
      messageRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.data;
  }

  Future<List<Message>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await (select(
      messageRows,
    )..where((t) => t.id.isIn(ids))).get();
    return rows.map((row) => row.data).toList();
  }

  /// Content messages of a topic, **excluding the structural virtual root**
  /// (`role = 'root'`). The root is purely structural (message-tree model); no
  /// current display/logic consumer wants it, so filtering here keeps the flat
  /// list identical to before the tree backfill. Tree code that needs the root
  /// uses [getRootByTopicId] (or, later, the dedicated tree queries).
  Future<List<Message>> getByTopicId(String topicId) async {
    final rows = await (select(
      messageRows,
    )..where((t) => t.topicId.equals(topicId))).get();
    return rows
        .map((row) => row.data)
        .where((m) => m.role != MessageRole.root)
        .toList();
  }

  /// The topic's virtual-root message (`role = 'root'`), or null if it has none
  /// yet (pre-backfill). Used by the tree backfill (idempotency guard) and tree
  /// read paths.
  Future<Message?> getRootByTopicId(String topicId) async {
    final row =
        await (select(messageRows)..where(
              (t) => t.topicId.equals(topicId) & t.role.equals('root'),
            ))
            .getSingleOrNull();
    return row?.data;
  }

  Future<List<Message>> getByAssistantId(String assistantId) async {
    final rows = await (select(
      messageRows,
    )..where((t) => t.assistantId.equals(assistantId))).get();
    return rows.map((row) => row.data).toList();
  }

  Future<void> upsert(Message message) {
    return into(messageRows).insertOnConflictUpdate(_companion(message));
  }

  Future<void> upsertAll(List<Message> messages) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(
        messageRows,
        messages.map(_companion).toList(),
      );
    });
  }

  Future<void> deleteById(String id) =>
      (delete(messageRows)..where((t) => t.id.equals(id))).go();

  Future<void> deleteByTopicId(String topicId) =>
      (delete(messageRows)..where((t) => t.topicId.equals(topicId))).go();

  MessageRowsCompanion _companion(Message message) =>
      MessageRowsCompanion.insert(
        id: message.id,
        topicId: message.topicId,
        assistantId: message.assistantId,
        data: message,
        // 树模型列（PR-1）：从实体取值写入真实列，与 data blob 内保持一致。
        // 现阶段 parentId 多为 null（回填在 PR-2），role/siblingsGroupId/createdAt
        // 对新写入即刻可用，但暂无读取方依赖。
        parentId: Value(message.parentId),
        role: Value(message.role.name),
        siblingsGroupId: Value(message.siblingsGroupId),
        createdAt: Value(message.createdAt),
      );
}
