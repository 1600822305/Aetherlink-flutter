import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/assistants_table.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';

part 'assistant_dao.g.dart';

/// Data-access object for the [AssistantRows] table. Reads/writes whole
/// [Assistant] entities stored as a JSON blob, keyed by id.
@DriftAccessor(tables: [AssistantRows])
class AssistantDao extends DatabaseAccessor<AppDatabase>
    with _$AssistantDaoMixin {
  AssistantDao(super.db);

  Future<List<Assistant>> getAll() async {
    final rows = await select(assistantRows).get();
    return rows.map((row) => row.data).toList();
  }

  Future<Assistant?> getById(String id) async {
    final row = await (select(
      assistantRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.data;
  }

  Future<void> upsert(Assistant assistant) {
    return into(assistantRows).insertOnConflictUpdate(
      AssistantRowsCompanion.insert(id: assistant.id, data: assistant),
    );
  }

  Future<void> deleteById(String id) =>
      (delete(assistantRows)..where((t) => t.id.equals(id))).go();
}
