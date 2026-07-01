import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/knowledge/data/datasources/local/knowledge_tables.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_chunking.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_item.dart';

part 'knowledge_dao.g.dart';

/// Data-access object for the knowledge-base tables (设计文档 §4)。摄取写入走
/// 单个 Drift 事务（条目 + 正文 + 切块一起提交），删除按 `baseId` / `itemId`
/// 级联清理派生数据。P0 只覆盖权威三表 + `kb_chunk`；向量派生表在 P1 加入。
@DriftAccessor(
  tables: [
    KnowledgeBaseRows,
    KnowledgeItemRows,
    KnowledgeContentRows,
    KbChunkRows,
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
  /// chunks), in one transaction.
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
  });

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

  Future<String?> readItemContent(String itemId) async {
    final row = await (select(
      knowledgeContentRows,
    )..where((t) => t.itemId.equals(itemId))).getSingleOrNull();
    return row?.content;
  }

  /// Ingests one item's authoritative rows plus its derived chunks in a single
  /// transaction: `knowledge_item` (status → completed) + `knowledge_content` +
  /// the freshly-computed `kb_chunk` slices. Keyword search runs off the chunks.
  Future<void> insertItemWithChunks({
    required KnowledgeItem item,
    required String text,
    required String contentHash,
    required List<TextChunk> chunks,
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
