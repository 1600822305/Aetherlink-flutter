import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/local/topics_table.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

part 'topic_dao.g.dart';

/// Data-access object for the [TopicRows] table. Reads/writes whole [Topic]
/// entities (stored as a JSON blob) and maintains the derived
/// `lastMessageTimeNum` sort index on write.
@DriftAccessor(tables: [TopicRows])
class TopicDao extends DatabaseAccessor<AppDatabase> with _$TopicDaoMixin {
  TopicDao(super.db);

  Future<List<Topic>> getAll() async {
    final rows = await select(topicRows).get();
    return rows.map((row) => row.data).toList();
  }

  Future<Topic?> getById(String id) async {
    final row = await (select(
      topicRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.data;
  }

  /// Most recently active topics first (descending `lastMessageTimeNum`),
  /// mirroring the original `getRecentTopics` query.
  Future<List<Topic>> getRecent({int limit = 10}) async {
    final rows =
        await (select(topicRows)
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.lastMessageTimeNum,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(limit))
            .get();
    return rows.map((row) => row.data).toList();
  }

  Future<void> upsert(Topic topic) {
    return into(topicRows).insertOnConflictUpdate(
      TopicRowsCompanion.insert(
        id: topic.id,
        lastMessageTimeNum: _lastMessageTimeNum(topic),
        data: topic,
      ),
    );
  }

  Future<void> deleteById(String id) =>
      (delete(topicRows)..where((t) => t.id.equals(id))).go();

  /// Epoch millis used for the `lastMessageTimeNum` sort index. Derived from
  /// `Topic.lastMessageTime`, falling back to `updatedAt` — the same rule the
  /// original `DexieStorageService` used for `_lastMessageTimeNum`.
  static int _lastMessageTimeNum(Topic topic) {
    final raw = topic.lastMessageTime;
    if (raw != null) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return parsed.millisecondsSinceEpoch;
      }
    }
    return topic.updatedAt.millisecondsSinceEpoch;
  }
}
