import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/message_blocks_table.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';

part 'message_block_dao.g.dart';

/// Data-access object for the [MessageBlockRows] table. Reads/writes whole
/// [MessageBlock] entities (any of the 15 union variants) as a JSON blob,
/// keyed by id and indexed by message.
@DriftAccessor(tables: [MessageBlockRows])
class MessageBlockDao extends DatabaseAccessor<AppDatabase>
    with _$MessageBlockDaoMixin {
  MessageBlockDao(super.db);

  Future<MessageBlock?> getById(String id) async {
    final row = await (select(
      messageBlockRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.data;
  }

  /// Blocks for the given ids, preserving the requested order and skipping ids
  /// with no stored block (mirrors the original `getMessageBlocksByIds`).
  Future<List<MessageBlock>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await (select(
      messageBlockRows,
    )..where((t) => t.id.isIn(ids))).get();
    final byId = {for (final row in rows) row.id: row.data};
    return [
      for (final id in ids)
        if (byId.containsKey(id)) byId[id]!,
    ];
  }

  Future<List<MessageBlock>> getByMessageId(String messageId) async {
    final rows = await (select(
      messageBlockRows,
    )..where((t) => t.messageId.equals(messageId))).get();
    return rows.map((row) => row.data).toList();
  }

  Future<void> upsert(MessageBlock block) {
    return into(messageBlockRows).insertOnConflictUpdate(_companion(block));
  }

  Future<void> upsertAll(List<MessageBlock> blocks) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(
        messageBlockRows,
        blocks.map(_companion).toList(),
      );
    });
  }

  Future<void> deleteById(String id) =>
      (delete(messageBlockRows)..where((t) => t.id.equals(id))).go();

  Future<void> deleteByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    await (delete(messageBlockRows)..where((t) => t.id.isIn(ids))).go();
  }

  Future<void> deleteByMessageId(String messageId) => (delete(
    messageBlockRows,
  )..where((t) => t.messageId.equals(messageId))).go();

  MessageBlockRowsCompanion _companion(MessageBlock block) =>
      MessageBlockRowsCompanion.insert(
        id: block.id,
        messageId: block.messageId,
        data: block,
      );
}
