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

  /// 云端文件预处理器 id（设计文档 §5.2 云端预处理轨，P3e 起）。为空走本地解析轨。
  TextColumn get fileProcessorId => text().nullable()();

  /// 所属分组名（功能缺口⑦）。轻量字符串分组：同名即同组，为空表示未分组。
  TextColumn get groupName => text().nullable()();

  /// 重排序模型 key（功能缺口⑥），`providerId\0modelId` 编码同
  /// [embeddingModelKey]。为空不重排，检索保持原排序。
  TextColumn get rerankModelKey => text().nullable()();

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

  /// 来源指纹快照（JSON，设计文档 §8.1）。仅 workspace 条目写入摄取时的
  /// `{path, mtime, size}`，供 staleness 检测异步比对；其它来源为空。P3c 起新增。
  TextColumn get sourceFingerprint => text().nullable()();

  IntColumn get createdAt => integer()();

  /// 软删除时间戳（功能缺口⑩ 回收站）。非空表示在回收站里：列表 / 检索 /
  /// 重建均排除，正文保留以便恢复。
  IntColumn get deletedAt => integer().nullable()();

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

/// 派生切块表（设计文档 §4.3，可从正文重建）。关键词检索走 `LIKE` on [content]；
/// 向量检索走 [embeddingKey]——它指向 [KbEmbeddingRows] 里的向量（P0 关键词模式下
/// 为空，P1 摄取时按需回填）。
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

  /// 复合去重键 `sha256(embeddingModelKey|sha256(content))`（设计文档 §4.3）。
  /// 关键词库或尚未嵌入的切块为空。
  TextColumn get embeddingKey => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {chunkId};
}

/// 向量存储（设计文档 §4.3）。按 [embeddingKey] 去重：同一段文本在同一嵌入模型下
/// 只嵌入一次（§A4：不变内容不重复扣费），不同模型（维度不同）因模型键不同天然隔离。
///
/// 向量以 JSON 编码的 `List<double>` 存于 [vector]；[dimensions] 便于校验/按维度归类。
/// 这是权威的持久向量层——检索时从此表取回向量在 Dart 侧算 cosine（sqlite-vec 原生
/// 索引作为后续可选加速项）。
@DataClassName('KbEmbeddingRow')
class KbEmbeddingRows extends Table {
  TextColumn get embeddingKey => text()();
  IntColumn get dimensions => integer()();
  TextColumn get vector => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {embeddingKey};
}
