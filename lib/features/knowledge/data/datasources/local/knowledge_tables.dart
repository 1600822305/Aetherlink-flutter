import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/features/knowledge/data/datasources/local/knowledge_converters.dart';

/// 知识库权威元数据表（设计文档 §4.1）。一个 Drift 库内的分层表，替代 Cherry
/// Studio「每库一个 index.sqlite」的多文件方案，避免移动端的句柄/管理开销。
///
/// [embeddingModelKey] / [dimensions] / [threshold] 在 P0 关键词模式下为空，
/// P1 接入嵌入后写入并锁定；提前建列以免 P1 再迁移一次。
@DataClassName('KnowledgeBaseRow')
class KnowledgeBaseRows extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get embeddingModelKey => text().nullable()();
  IntColumn get dimensions => integer().nullable()();
  IntColumn get chunkSize => integer().withDefault(const Constant(1000))();
  IntColumn get chunkOverlap => integer().withDefault(const Constant(200))();
  TextColumn get searchMode => text().withDefault(const Constant('keyword'))();
  RealColumn get threshold => real().nullable()();
  IntColumn get topK => integer().withDefault(const Constant(5))();
  TextColumn get scope => text().map(const KnowledgeScopeConverter())();
  TextColumn get status => text().withDefault(const Constant('idle'))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 知识库条目元数据表（设计文档 §4.1）。正文另存 [KnowledgeContentRows]。
@DataClassName('KnowledgeItemRow')
@TableIndex(name: 'idx_knowledge_item_base', columns: {#baseId})
class KnowledgeItemRows extends Table {
  TextColumn get id => text()();
  TextColumn get baseId => text()();
  TextColumn get type => text()();
  TextColumn get source => text()();
  TextColumn get conceptId => text()();
  TextColumn get title => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('idle'))();
  TextColumn get error => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 条目正文表（设计文档 §4.2）。P0 只处理小文本（note / txt / md），正文直接
/// 内联存 [content] 列；大文件落盘策略与 [contentHash] 复合去重键留待 P1/P3。
@DataClassName('KnowledgeContentRow')
class KnowledgeContentRows extends Table {
  TextColumn get itemId => text()();
  TextColumn get content => text()();
  TextColumn get contentHash => text()();

  @override
  Set<Column<Object>> get primaryKey => {itemId};
}

/// 派生切块表（设计文档 §4.3，可从正文重建）。P0 只用它做关键词检索
/// （`LIKE` on [content]）；`embeddingKey` 等向量相关列在 P1 补上。
///
/// 保持不变式 `KnowledgeContentRows.content.substring(charStart, charEnd)
/// == content`。
@DataClassName('KbChunkRow')
@TableIndex(name: 'idx_kb_chunk_base', columns: {#baseId})
@TableIndex(name: 'idx_kb_chunk_item', columns: {#itemId})
class KbChunkRows extends Table {
  TextColumn get chunkId => text()();
  TextColumn get baseId => text()();
  TextColumn get itemId => text()();
  IntColumn get unitIndex => integer()();
  IntColumn get charStart => integer()();
  IntColumn get charEnd => integer()();
  TextColumn get content => text()();
  TextColumn get contentHash => text()();

  @override
  Set<Column<Object>> get primaryKey => {chunkId};
}
