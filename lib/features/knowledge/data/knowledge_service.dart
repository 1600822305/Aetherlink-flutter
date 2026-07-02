import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/knowledge_reference_item.dart';
import 'package:aetherlink_flutter/features/knowledge/data/datasources/local/knowledge_dao.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_chunking.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_embedder.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_embedding.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_item.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_ranking.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_scope.dart';

/// 知识库核心服务（设计文档 §5 摄取 + §6 检索）。
///
/// 只依赖 [KnowledgeDao] 与一个可选的 [KnowledgeEmbedderResolver]（组合根注入，
/// 测试可传假实现或省略）。嵌入永远 best-effort：解析不到模型 / 调用失败都自动回退
/// 关键词检索，绝不中断。同一套核心未来供 UI（轨道 A）、聊天工具（轨道 B）、智能体
/// （轨道 C）复用；[search] 的 [allowedIds] 现在恒传 null，预留给智能体轨道（§9）。
class KnowledgeService {
  KnowledgeService(this._dao, {KnowledgeEmbedderResolver? embedderResolver})
    : _resolveEmbedder = embedderResolver;

  final KnowledgeDao _dao;
  final KnowledgeEmbedderResolver? _resolveEmbedder;

  Future<List<KnowledgeBase>> listBases() => _dao.listBases();

  Future<List<KnowledgeItem>> listItems(String baseId) =>
      _dao.listItems(baseId);

  Future<int> itemCount(String baseId) => _dao.countItems(baseId);

  Future<KnowledgeBase?> getBase(String id) => _dao.getBase(id);

  Future<KnowledgeItem?> getItem(String itemId) => _dao.getItem(itemId);

  /// 读取一个条目的完整正文（供 `kb_read` 按 documentId 取回原文），不存在返回 null。
  Future<String?> readItemContent(String itemId) =>
      _dao.readItemContent(itemId);

  /// Creates an empty base. [embeddingModelKey] 非空且 [searchMode] 不是 keyword
  /// 时该库启用语义检索（摄取时嵌入切块）；否则纯关键词。[scope] 默认聊天关闭
  /// （聊天轨道是 P2 的事）。
  Future<KnowledgeBase> createBase({
    required String name,
    KnowledgeScope scope = const KnowledgeScope(),
    String? embeddingModelKey,
    KnowledgeSearchMode searchMode = KnowledgeSearchMode.keyword,
  }) async {
    final key = embeddingModelKey?.trim();
    final hasModel = key != null && key.isNotEmpty;
    // 没有嵌入模型就锁死关键词——避免建出一个「向量库却无从嵌入」的坏状态。
    final mode = hasModel ? searchMode : KnowledgeSearchMode.keyword;
    final base = KnowledgeBase(
      id: generateId('kb'),
      name: name.trim(),
      embeddingModelKey: hasModel ? key : null,
      searchMode: mode,
      status: KnowledgeBaseStatus.idle,
      scope: scope,
      createdAt: DateTime.now(),
    );
    await _dao.createBase(base);
    return base;
  }

  Future<void> deleteBase(String id) => _dao.deleteBase(id);

  /// Ingests a note (also the entry point for pasted txt / md text, §5): stores
  /// the content, splits it into fixed-length chunks, writes the keyword index,
  /// 并在库启用语义检索时惰性/去重地嵌入切块（写 `kb_embedding`）——全在一个事务里。
  Future<KnowledgeItem> addNote({
    required String baseId,
    required String title,
    required String text,
  }) async {
    final base = await _requireBase(baseId);
    final trimmedTitle = title.trim();
    final label = trimmedTitle.isEmpty ? '未命名笔记' : trimmedTitle;
    return _ingest(
      base: base,
      type: KnowledgeItemType.note,
      source: label,
      conceptId: trimmedTitle.isEmpty ? generateId('note') : trimmedTitle,
      title: label,
      text: text,
    );
  }

  /// 摄取一个纯文本文件（txt / md，设计文档 §5「文件选择上传」）。调用方（UI /
  /// 文件选择器）负责把文件读成 UTF-8 文本传进来；本方法复用与 [addNote] 完全一致
  /// 的切块 + 惰性嵌入骨架，只是把 `type` 记为 [KnowledgeItemType.file]、`source`
  /// 记为原始路径/文件名，便于后续 refresh 重索引与来源展示。空文件视为坏输入抛错。
  ///
  /// PDF / DOCX 等富文档的解析不在此处——它们先被转换层转成纯文本后再走这条路径。
  Future<KnowledgeItem> addFile({
    required String baseId,
    required String fileName,
    required String text,
    String? sourcePath,
  }) async {
    final base = await _requireBase(baseId);
    final name = fileName.trim();
    if (text.trim().isEmpty) {
      throw StateError('文件内容为空，无法摄取: ${name.isEmpty ? sourcePath : name}');
    }
    final label = name.isEmpty ? '未命名文件' : name;
    final source = (sourcePath == null || sourcePath.trim().isEmpty)
        ? label
        : sourcePath.trim();
    return _ingest(
      base: base,
      type: KnowledgeItemType.file,
      source: source,
      conceptId: source,
      title: label,
      text: text,
    );
  }

  /// 通用摄取骨架：切块 → 惰性/去重嵌入 → 单事务落库（条目 + 正文 + 切块 [+ 向量]）
  /// → 首个条目落地时把库状态置 completed。note / file / url 等来源只是传入不同的
  /// `type` / `source` / `title`，管线完全一致。
  Future<KnowledgeItem> _ingest({
    required KnowledgeBase base,
    required KnowledgeItemType type,
    required String source,
    required String conceptId,
    required String title,
    required String text,
  }) async {
    final contentHash = sha256.convert(utf8.encode(text)).toString();
    final chunks = chunkText(
      text,
      size: base.chunkSize,
      overlap: base.chunkOverlap,
    );
    final item = KnowledgeItem(
      id: generateId('kbitem'),
      baseId: base.id,
      type: type,
      source: source,
      conceptId: conceptId,
      title: title,
      status: KnowledgeItemStatus.completed,
      createdAt: DateTime.now(),
    );

    final embedded = await _embedChunks(base, chunks);
    await _dao.insertItemWithChunks(
      item: item,
      text: text,
      contentHash: contentHash,
      chunks: chunks,
      chunkEmbeddingKeys: embedded?.keys,
      embeddings: embedded?.vectors,
    );
    if (base.status != KnowledgeBaseStatus.completed) {
      await _dao.updateBaseStatus(base.id, KnowledgeBaseStatus.completed);
    }
    return item;
  }

  /// 删除单个条目及其派生数据（正文 + 切块 + 孤儿嵌入），见 [KnowledgeDao.deleteItem]。
  Future<void> deleteItem(String itemId) => _dao.deleteItem(itemId);

  /// 重建整库派生索引（设计文档 §5.1 原子重建）。从每个条目已存的权威正文重新切块，
  /// 复用与摄取一致的惰性/去重嵌入（未变的内容命中已存向量、不重复调用嵌入 API），
  /// 再在一个事务里替换 `kb_chunk`、补写新增 `kb_embedding`、回收孤儿嵌入。适用于
  /// 切块参数或嵌入配置调整后刷新索引。返回重建覆盖的条目数。
  Future<int> reindexBase(String baseId) async {
    final base = await _requireBase(baseId);
    final entries = await _dao.itemsWithContent(baseId);
    final reindexed = <ReindexItem>[];
    final embeddings = <String, List<double>>{};
    for (final entry in entries) {
      final chunks = chunkText(
        entry.content,
        size: base.chunkSize,
        overlap: base.chunkOverlap,
      );
      final embedded = await _embedChunks(base, chunks);
      if (embedded != null) embeddings.addAll(embedded.vectors);
      reindexed.add(
        ReindexItem(
          itemId: entry.item.id,
          contentHash: entry.contentHash,
          chunks: chunks,
          embeddingKeys: embedded?.keys,
        ),
      );
    }
    await _dao.reindexBase(
      baseId: baseId,
      items: reindexed,
      embeddings: embeddings,
    );
    if (entries.isNotEmpty && base.status != KnowledgeBaseStatus.completed) {
      await _dao.updateBaseStatus(baseId, KnowledgeBaseStatus.completed);
    }
    return entries.length;
  }

  Future<KnowledgeBase> _requireBase(String baseId) async {
    final base = await _dao.getBase(baseId);
    if (base == null) {
      throw StateError('知识库不存在: $baseId');
    }
    return base;
  }

  /// 检索一个库（设计文档 §6）。按库的 [KnowledgeBase.searchMode] 分流到关键词 /
  /// 向量 / hybrid；向量与 hybrid 在拿不到嵌入（无模型 / 调用失败 / 无已嵌入切块）
  /// 时静默回退关键词。产出复用聊天领域的 [KnowledgeReferenceItem]，
  /// `KnowledgeReferenceBlockView` 零改动即可渲染。
  ///
  /// [allowedIds] 预留给智能体轨道，现在恒为 null。
  Future<List<KnowledgeReferenceItem>> search({
    required String baseId,
    required String query,
    int? topK,
    List<String>? allowedIds,
  }) async {
    final base = await _dao.getBase(baseId);
    if (base == null) return const [];
    final limit = topK ?? base.topK;

    switch (base.searchMode) {
      case KnowledgeSearchMode.keyword:
        return _keywordSearch(base, query, limit);
      case KnowledgeSearchMode.vector:
        final scored = await _vectorScored(base, query);
        if (scored == null) return _keywordSearch(base, query, limit);
        return _toReferences(base, _applyThreshold(base, scored), limit);
      case KnowledgeSearchMode.hybrid:
        final vector = await _vectorScored(base, query);
        if (vector == null) return _keywordSearch(base, query, limit);
        final keyword = await _keywordScored(base, query);
        return _hybridReferences(base, keyword, vector, limit);
    }
  }

  // ── ingest: embedding (设计文档 §5) ──

  /// 为一批切块算向量。返回 `keys`（unitIndex→embeddingKey）与要新写入的 `vectors`
  /// （已按已存在的 embeddingKey 去重，只嵌入缺失的），库未启用语义检索或嵌入失败时
  /// 返回 null（→ 关键词兜底）。
  Future<({Map<int, String> keys, Map<String, List<double>> vectors})?>
  _embedChunks(KnowledgeBase base, List<TextChunk> chunks) async {
    final modelKey = base.embeddingModelKey;
    final resolver = _resolveEmbedder;
    if (resolver == null ||
        modelKey == null ||
        modelKey.isEmpty ||
        base.searchMode == KnowledgeSearchMode.keyword ||
        chunks.isEmpty) {
      return null;
    }
    try {
      final embedder = await resolver(modelKey);
      if (embedder == null) return null;

      final keys = <int, String>{};
      final keyToText = <String, String>{};
      for (final chunk in chunks) {
        final key = computeEmbeddingKey(modelKey, chunk.text);
        keys[chunk.unitIndex] = key;
        keyToText.putIfAbsent(key, () => chunk.text);
      }

      final existing = await _dao.existingEmbeddingKeys(keyToText.keys);
      final missingKeys = [
        for (final key in keyToText.keys)
          if (!existing.contains(key)) key,
      ];
      final vectors = <String, List<double>>{};
      if (missingKeys.isNotEmpty) {
        final texts = [for (final key in missingKeys) keyToText[key]!];
        final embedded = await embedder.embed(texts);
        for (var i = 0; i < missingKeys.length && i < embedded.length; i++) {
          if (embedded[i].isNotEmpty) vectors[missingKeys[i]] = embedded[i];
        }
      }
      return (keys: keys, vectors: vectors);
    } catch (_) {
      // best-effort：任何嵌入错误都不阻断摄取，落成纯关键词切块。
      return null;
    }
  }

  // ── retrieval helpers ──

  Future<List<KnowledgeReferenceItem>> _keywordSearch(
    KnowledgeBase base,
    String query,
    int limit,
  ) async {
    final scored = await _keywordScored(base, query);
    return _toReferences(base, scored, limit);
  }

  /// 关键词打分：命中查询词的比例作相似度，命中次数作次序 tiebreaker。
  Future<List<_ScoredChunk>> _keywordScored(
    KnowledgeBase base,
    String query,
  ) async {
    final tokens = _tokenize(query);
    if (tokens.isEmpty) return const [];
    final rows = await _dao.searchChunks(base.id, tokens);
    final scored = <_ScoredChunk>[];
    for (final row in rows) {
      final lower = row.content.toLowerCase();
      var matchedTokens = 0;
      var occurrences = 0;
      for (final token in tokens) {
        final count = token.allMatches(lower).length;
        if (count > 0) {
          matchedTokens++;
          occurrences += count;
        }
      }
      if (matchedTokens == 0) continue;
      scored.add(
        _ScoredChunk(
          chunkId: row.chunkId,
          text: row.content,
          itemId: row.itemId,
          similarity: matchedTokens / tokens.length,
          tieBreaker: occurrences.toDouble(),
        ),
      );
    }
    scored.sort(_ScoredChunk.compare);
    return scored;
  }

  /// 向量打分：嵌入查询，对本库已嵌入切块算 cosine 排序。拿不到嵌入器 / 查询向量 /
  /// 任何已嵌入切块时返回 null，交由调用方回退关键词。
  Future<List<_ScoredChunk>?> _vectorScored(
    KnowledgeBase base,
    String query,
  ) async {
    final modelKey = base.embeddingModelKey;
    final resolver = _resolveEmbedder;
    if (resolver == null || modelKey == null || modelKey.isEmpty) return null;
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    try {
      final embedder = await resolver(modelKey);
      if (embedder == null) return null;
      final embedded = await embedder.embed([trimmed]);
      if (embedded.isEmpty || embedded.first.isEmpty) return null;
      final queryVector = embedded.first;

      final chunks = await _dao.embeddedChunks(base.id);
      if (chunks.isEmpty) return null;
      final keys = [
        for (final c in chunks)
          if (c.embeddingKey != null) c.embeddingKey!,
      ];
      final vectors = await _dao.getEmbeddings(keys);
      if (vectors.isEmpty) return null;

      final scored = <_ScoredChunk>[];
      for (final chunk in chunks) {
        final vector = vectors[chunk.embeddingKey];
        if (vector == null || vector.isEmpty) continue;
        scored.add(
          _ScoredChunk(
            chunkId: chunk.chunkId,
            text: chunk.content,
            itemId: chunk.itemId,
            similarity: cosineSimilarity(queryVector, vector),
            tieBreaker: -chunk.unitIndex.toDouble(),
          ),
        );
      }
      if (scored.isEmpty) return null;
      scored.sort(_ScoredChunk.compare);
      return scored;
    } catch (_) {
      return null;
    }
  }

  /// 阈值过滤（仅向量/hybrid，值域可比）。[KnowledgeBase.threshold] 为空则不裁。
  List<_ScoredChunk> _applyThreshold(
    KnowledgeBase base,
    List<_ScoredChunk> scored,
  ) {
    final threshold = base.threshold;
    if (threshold == null) return scored;
    return [
      for (final s in scored)
        if (s.similarity >= threshold) s,
    ];
  }

  /// hybrid：RRF 融合关键词与向量两路排名，产出引用。融合后的相似度取该切块在向量
  /// 路的分数（无则取关键词路），阈值过滤后裁 topK。
  List<KnowledgeReferenceItem> _hybridReferences(
    KnowledgeBase base,
    List<_ScoredChunk> keyword,
    List<_ScoredChunk> vector,
    int limit,
  ) {
    final byId = <String, _ScoredChunk>{};
    for (final s in keyword) {
      byId[s.chunkId] = s;
    }
    // 向量分数覆盖关键词分数（相似度以向量为准）。
    for (final s in vector) {
      byId[s.chunkId] = s;
    }
    final fused = fuseWithRrf([
      [for (final s in keyword) s.chunkId],
      [for (final s in vector) s.chunkId],
    ]);
    final ordered = [
      for (final id in fused)
        if (byId[id] != null) byId[id]!,
    ];
    return _toReferences(base, _applyThreshold(base, ordered), limit);
  }

  List<KnowledgeReferenceItem> _toReferences(
    KnowledgeBase base,
    List<_ScoredChunk> scored,
    int limit,
  ) {
    final top = scored.take(limit).toList();
    return [
      for (var i = 0; i < top.length; i++)
        KnowledgeReferenceItem(
          index: i + 1,
          content: top[i].text,
          similarity: top[i].similarity,
          documentId: top[i].itemId,
          knowledgeBaseId: base.id,
          knowledgeBaseName: base.name,
        ),
    ];
  }

  List<String> _tokenize(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return const [];
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    // 无空格（如中文短语）时整串作为单个子串词，天然覆盖 1-2 字中文词。
    return parts.isEmpty ? [trimmed] : parts;
  }
}

class _ScoredChunk {
  const _ScoredChunk({
    required this.chunkId,
    required this.text,
    required this.itemId,
    required this.similarity,
    required this.tieBreaker,
  });

  final String chunkId;
  final String text;
  final String itemId;
  final double similarity;

  /// 相似度相同时的次序依据（关键词用命中次数、向量用负 unitIndex 保稳定）。
  final double tieBreaker;

  static int compare(_ScoredChunk a, _ScoredChunk b) {
    final bySimilarity = b.similarity.compareTo(a.similarity);
    if (bySimilarity != 0) return bySimilarity;
    return b.tieBreaker.compareTo(a.tieBreaker);
  }
}
