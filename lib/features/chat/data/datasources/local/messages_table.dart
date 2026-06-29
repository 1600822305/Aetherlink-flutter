import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/features/chat/data/datasources/local/model_converters.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';

/// Drift table for chat messages. Mirrors the original IndexedDB `messages`
/// store (v9 index `id, topicId, assistantId`): primary key [id], the
/// [topicId] / [assistantId] foreign-key indexes, and the full [Message] as a
/// JSON blob.
///
/// 消息树模型（见 `docs/design/message-tree-model-design.md`）把 [parentId] /
/// [role] / [siblingsGroupId] / [createdAt] 从 JSON blob 提升为真实列（值仍冗余
/// 在 [data] 内，保持单一实体序列化不变），以支持建树查询与排序。PR-1 仅新增列 +
/// `parentId` 普通索引，不回填、不加偏唯一索引/CHECK/FK（那些放到回填之后，避免
/// 老数据 parentId 全为 NULL 时立刻违反唯一性）。
@DataClassName('MessageRow')
@TableIndex(name: 'idx_messages_topic_id', columns: {#topicId})
@TableIndex(name: 'idx_messages_assistant_id', columns: {#assistantId})
@TableIndex(name: 'idx_messages_parent_id', columns: {#parentId})
class MessageRows extends Table {
  TextColumn get id => text()();
  TextColumn get topicId => text()();
  TextColumn get assistantId => text()();
  TextColumn get data => text().map(const MessageConverter())();

  // 树模型列（PR-1 引入，nullable / 带默认，便于 addColumn 且不读取）。
  TextColumn get parentId => text().nullable()();
  TextColumn get role => text().nullable()();
  IntColumn get siblingsGroupId => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
