import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/knowledge/data/datasources/local/knowledge_tables.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_chunking.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_embedding.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_item.dart';

part 'knowledge_dao.g.dart';

/// Data-access object for the knowledge-base tables (设计文档 §4)。摄取写入走
/// 单个 Drift 事务（条目 + 正文 + 切块 [+ 向量] 一起提交），删除按 `baseId` /
/// `itemId` 级联清理派生数据。P1 起额外覆盖 `kb_embedding` 持久向量表。
@DriftAccessor(
  tables: [
    KnowledgeBaseRows,
    KnowledgeItemRows,
    KnowledgeContentRows,
    KbChunkRows,
    KbEmbeddingRows,
  ],
)
class KnowledgeDao extends DatabaseAccessor<AppDatabase>
    with _$KnowledgeDaoMixin {
  KnowledgeDao(super.db);

  // ── knowledge_base ──

  Future<void> createBase(KnowledgeBase base) {
    return into(knowledgeBaseRows).insert(
      KnowledgeBaseRowsCompanion.insert(
        id: base.id,
        name: base.name,
        embeddingModelKey: Value(base.embeddingModelKey),
        dimensions: Value(base.dimensions),
        chunkSize: Value(base.chunkSize),
        chunkOverlap: Value(base.chunkOverlap),
        searchMode: Value(base.searchMode.name),
        threshold: Value(base.threshold),
        topK: Value(base.topK),
        scope: base.scope,
        status: Value(base.status.name),
        createdAt: base.createdAt.millisecondsSinceEpoch,
      ),
    );
  }

  Future<List<KnowledgeBase>> listBases() async {
    final rows = await (select(knowledgeBaseRows)
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
    return rows.map(_toBase).toList();
  }

  Future<KnowledgeBase?> getBase(String id) async {
    final row = await (select(
      knowledgeBaseRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toBase(row);
  }

  Future<void> updateBaseStatus(String id, KnowledgeBaseStatus status) {
    return (update(knowledgeBaseRows)..where((t) => t.id.equals(id))).write(
      KnowledgeBaseRowsCompanion(status: Value(status.name)),
    );
  }

  /// Deletes a base and every derived row hanging off it (items / content /
  /// chunks), in one transaction. `kb_embedding` 是按 `embeddingKey`
  /// (`sha256(模型键|内容哈希)`) 全局去重的共享缓存，可能被其它库的切块引用，
  /// 所以不按库删，而是删完切块后回收「已无任何切块引用」的孤儿嵌入行。
  Future<void> deleteBase(String id) => transaction(() async {
    final items = await (select(
      knowledgeItemRows,
    )..where((t) => t.baseId.equals(id))).get();
    for (final item in items) {
      await (delete(
        knowledgeContentRows,
      )..where((t) => t.itemId.equals(item.id))).go();
    }
    await (delete(kbChunkRows)..where((t) => t.baseId.equals(id))).go();
    await (delete(knowledgeItemRows)..where((t) => t.baseId.equals(id))).go();
    await (delete(knowledgeBaseRows)..where((t) => t.id.equals(id))).go();
    await _deleteOrphanEmbeddings();
  });

  /// Removes `kb_embedding` rows whose `embeddingKey` is no longer referenced by
  /// any surviving chunk — a safe GC that preserves cross-base dedup reuse.
  Future<void> _deleteOrphanEmbeddings() async {
    final referenced = selectOnly(kbChunkRows, distinct: true)
      ..addColumns([kbChunkRows.embeddingKey])
      ..where(kbChunkRows.embeddingKey.isNotNull());
    await (delete(kbEmbeddingRows)
          ..where((t) => t.embeddingKey.isNotInQuery(referenced)))
        .go();
  }

  // ── knowledge_item ──

  Future<List<KnowledgeItem>> listItems(String baseId) async {
    final rows = await (select(knowledgeItemRows)
          ..where((t) => t.baseId.equals(baseId))
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
    return rows.map(_toItem).toList();
  }

  Future<int> countItems(String baseId) async {
    final count = knowledgeItemRows.id.count();
    final query = selectOnly(knowledgeItemRows)
      ..addColumns([count])
      ..where(knowledgeItemRows.baseId.equals(baseId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<KnowledgeItem?> getItem(String itemId) async {
    final row = await (select(
      knowledgeItemRows,
    )..where((t) => t.id.equals(itemId))).getSingleOrNull();
    return row == null ? null : _toItem(row);
  }

  Future<String?> readItemContent(String itemId) async {
    final row = await (select(
      knowledgeContentRows,
    )..where((t) => t.itemId.equals(itemId))).getSingleOrNull();
    return row?.content;
  }

  /// Ingests one item's authoritative rows plus its derived chunks in a single
  /// transaction: `knowledge_item` (status → completed) + `knowledge_content` +
  /// the freshly-computed `kb_chunk` slices. Keyword search runs off the chunks.
  /// [chunkEmbeddingKeys] 把 `chunk.unitIndex` 映射到该切块的 `embeddingKey`
  /// （关键词库为空）；[embeddings] 是本次要落库的 `embeddingKey → 向量`（调用方
  /// 已按 [existingEmbeddingKeys] 去重，只传缺失的），一并写入 `kb_embedding`。
  Future<void> insertItemWithChunks({
    required KnowledgeItem item,
    required String text,
    required String contentHash,
    required List<TextChunk> chunks,
    Map<int, String>? chunkEmbeddingKeys,
    Map<String, List<double>>? embeddings,
  }) => transaction(() async {
    await into(knowledgeItemRows).insert(
      KnowledgeItemRowsCompanion.insert(
        id: item.id,
        baseId: item.baseId,
        type: item.type.name,
        source: item.source,
        conceptId: item.conceptId,
        title: Value(item.title),
        status: Value(item.status.name),
        error: Value(item.error),
        createdAt: item.createdAt.millisecondsSinceEpoch,
      ),
    );
    await into(knowledgeContentRows).insert(
      KnowledgeContentRowsCompanion.insert(
        itemId: item.id,
        content: text,
        contentHash: contentHash,
      ),
    );
    for (final chunk in chunks) {
      await into(kbChunkRows).insert(
        KbChunkRowsCompanion.insert(
          chunkId: '${item.id}#${chunk.unitIndex}',
          baseId: item.baseId,
          itemId: item.id,
          unitIndex: chunk.unitIndex,
          charStart: chunk.charStart,
          charEnd: chunk.charEnd,
          content: chunk.text,
          contentHash: contentHash,
          embeddingKey: Value(chunkEmbeddingKeys?[chunk.unitIndex]),
        ),
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in (embeddings ?? const {}).entries) {
      // insertOnConflictUpdate：跨条目/跨库共享同一 embeddingKey 时幂等复用。
      await into(kbEmbeddingRows).insertOnConflictUpdate(
        KbEmbeddingRowsCompanion.insert(
          embeddingKey: entry.key,
          dimensions: entry.value.length,
          vector: encodeVector(entry.value),
          createdAt: now,
        ),
      );
    }
  });

  // ── keyword search (设计文档 §6) ──

  /// Chunks in [baseId] whose text contains ANY of [tokens] (case-insensitive
  /// `LIKE`), restricted to items that finished ingesting (`completed`).
  /// Scoring / topK trimming happens in the service layer.
  Future<List<KbChunkRow>> searchChunks(
    String baseId,
    List<String> tokens,
  ) async {
    if (tokens.isEmpty) return const [];
    final completedItemIds = selectOnly(knowledgeItemRows)
      ..addColumns([knowledgeItemRows.id])
      ..where(
        knowledgeItemRows.baseId.equals(baseId) &
            knowledgeItemRows.status.equals(
              KnowledgeItemStatus.completed.name,
            ),
      );

    Expression<bool> anyToken = const Constant(false);
    for (final token in tokens) {
      anyToken = anyToken | kbChunkRows.content.like('%$token%');
    }

    final query = select(kbChunkRows)
      ..where(
        (t) => t.baseId.equals(baseId) &
            t.itemId.isInQuery(completedItemIds) &
            anyToken,
      )
      ..orderBy([(t) => OrderingTerm(expression: t.unitIndex)]);
    return query.get();
  }

  // ── vector search (设计文档 §6 vector / hybrid) ──

  /// 某库所有「已完成条目 + 已嵌入（`embeddingKey` 非空）」的切块，供向量检索取回
  /// 后在 Dart 侧算 cosine。不带 token 过滤——语义检索靠向量而非字面命中。
  Future<List<KbChunkRow>> embeddedChunks(String baseId) async {
    final completedItemIds = selectOnly(knowledgeItemRows)
      ..addColumns([knowledgeItemRows.id])
      ..where(
        knowledgeItemRows.baseId.equals(baseId) &
            knowledgeItemRows.status.equals(
              KnowledgeItemStatus.completed.name,
            ),
      );
    final query = select(kbChunkRows)
      ..where(
        (t) => t.baseId.equals(baseId) &
            t.itemId.isInQuery(completedItemIds) &
            t.embeddingKey.isNotNull(),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.unitIndex)]);
    return query.get();
  }

  /// 取回一批 `embeddingKey` 对应的向量（缺失的键不出现在结果里）。
  Future<Map<String, List<double>>> getEmbeddings(Iterable<String> keys) async {
    final keyList = keys.toSet().toList();
    if (keyList.isEmpty) return const {};
    final rows = await (select(
      kbEmbeddingRows,
    )..where((t) => t.embeddingKey.isIn(keyList))).get();
    return {
      for (final row in rows) row.embeddingKey: decodeVector(row.vector),
    };
  }

  /// 已存在于 `kb_embedding` 的键子集，供摄取前去重（不重复调用嵌入 API）。
  Future<Set<String>> existingEmbeddingKeys(Iterable<String> keys) async {
    final keyList = keys.toSet().toList();
    if (keyList.isEmpty) return const {};
    final query = selectOnly(kbEmbeddingRows)
      ..addColumns([kbEmbeddingRows.embeddingKey])
      ..where(kbEmbeddingRows.embeddingKey.isIn(keyList));
    final rows = await query.get();
    return rows.map((r) => r.read(kbEmbeddingRows.embeddingKey)!).toSet();
  }

  // ── mapping ──

  KnowledgeBase _toBase(KnowledgeBaseRow row) => KnowledgeBase(
    id: row.id,
    name: row.name,
    embeddingModelKey: row.embeddingModelKey,
    dimensions: row.dimensions,
    chunkSize: row.chunkSize,
    chunkOverlap: row.chunkOverlap,
    searchMode: KnowledgeSearchMode.fromName(row.searchMode),
    threshold: row.threshold,
    topK: row.topK,
    scope: row.scope,
    status: KnowledgeBaseStatus.fromName(row.status),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
  );

  KnowledgeItem _toItem(KnowledgeItemRow row) => KnowledgeItem(
    id: row.id,
    baseId: row.baseId,
    type: KnowledgeItemType.fromName(row.type),
    source: row.source,
    conceptId: row.conceptId,
    title: row.title,
    status: KnowledgeItemStatus.fromName(row.status),
    error: row.error,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
  );
}
