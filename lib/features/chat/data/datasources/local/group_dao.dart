import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/groups_table.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';

part 'group_dao.g.dart';

/// Data-access object for the [GroupRows] table. Reads/writes whole [Group]
/// entities (stored as a JSON blob) ordered by the derived `orderIndex`.
@DriftAccessor(tables: [GroupRows])
class GroupDao extends DatabaseAccessor<AppDatabase> with _$GroupDaoMixin {
  GroupDao(super.db);

  /// All groups, ascending by display order (the domain `Group.order`).
  Future<List<Group>> getAll() async {
    final rows = await (select(
      groupRows,
    )..orderBy([(t) => OrderingTerm(expression: t.orderIndex)])).get();
    return rows.map((row) => row.data).toList();
  }

  Future<Group?> getById(String id) async {
    final row = await (select(
      groupRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.data;
  }

  Future<void> upsert(Group group) {
    return into(groupRows).insertOnConflictUpdate(
      GroupRowsCompanion.insert(
        id: group.id,
        orderIndex: group.order,
        data: group,
      ),
    );
  }

  Future<void> deleteById(String id) =>
      (delete(groupRows)..where((t) => t.id.equals(id))).go();
}
