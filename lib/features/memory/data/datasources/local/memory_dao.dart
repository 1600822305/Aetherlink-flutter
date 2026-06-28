import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/memory/data/datasources/local/memories_table.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_scope.dart';

part 'memory_dao.g.dart';

/// Data-access object for the [MemoryRows] table. Reads/writes whole
/// [MemoryItem] entities (stored as a JSON blob) and always filters by scope so
/// chat and agent buckets never mix. Deletes are soft (the row stays for audit
/// / future undo and is excluded from every read).
@DriftAccessor(tables: [MemoryRows])
class MemoryDao extends DatabaseAccessor<AppDatabase> with _$MemoryDaoMixin {
  MemoryDao(super.db);

  Expression<bool> _scopeFilter(MemoryScope scope) {
    var predicate = memoryRows.kind.equals(scope.kind.wire) &
        memoryRows.level.equals(scope.level.wire) &
        memoryRows.isDeleted.equals(false);
    if (scope.ownerId != null) {
      predicate = predicate & memoryRows.ownerId.equals(scope.ownerId!);
    }
    return predicate;
  }

  /// Memories in [scope], newest first, optionally filtered by a case-insensitive
  /// [query] substring against the content column.
  Future<List<MemoryItem>> list(MemoryScope scope, {String? query}) async {
    final statement = select(memoryRows)..where((_) => _scopeFilter(scope));
    final trimmed = query?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      statement.where((t) => t.data.like('%$trimmed%'));
    }
    statement.orderBy([
      (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
    ]);
    final rows = await statement.get();
    return rows.map((row) => row.data).toList();
  }

  Future<MemoryItem?> getById(String id) async {
    final row = await (select(
      memoryRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.data;
  }

  /// Inserts or updates a memory, keeping the promoted scope columns in sync
  /// with the entity.
  Future<void> upsert(MemoryItem item) {
    return into(memoryRows).insertOnConflictUpdate(
      MemoryRowsCompanion.insert(
        id: item.id,
        kind: item.kind.wire,
        level: item.level.wire,
        ownerId: Value(item.ownerId),
        createdAt: item.createdAt,
        data: item,
      ),
    );
  }

  /// Marks a memory deleted (excluded from every read) without removing the row.
  Future<void> softDelete(String id) {
    return (update(memoryRows)..where((t) => t.id.equals(id))).write(
      const MemoryRowsCompanion(isDeleted: Value(true)),
    );
  }

  /// Number of non-deleted memories matching [scope] (ownerId ignored when null,
  /// so a chat-global scope counts only global rows).
  Future<int> count(MemoryScope scope) async {
    final countExp = memoryRows.id.count();
    final statement = selectOnly(memoryRows)
      ..addColumns([countExp])
      ..where(_scopeFilter(scope));
    final row = await statement.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Number of non-deleted memories of [kind] across every level.
  Future<int> countByKind(MemoryKind kind) async {
    final countExp = memoryRows.id.count();
    final statement = selectOnly(memoryRows)
      ..addColumns([countExp])
      ..where(
        memoryRows.kind.equals(kind.wire) &
            memoryRows.isDeleted.equals(false),
      );
    final row = await statement.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Distinct owning-assistant ids that have at least one non-deleted private
  /// chat memory.
  Future<int> distinctOwnerCount(MemoryKind kind) async {
    final rows = await (selectOnly(memoryRows, distinct: true)
          ..addColumns([memoryRows.ownerId])
          ..where(
            memoryRows.kind.equals(kind.wire) &
                memoryRows.level.equals(MemoryLevel.owner.wire) &
                memoryRows.isDeleted.equals(false),
          ))
        .get();
    return rows
        .map((r) => r.read(memoryRows.ownerId))
        .whereType<String>()
        .toSet()
        .length;
  }
}
