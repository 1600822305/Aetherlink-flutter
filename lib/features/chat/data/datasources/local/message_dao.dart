import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/messages_table.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';

part 'message_dao.g.dart';

/// Data-access object for the [MessageRows] table. Reads/writes whole [Message]
/// entities stored as a JSON blob, keyed by id and indexed by topic/assistant.
@DriftAccessor(tables: [MessageRows])
class MessageDao extends DatabaseAccessor<AppDatabase> with _$MessageDaoMixin {
  MessageDao(super.db);

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

  Future<List<Message>> getByTopicId(String topicId) async {
    final rows = await (select(
      messageRows,
    )..where((t) => t.topicId.equals(topicId))).get();
    return rows.map((row) => row.data).toList();
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
      );
}
