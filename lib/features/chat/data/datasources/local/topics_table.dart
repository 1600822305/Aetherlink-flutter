import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/features/chat/data/datasources/local/model_converters.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// Drift table for chat topics. Mirrors the original IndexedDB `topics` store
/// (v9 index `id, _lastMessageTimeNum`): primary key [id], a numeric
/// [lastMessageTimeNum] sort index, and the full [Topic] as a JSON blob.
///
/// [lastMessageTimeNum] is derived on write (it is not part of the domain
/// model) — epoch millis of `Topic.lastMessageTime` (falling back to
/// `updatedAt`), exactly like the original `_lastMessageTimeNum` index.
@DataClassName('TopicRow')
@TableIndex(
  name: 'idx_topics_last_message_time_num',
  columns: {#lastMessageTimeNum},
)
class TopicRows extends Table {
  TextColumn get id => text()();
  IntColumn get lastMessageTimeNum => integer()();
  TextColumn get data => text().map(const TopicConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
