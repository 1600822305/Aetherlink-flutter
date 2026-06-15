import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/features/chat/data/datasources/local/model_converters.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';

/// Drift table for message blocks. Mirrors the original IndexedDB
/// `message_blocks` store (v9 index `id, messageId`): primary key [id], the
/// [messageId] foreign-key index, and the full [MessageBlock] (any of the 15
/// union variants) as a JSON blob.
@DataClassName('MessageBlockRow')
@TableIndex(name: 'idx_message_blocks_message_id', columns: {#messageId})
class MessageBlockRows extends Table {
  TextColumn get id => text()();
  TextColumn get messageId => text()();
  TextColumn get data => text().map(const MessageBlockConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
