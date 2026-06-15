import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/features/chat/data/datasources/local/model_converters.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';

/// Drift table for chat messages. Mirrors the original IndexedDB `messages`
/// store (v9 index `id, topicId, assistantId`): primary key [id], the
/// [topicId] / [assistantId] foreign-key indexes, and the full [Message] as a
/// JSON blob.
@DataClassName('MessageRow')
@TableIndex(name: 'idx_messages_topic_id', columns: {#topicId})
@TableIndex(name: 'idx_messages_assistant_id', columns: {#assistantId})
class MessageRows extends Table {
  TextColumn get id => text()();
  TextColumn get topicId => text()();
  TextColumn get assistantId => text()();
  TextColumn get data => text().map(const MessageConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
