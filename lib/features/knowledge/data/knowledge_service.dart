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
    final base = await _dao.getBase(baseId);
    if (base == null) {
      throw StateError('知识库不存在: $baseId');
    }
    final trimmedTitle = title.trim();
    final contentHash = sha256.convert(utf8.encode(text)).toString();
    final chunks = chunkText(
      text,
      size: base.chunkSize,
      overlap: base.chunkOverlap,
    );
    final item = KnowledgeItem(
      id: generateId('kbitem'),
      baseId: baseId,
      type: KnowledgeItemType.note,
      source: trimmedTitle.isEmpty ? '未命名笔记' : trimmedTitle,
      conceptId: trimmedTitle.isEmpty ? generateId('note') : trimmedTitle,
      title: trimmedTitle.isEmpty ? '未命名笔记' : trimmedTitle,
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
      await _dao.updateBaseStatus(baseId, KnowledgeBaseStatus.completed);
    }
    return item;
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
