import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/world_book/data/datasources/local/world_book_tables.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';

part 'world_book_dao.g.dart';

/// Data-access object for [WorldBookRows].
@DriftAccessor(tables: [WorldBookRows])
class WorldBookDao extends DatabaseAccessor<AppDatabase>
    with _$WorldBookDaoMixin {
  WorldBookDao(super.db);

  Future<List<WorldBook>> listBooks() async {
    final rows =
        await (select(worldBookRows)..orderBy([
              (t) => OrderingTerm(expression: t.sortOrder),
              (t) => OrderingTerm(expression: t.updatedAt),
            ]))
            .get();
    return rows.map(_toBook).toList();
  }

  Future<WorldBook?> getBook(String id) async {
    final row = await _row(id);
    return row == null ? null : _toBook(row);
  }

  /// 新增或整本覆盖。已存在的书保持原排序位，新书排到末尾。
  Future<void> upsertBook(WorldBook book) => transaction(() async {
    final existing = await _row(book.id);
    final sortOrder = existing?.sortOrder ?? await _nextSortOrder();
    await into(worldBookRows).insertOnConflictUpdate(
      WorldBookRowsCompanion.insert(
        id: book.id,
        sortOrder: sortOrder,
        groupName: Value(_cleanGroup(book.groupName)),
        data: book,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  });

  Future<void> deleteBook(String id) =>
      (delete(worldBookRows)..where((t) => t.id.equals(id))).go();

  /// 按 [orderedIds] 的下标重写排序位（单事务）。
  Future<void> reorder(List<String> orderedIds) => transaction(() async {
    for (var i = 0; i < orderedIds.length; i++) {
      await (update(worldBookRows)..where((t) => t.id.equals(orderedIds[i])))
          .write(WorldBookRowsCompanion(sortOrder: Value(i)));
    }
  });

  Future<void> updateGroup(String id, String? groupName) {
    return (update(worldBookRows)..where((t) => t.id.equals(id))).write(
      WorldBookRowsCompanion(groupName: Value(_cleanGroup(groupName))),
    );
  }

  Future<int> renameGroup(String from, String to) {
    return (update(worldBookRows)..where((t) => t.groupName.equals(from)))
        .write(WorldBookRowsCompanion(groupName: Value(_cleanGroup(to))));
  }

  Future<int> dissolveGroup(String name) {
    return (update(worldBookRows)..where((t) => t.groupName.equals(name)))
        .write(const WorldBookRowsCompanion(groupName: Value(null)));
  }

  Future<WorldBookRow?> _row(String id) => (select(
    worldBookRows,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> _nextSortOrder() async {
    final maxOrder = worldBookRows.sortOrder.max();
    final row = await (selectOnly(
      worldBookRows,
    )..addColumns([maxOrder])).getSingle();
    return (row.read(maxOrder) ?? -1) + 1;
  }

  static String? _cleanGroup(String? name) {
    final trimmed = name?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static WorldBook _toBook(WorldBookRow row) =>
      row.data.copyWith(id: row.id, groupName: row.groupName);
}
