import 'package:drift/drift.dart';

/// Drift table for the memory audit trail. Each row records one ADD / UPDATE /
/// DELETE on a memory (by [memoryId]), keeping the content before/after in
/// [previousValue] / [newValue]. Append-only; rows outlive a soft-deleted memory
/// so the change history survives. [memoryId] is indexed for per-memory lookups
/// and [createdAt] for newest-first ordering.
@DataClassName('MemoryHistoryRow')
@TableIndex(name: 'idx_memory_history_memory', columns: {#memoryId})
@TableIndex(name: 'idx_memory_history_created', columns: {#createdAt})
class MemoryHistoryRows extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get memoryId => text()();
  TextColumn get action => text()();
  TextColumn get previousValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  IntColumn get createdAt => integer()();
}
