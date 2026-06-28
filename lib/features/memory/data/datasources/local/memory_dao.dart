import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/memory/data/datasources/local/memories_table.dart';
import 'package:aetherlink_flutter/features/memory/data/datasources/local/memory_history_table.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_history.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_scope.dart';

part 'memory_dao.g.dart';

/// Data-access object for the [MemoryRows] table. Reads/writes whole
/// [MemoryItem] entities (stored as a JSON blob) and always filters by scope so
/// chat and agent buckets never mix. Deletes are soft (the row stays for audit
/// / future undo and is excluded from every read).
@DriftAccessor(tables: [MemoryRows, MemoryHistoryRows])
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

  /// Every non-deleted memory of [kind] across all levels (global + each
  /// assistant's private rows), newest first, optionally filtered by a
  /// case-insensitive [query] substring against the content column. Backs the
  /// 搜索全部记忆 page; an empty [query] returns the whole [kind] bucket.
  Future<List<MemoryItem>> searchAll(MemoryKind kind, {String? query}) async {
    final statement = select(memoryRows)
      ..where(
        (t) => t.kind.equals(kind.wire) & t.isDeleted.equals(false),
      );
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

  /// Permanently removes memories that were soft-deleted before [cutoffMillis],
  /// reclaiming space. A memory's deletion time is the newest `DELETE` audit
  /// entry (falling back to its `createdAt` when none was recorded). The purged
  /// memories' audit rows are dropped too, since the memory is gone for good.
  /// Returns how many memories were purged.
  Future<int> purgeSoftDeleted(int cutoffMillis) async {
    final deleted = await (select(memoryRows)
          ..where((t) => t.isDeleted.equals(true)))
        .get();
    if (deleted.isEmpty) return 0;

    // Newest DELETE-audit time per memory, used as the deletion timestamp.
    final maxDeletedAt = memoryHistoryRows.createdAt.max();
    final deleteTimeRows = await (selectOnly(memoryHistoryRows)
          ..addColumns([memoryHistoryRows.memoryId, maxDeletedAt])
          ..where(memoryHistoryRows.action.equals(MemoryAction.delete.wire))
          ..groupBy([memoryHistoryRows.memoryId]))
        .get();
    final deletedAtById = <String, int>{
      for (final row in deleteTimeRows)
        if (row.read(maxDeletedAt) != null)
          row.read(memoryHistoryRows.memoryId)!: row.read(maxDeletedAt)!,
    };

    final expiredIds = <String>[
      for (final row in deleted)
        if ((deletedAtById[row.id] ?? row.createdAt) < cutoffMillis) row.id,
    ];
    if (expiredIds.isEmpty) return 0;

    await (delete(memoryRows)..where((t) => t.id.isIn(expiredIds))).go();
    await (delete(memoryHistoryRows)
          ..where((t) => t.memoryId.isIn(expiredIds)))
        .go();
    return expiredIds.length;
  }

  /// Appends one audit [entry] (ADD/UPDATE/DELETE) to the memory history log.
  Future<void> insertHistory(MemoryHistoryEntry entry) {
    return into(memoryHistoryRows).insert(
      MemoryHistoryRowsCompanion.insert(
        memoryId: entry.memoryId,
        action: entry.action.wire,
        previousValue: Value(entry.previousValue),
        newValue: Value(entry.newValue),
        createdAt: entry.createdAt,
      ),
    );
  }

  /// The audit trail for a single memory [memoryId], newest first.
  Future<List<MemoryHistoryEntry>> historyFor(String memoryId) async {
    final rows = await (select(memoryHistoryRows)
          ..where((t) => t.memoryId.equals(memoryId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ]))
        .get();
    return rows.map(_toEntry).toList();
  }

  /// The most recent [limit] audit entries across every memory, newest first.
  Future<List<MemoryHistoryEntry>> recentHistory({int limit = 100}) async {
    final rows = await (select(memoryHistoryRows)
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(limit < 1 ? 1 : limit))
        .get();
    return rows.map(_toEntry).toList();
  }

  MemoryHistoryEntry _toEntry(MemoryHistoryRow row) => MemoryHistoryEntry(
    id: row.id,
    memoryId: row.memoryId,
    action: MemoryActionWire.parse(row.action),
    previousValue: row.previousValue,
    newValue: row.newValue,
    createdAt: row.createdAt,
  );

  /// Per-owner counts of non-deleted private memories of [kind]: a map from
  /// `ownerId` (assistant id) to the number of memories it owns. Drives the
  /// 按助手查看 index without one query per assistant.
  Future<Map<String, int>> ownerCounts(MemoryKind kind) async {
    final countExp = memoryRows.id.count();
    final rows = await (selectOnly(memoryRows)
          ..addColumns([memoryRows.ownerId, countExp])
          ..where(
            memoryRows.kind.equals(kind.wire) &
                memoryRows.level.equals(MemoryLevel.owner.wire) &
                memoryRows.isDeleted.equals(false),
          )
          ..groupBy([memoryRows.ownerId]))
        .get();
    final result = <String, int>{};
    for (final row in rows) {
      final owner = row.read(memoryRows.ownerId);
      if (owner != null) result[owner] = row.read(countExp) ?? 0;
    }
    return result;
  }
}
