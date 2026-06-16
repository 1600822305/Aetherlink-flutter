import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/features/chat/data/datasources/local/model_converters.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';

/// Drift table for sidebar groups (assistant folders and per-assistant topic
/// folders). Mirrors the original IndexedDB `groups` store: primary key [id], a
/// numeric [orderIndex] sort column (the domain `Group.order`), and the full
/// [Group] as a JSON blob.
@DataClassName('GroupRow')
@TableIndex(name: 'idx_groups_order', columns: {#orderIndex})
class GroupRows extends Table {
  TextColumn get id => text()();
  IntColumn get orderIndex => integer()();
  TextColumn get data => text().map(const GroupConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
