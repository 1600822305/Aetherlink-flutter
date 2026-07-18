import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/knowledge/data/datasources/local/knowledge_tables.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_chunking.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_embedding.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_item.dart';

part 'knowledge_dao.g.dart';

/// 一个条目连同其权威正文（[itemsWithContent] 的返回单元）。重索引据此从正文
/// 无损重建派生切块。
class KnowledgeItemWithContent {
  const KnowledgeItemWithContent({
    required this.item,
    required this.content,
    required this.contentHash,
  });

  final KnowledgeItem item;
  final String content;
  final String contentHash;
}

/// [KnowledgeDao.reindexBase] 的每条目重建单元：服务层已重新切块并把 `unitIndex`
/// 映射到（可空的）`embeddingKey`，DAO 只负责在事务里落库。
class ReindexItem {
  const ReindexItem({
    required this.itemId,
    required this.contentHash,
    required this.chunks,
    this.embeddingKeys,
  });

  final String itemId;
  final String contentHash;
  final List<TextChunk> chunks;
  final Map<int, String>? embeddingKeys;
}

/// 知识库派生数据的存储占用汇总（设计文档 §11.1 存储配额）。[contentBytes] 为权威
/// 正文的 UTF-8 字节数，[chunkBytes] / [embeddingBytes] 为派生索引占用（可通过
/// 重建回收/再生）。
class KnowledgeStorageStats {
  const KnowledgeStorageStats({
    required this.baseCount,
    required this.itemCount,
    required this.contentBytes,
    required this.chunkCount,
    required this.chunkBytes,
    required this.embeddingCount,
    required this.embeddingBytes,
  });

  final int baseCount;
  final int itemCount;
  final int contentBytes;
  final int chunkCount;
  final int chunkBytes;
  final int embeddingCount;
  final int embeddingBytes;

  int get totalBytes => contentBytes + chunkBytes + embeddingBytes;
}

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
        chunkStrategy: Value(base.chunkStrategy.name),
        chunkSeparator: Value(base.chunkSeparator),
        searchMode: Value(base.searchMode.name),
        threshold: Value(base.threshold),
        topK: Value(base.topK),
        scope: base.scope,
        status: Value(base.status.name),
        createdAt: base.createdAt.millisecondsSinceEpoch,
        fileProcessorId: Value(base.fileProcessorId),
        groupName: Value(base.groupName),
        rerankModelKey: Value(base.rerankModelKey),
      ),
    );
  }

  Future<List<KnowledgeBase>> listBases() async {
    final rows =
        await (select(knowledgeBaseRows)..orderBy([
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

  /// 更新库的所属分组（功能缺口⑦）；传 null 移出分组。
  Future<void> updateBaseGroup(String id, String? groupName) {
    return (update(knowledgeBaseRows)..where((t) => t.id.equals(id))).write(
      KnowledgeBaseRowsCompanion(groupName: Value(groupName)),
    );
  }

  /// 重命名分组：把组内所有库的分组名改为 [to]。返回受影响的库数。
  Future<int> renameGroup(String from, String to) {
    return (update(knowledgeBaseRows)..where((t) => t.groupName.equals(from)))
        .write(KnowledgeBaseRowsCompanion(groupName: Value(to)));
  }

  /// 解散分组：把组内所有库移回未分组（库本身保留）。返回受影响的库数。
  Future<int> dissolveGroup(String name) {
    return (update(knowledgeBaseRows)..where((t) => t.groupName.equals(name)))
        .write(const KnowledgeBaseRowsCompanion(groupName: Value(null)));
  }

  /// 更新库的重排序模型 key（功能缺口⑥）；传 null 关闭重排。
  Future<void> updateBaseRerankModel(String id, String? rerankModelKey) {
    return (update(knowledgeBaseRows)..where((t) => t.id.equals(id))).write(
      KnowledgeBaseRowsCompanion(rerankModelKey: Value(rerankModelKey)),
    );
  }

  /// 更换库的嵌入模型：一并更新维度与检索模式（建库后换嵌入模型，功能缺口对比
  /// CS 的最后一项）。向量索引的重建由服务层随后调用 [reindexBase] 完成。
  Future<void> updateBaseEmbeddingModel(
    String id, {
    required String embeddingModelKey,
    required int? dimensions,
    required KnowledgeSearchMode searchMode,
  }) {
    return (update(knowledgeBaseRows)..where((t) => t.id.equals(id))).write(
      KnowledgeBaseRowsCompanion(
        embeddingModelKey: Value(embeddingModelKey),
        dimensions: Value(dimensions),
        searchMode: Value(searchMode.name),
      ),
    );
  }

  /// 更新库级云端文件预处理器 id（§5.2 云端预处理轨）；传 null 回到本地解析轨。
  Future<void> updateBaseFileProcessor(String id, String? processorId) {
    return (update(knowledgeBaseRows)..where((t) => t.id.equals(id))).write(
      KnowledgeBaseRowsCompanion(fileProcessorId: Value(processorId)),
    );
  }

  /// 更新库的可编辑配置（名称 + RAG 参数，设计文档 §6）。[threshold] 传 null
  /// 表示清除相似度阈值；[searchMode] 传 null 表示不改检索模式。
  Future<void> updateBaseConfig(
    String id, {
    required String name,
    required int chunkSize,
    required int chunkOverlap,
    required KnowledgeChunkStrategy chunkStrategy,
    required String chunkSeparator,
    required int topK,
    required double? threshold,
    KnowledgeSearchMode? searchMode,
  }) {
    return (update(knowledgeBaseRows)..where((t) => t.id.equals(id))).write(
      KnowledgeBaseRowsCompanion(
        name: Value(name),
        chunkSize: Value(chunkSize),
        chunkOverlap: Value(chunkOverlap),
        chunkStrategy: Value(chunkStrategy.name),
        chunkSeparator: Value(chunkSeparator),
        topK: Value(topK),
        threshold: Value(threshold),
        searchMode: searchMode == null
            ? const Value.absent()
            : Value(searchMode.name),
      ),
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
  /// 返回回收的行数。
  Future<int> _deleteOrphanEmbeddings() async {
    final referenced = selectOnly(kbChunkRows, distinct: true)
      ..addColumns([kbChunkRows.embeddingKey])
      ..where(kbChunkRows.embeddingKey.isNotNull());
    return (delete(
      kbEmbeddingRows,
    )..where((t) => t.embeddingKey.isNotInQuery(referenced))).go();
  }

  /// 手动触发孤儿嵌入 GC（设计文档 §11.1）。删除/重索引路径已自动 GC，此入口供
  /// 存储管理 / 异常残留时兜底清理。返回回收的行数。
  Future<int> gcOrphanEmbeddings() =>
      transaction(() => _deleteOrphanEmbeddings());

  /// 知识库整体存储占用汇总（设计文档 §11.1）。字节数按各表文本列的 UTF-8 长度
  /// 估算（`LENGTH()`），足够支撑软配额提示。
  Future<KnowledgeStorageStats> storageStats() async {
    final baseCount = knowledgeBaseRows.id.count();
    final baseRow = await (selectOnly(
      knowledgeBaseRows,
    )..addColumns([baseCount])).getSingle();

    final itemCount = knowledgeItemRows.id.count();
    final itemRow = await (selectOnly(
      knowledgeItemRows,
    )..addColumns([itemCount])).getSingle();

    final contentBytes = knowledgeContentRows.content.length.sum();
    final contentRow = await (selectOnly(
      knowledgeContentRows,
    )..addColumns([contentBytes])).getSingle();

    final chunkCount = kbChunkRows.chunkId.count();
    final chunkBytes = kbChunkRows.content.length.sum();
    final chunkRow = await (selectOnly(
      kbChunkRows,
    )..addColumns([chunkCount, chunkBytes])).getSingle();

    final embeddingCount = kbEmbeddingRows.embeddingKey.count();
    final embeddingBytes = kbEmbeddingRows.vector.length.sum();
    final embeddingRow = await (selectOnly(
      kbEmbeddingRows,
    )..addColumns([embeddingCount, embeddingBytes])).getSingle();

    return KnowledgeStorageStats(
      baseCount: baseRow.read(baseCount) ?? 0,
      itemCount: itemRow.read(itemCount) ?? 0,
      contentBytes: contentRow.read(contentBytes) ?? 0,
      chunkCount: chunkRow.read(chunkCount) ?? 0,
      chunkBytes: chunkRow.read(chunkBytes) ?? 0,
      embeddingCount: embeddingRow.read(embeddingCount) ?? 0,
      embeddingBytes: embeddingRow.read(embeddingBytes) ?? 0,
    );
  }

  /// 某库里「已完成条目但尚未嵌入（`embeddingKey` 为空）」的切块——嵌入失败/中断
  /// 后留下的待补索引（设计文档 §11「失败恢复」）。
  Future<List<KbChunkRow>> pendingEmbeddingChunks(String baseId) {
    final completedItemIds = selectOnly(knowledgeItemRows)
      ..addColumns([knowledgeItemRows.id])
      ..where(
        knowledgeItemRows.baseId.equals(baseId) &
            knowledgeItemRows.status.equals(KnowledgeItemStatus.completed.name),
      );
    final query = select(kbChunkRows)
      ..where(
        (t) =>
            t.baseId.equals(baseId) &
            t.itemId.isInQuery(completedItemIds) &
            t.embeddingKey.isNull(),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.unitIndex)]);
    return query.get();
  }

  /// 给一批已存在的切块补写 `embeddingKey` 并落库新增向量（失败恢复的写入侧），
  /// 全在一个事务里。[chunkKeys] 是 `chunkId → embeddingKey`；[embeddings] 是本次
  /// 要新写入的 `embeddingKey → 向量`（调用方已按已存在键去重）。
  Future<void> attachChunkEmbeddings({
    required Map<String, String> chunkKeys,
    required Map<String, List<double>> embeddings,
  }) => transaction(() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in embeddings.entries) {
      await into(kbEmbeddingRows).insertOnConflictUpdate(
        KbEmbeddingRowsCompanion.insert(
          embeddingKey: entry.key,
          dimensions: entry.value.length,
          vector: encodeVector(entry.value),
          createdAt: now,
        ),
      );
    }
    for (final entry in chunkKeys.entries) {
      await (update(kbChunkRows)..where((t) => t.chunkId.equals(entry.key)))
          .write(KbChunkRowsCompanion(embeddingKey: Value(entry.value)));
    }
  });

  // ── knowledge_item ──

  Future<List<KnowledgeItem>> listItems(String baseId) async {
    final rows =
        await (select(knowledgeItemRows)
              ..where((t) => t.baseId.equals(baseId) & t.deletedAt.isNull())
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    return rows.map(_toItem).toList();
  }

  /// 回收站里的条目（功能缺口⑩），按删除时间倒序。
  Future<List<KnowledgeItem>> listDeletedItems(String baseId) async {
    final rows =
        await (select(knowledgeItemRows)
              ..where((t) => t.baseId.equals(baseId) & t.deletedAt.isNotNull())
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.deletedAt,
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
      ..where(
        knowledgeItemRows.baseId.equals(baseId) &
            knowledgeItemRows.deletedAt.isNull(),
      );
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

  /// 一个库里所有条目连同其正文（供 [reindexBase] 从权威正文重建派生切块）。
  /// 缺正文的条目（极少见的坏状态）跳过——没有正文就无从重新切块。
  Future<List<KnowledgeItemWithContent>> itemsWithContent(String baseId) async {
    final items =
        await (select(knowledgeItemRows)
              ..where((t) => t.baseId.equals(baseId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
            .get();
    if (items.isEmpty) return const [];
    final contents = await (select(
      knowledgeContentRows,
    )..where((t) => t.itemId.isIn([for (final i in items) i.id]))).get();
    final byItem = {for (final c in contents) c.itemId: c};
    final result = <KnowledgeItemWithContent>[];
    for (final item in items) {
      final content = byItem[item.id];
      if (content == null) continue;
      result.add(
        KnowledgeItemWithContent(
          item: _toItem(item),
          content: content.content,
          contentHash: content.contentHash,
        ),
      );
    }
    return result;
  }

  /// 单个条目连同其权威正文（供单条目重索引）。条目或正文缺失返 null。
  Future<KnowledgeItemWithContent?> itemWithContent(String itemId) async {
    final item = await (select(
      knowledgeItemRows,
    )..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (item == null) return null;
    final content = await (select(
      knowledgeContentRows,
    )..where((t) => t.itemId.equals(itemId))).getSingleOrNull();
    if (content == null) return null;
    return KnowledgeItemWithContent(
      item: _toItem(item),
      content: content.content,
      contentHash: content.contentHash,
    );
  }

  /// 某条目的全部切块（按 unitIndex 排序），供条目切块详情展示。
  Future<List<KbChunkRow>> listItemChunks(String itemId) {
    final query = select(kbChunkRows)
      ..where((t) => t.itemId.equals(itemId))
      ..orderBy([(t) => OrderingTerm(expression: t.unitIndex)]);
    return query.get();
  }

  /// 软删除单个条目（功能缺口⑩ 回收站）：标记 `deletedAt` 并删掉派生切块
  /// （检索随之排除）+ 回收孤儿嵌入；权威正文保留，供 [restoreItem] 无损重建。
  Future<void> softDeleteItem(String itemId) => transaction(() async {
    await (update(knowledgeItemRows)..where((t) => t.id.equals(itemId))).write(
      KnowledgeItemRowsCompanion(
        deletedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    await (delete(kbChunkRows)..where((t) => t.itemId.equals(itemId))).go();
    await _deleteOrphanEmbeddings();
  });

  /// 把回收站里的条目标回未删除（切块由服务层重建）。
  Future<void> restoreItem(String itemId) {
    return (update(knowledgeItemRows)..where((t) => t.id.equals(itemId))).write(
      const KnowledgeItemRowsCompanion(deletedAt: Value(null)),
    );
  }

  /// 彻底删除单个条目及其派生数据（正文 + 切块），并回收随之产生的孤儿嵌入，全在
  /// 一个事务里。`kb_embedding` 按 `embeddingKey` 全局去重共享，故删完切块后才 GC。
  Future<void> deleteItem(String itemId) => transaction(() async {
    await (delete(
      knowledgeContentRows,
    )..where((t) => t.itemId.equals(itemId))).go();
    await (delete(kbChunkRows)..where((t) => t.itemId.equals(itemId))).go();
    await (delete(knowledgeItemRows)..where((t) => t.id.equals(itemId))).go();
    await _deleteOrphanEmbeddings();
  });

  /// 原子重建整库派生索引（设计文档 §5.1）：在一个事务里先删掉本库所有旧切块，
  /// 再按调用方（服务层）已重新切块 + 惰性嵌入好的结果重建 `kb_chunk`，写入本次
  /// 新增的 `kb_embedding`（复合键去重，`insertOnConflictUpdate` 幂等），最后回收
  /// 因重建而不再被任何切块引用的孤儿嵌入。权威表（item / content）不动——切块是
  /// 纯派生数据，可从正文无损重建。返回重建覆盖的条目数。
  Future<void> reindexBase({
    required String baseId,
    required List<ReindexItem> items,
    required Map<String, List<double>> embeddings,
  }) => transaction(() async {
    await (delete(kbChunkRows)..where((t) => t.baseId.equals(baseId))).go();
    for (final entry in items) {
      for (final chunk in entry.chunks) {
        await into(kbChunkRows).insert(
          KbChunkRowsCompanion.insert(
            chunkId: '${entry.itemId}#${chunk.unitIndex}',
            baseId: baseId,
            itemId: entry.itemId,
            unitIndex: chunk.unitIndex,
            charStart: chunk.charStart,
            charEnd: chunk.charEnd,
            content: chunk.text,
            contentHash: entry.contentHash,
            embeddingKey: Value(entry.embeddingKeys?[chunk.unitIndex]),
          ),
        );
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in embeddings.entries) {
      await into(kbEmbeddingRows).insertOnConflictUpdate(
        KbEmbeddingRowsCompanion.insert(
          embeddingKey: entry.key,
          dimensions: entry.value.length,
          vector: encodeVector(entry.value),
          createdAt: now,
        ),
      );
    }
    await _deleteOrphanEmbeddings();
  });

  /// 原子重建单个条目的派生切块（功能缺口⑪）：与 [reindexBase] 同构，但只删重
  /// 该条目的 `kb_chunk`，其它条目不动；同样写入新增嵌入并回收孤儿嵌入。
  Future<void> reindexItem({
    required String baseId,
    required ReindexItem item,
    required Map<String, List<double>> embeddings,
  }) => transaction(() async {
    await (delete(
      kbChunkRows,
    )..where((t) => t.itemId.equals(item.itemId))).go();
    for (final chunk in item.chunks) {
      await into(kbChunkRows).insert(
        KbChunkRowsCompanion.insert(
          chunkId: '${item.itemId}#${chunk.unitIndex}',
          baseId: baseId,
          itemId: item.itemId,
          unitIndex: chunk.unitIndex,
          charStart: chunk.charStart,
          charEnd: chunk.charEnd,
          content: chunk.text,
          contentHash: item.contentHash,
          embeddingKey: Value(item.embeddingKeys?[chunk.unitIndex]),
        ),
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in embeddings.entries) {
      await into(kbEmbeddingRows).insertOnConflictUpdate(
        KbEmbeddingRowsCompanion.insert(
          embeddingKey: entry.key,
          dimensions: entry.value.length,
          vector: encodeVector(entry.value),
          createdAt: now,
        ),
      );
    }
    await _deleteOrphanEmbeddings();
  });

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
        sourceFingerprint: Value(item.sourceFingerprint),
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
  /// substring via `instr(lower(content), token)`——不用 LIKE，避免 token 里的
  /// `%`/`_` 被当通配符), restricted to items that finished ingesting
  /// (`completed`). Scoring / topK trimming happens in the service layer.
  Future<List<KbChunkRow>> searchChunks(
    String baseId,
    List<String> tokens,
  ) async {
    if (tokens.isEmpty) return const [];
    final completedItemIds = selectOnly(knowledgeItemRows)
      ..addColumns([knowledgeItemRows.id])
      ..where(
        knowledgeItemRows.baseId.equals(baseId) &
            knowledgeItemRows.status.equals(KnowledgeItemStatus.completed.name),
      );

    final lowerContent = FunctionCallExpression<String>('lower', [
      kbChunkRows.content,
    ]);
    Expression<bool> anyToken = const Constant(false);
    for (final token in tokens) {
      anyToken =
          anyToken |
          FunctionCallExpression<int>('instr', [
            lowerContent,
            Variable<String>(token.toLowerCase()),
          ]).isBiggerThanValue(0);
    }

    final query = select(kbChunkRows)
      ..where(
        (t) =>
            t.baseId.equals(baseId) &
            t.itemId.isInQuery(completedItemIds) &
            anyToken,
      )
      ..orderBy([(t) => OrderingTerm(expression: t.unitIndex)]);
    return query.get();
  }

  /// FTS5 BM25 全文检索（对齐 CS 的 BM25 路径）：用 [matchQuery]（FTS5 MATCH
  /// 语法）在 `kb_chunk_fts` 上查，按 bm25 升序（越小越相关）返回切块及其分数，
  /// 限已完成条目。FTS 表不可用（旧 SQLite 无 trigram）时由调用方捕错回退。
  Future<List<({KbChunkRow chunk, double bm25})>> searchChunksBm25(
    String baseId,
    String matchQuery, {
    required int limit,
  }) async {
    final rows = await customSelect(
      'SELECT c.*, bm25(kb_chunk_fts) AS bm25_score '
      'FROM kb_chunk_fts f '
      'JOIN kb_chunk_rows c ON c.chunk_id = f.chunk_id '
      'JOIN knowledge_item_rows i ON i.id = c.item_id '
      "WHERE kb_chunk_fts MATCH ? AND c.base_id = ? AND i.status = 'completed' "
      'ORDER BY bm25_score ASC LIMIT ?',
      variables: [
        Variable<String>(matchQuery),
        Variable<String>(baseId),
        Variable<int>(limit),
      ],
      readsFrom: {kbChunkRows, knowledgeItemRows},
    ).get();
    final result = <({KbChunkRow chunk, double bm25})>[];
    for (final row in rows) {
      result.add((
        chunk: kbChunkRows.map(row.data),
        bm25: row.read<double>('bm25_score'),
      ));
    }
    return result;
  }

  // ── vector search (设计文档 §6 vector / hybrid) ──

  /// 某库所有「已完成条目 + 已嵌入（`embeddingKey` 非空）」的切块，供向量检索取回
  /// 后在 Dart 侧算 cosine。不带 token 过滤——语义检索靠向量而非字面命中。
  Future<List<KbChunkRow>> embeddedChunks(String baseId) async {
    final completedItemIds = selectOnly(knowledgeItemRows)
      ..addColumns([knowledgeItemRows.id])
      ..where(
        knowledgeItemRows.baseId.equals(baseId) &
            knowledgeItemRows.status.equals(KnowledgeItemStatus.completed.name),
      );
    final query = select(kbChunkRows)
      ..where(
        (t) =>
            t.baseId.equals(baseId) &
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
    return {for (final row in rows) row.embeddingKey: decodeVector(row.vector)};
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
    chunkStrategy: KnowledgeChunkStrategy.fromName(row.chunkStrategy),
    chunkSeparator: row.chunkSeparator,
    searchMode: KnowledgeSearchMode.fromName(row.searchMode),
    threshold: row.threshold,
    topK: row.topK,
    scope: row.scope,
    status: KnowledgeBaseStatus.fromName(row.status),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    fileProcessorId: row.fileProcessorId,
    groupName: row.groupName,
    rerankModelKey: row.rerankModelKey,
  );

  KnowledgeItem _toItem(KnowledgeItemRow row) => KnowledgeItem(
    deletedAt: row.deletedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.deletedAt!),
    id: row.id,
    baseId: row.baseId,
    type: KnowledgeItemType.fromName(row.type),
    source: row.source,
    conceptId: row.conceptId,
    title: row.title,
    status: KnowledgeItemStatus.fromName(row.status),
    error: row.error,
    sourceFingerprint: row.sourceFingerprint,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
  );
}
