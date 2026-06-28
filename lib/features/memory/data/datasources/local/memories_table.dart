import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/features/memory/data/datasources/local/memory_converters.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';

/// Drift table for long-term memory records. The full [MemoryItem] is stored as
/// a JSON blob in [data]; [kind] / [level] / [ownerId] / [isDeleted] are
/// promoted to scalar columns so scope-filtered recall stays a single indexed
/// query, and [createdAt] backs recency ordering. [kind] / [level] hold the
/// enum wire values (`chat`/`agent`, `global`/`owner`).
@DataClassName('MemoryRow')
@TableIndex(
  name: 'idx_memories_scope',
  columns: {#kind, #level, #ownerId, #isDeleted},
)
@TableIndex(name: 'idx_memories_created', columns: {#createdAt})
class MemoryRows extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get level => text()();
  TextColumn get ownerId => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  TextColumn get data => text().map(const MemoryItemConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
