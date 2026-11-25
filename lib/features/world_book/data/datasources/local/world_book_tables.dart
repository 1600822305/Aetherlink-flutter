import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/features/world_book/data/datasources/local/world_book_converters.dart';

/// 世界书表（schema v20）：一本书一行，条目随书整体存 [data] JSON blob。
///
/// [sortOrder] 是用户排序（也是注入时的书序）；[groupName] 是轻量字符串分组
/// （同名即同组，为空表示未分组），做法同 `KnowledgeBaseRows.groupName`。
@DataClassName('WorldBookRow')
class WorldBookRows extends Table {
  TextColumn get id => text()();
  IntColumn get sortOrder => integer()();
  TextColumn get groupName => text().nullable()();
  TextColumn get data => text().map(const WorldBookConverter())();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
