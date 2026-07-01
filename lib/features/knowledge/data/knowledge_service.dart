import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/knowledge_reference_item.dart';
import 'package:aetherlink_flutter/features/knowledge/data/datasources/local/knowledge_dao.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_chunking.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_item.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_scope.dart';

/// P0 知识库核心服务（设计文档 §5 摄取 + §6 检索的关键词部分）。
///
/// 只依赖 [KnowledgeDao]，不碰嵌入——摄取到关键词索引、检索走 `LIKE`。同一套核心
/// 未来供 UI（轨道 A）、聊天工具（轨道 B）、智能体（轨道 C）复用；[search] 的
/// [allowedIds] 参数现在恒传 null（聊天轨道 = 全部 `chatEnabled` 库），预留给
/// 智能体轨道（设计文档 §9）。
class KnowledgeService {
  KnowledgeService(this._dao);

  final KnowledgeDao _dao;

  Future<List<KnowledgeBase>> listBases() => _dao.listBases();

  Future<List<KnowledgeItem>> listItems(String baseId) =>
      _dao.listItems(baseId);

  Future<int> itemCount(String baseId) => _dao.countItems(baseId);

  /// Creates an empty base. P0 defaults to keyword search; [scope] defaults to
  /// chat-disabled (the chat track is a P2 concern).
  Future<KnowledgeBase> createBase({
    required String name,
    KnowledgeScope scope = const KnowledgeScope(),
  }) async {
    final base = KnowledgeBase(
      id: generateId('kb'),
      name: name.trim(),
      searchMode: KnowledgeSearchMode.keyword,
      status: KnowledgeBaseStatus.idle,
      scope: scope,
      createdAt: DateTime.now(),
    );
    await _dao.createBase(base);
    return base;
  }

  Future<void> deleteBase(String id) => _dao.deleteBase(id);

  /// Ingests a note (also the entry point for pasted txt / md text, §5): stores
  /// the content, splits it into fixed-length chunks, and writes the keyword
  /// index — all in one transaction. Returns the created item.
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
    await _dao.insertItemWithChunks(
      item: item,
      text: text,
      contentHash: contentHash,
      chunks: chunks,
    );
    if (base.status != KnowledgeBaseStatus.completed) {
      await _dao.updateBaseStatus(baseId, KnowledgeBaseStatus.completed);
    }
    return item;
  }

  /// Pure keyword search over a base's chunks (设计文档 §6 keyword 分支)。返回
  /// 复用聊天领域的 [KnowledgeReferenceItem]，`KnowledgeReferenceBlockView`
  /// 零改动即可渲染。相似度用「命中查询词的比例」作朴素打分。
  ///
  /// [allowedIds] 预留给智能体轨道，P0 恒为 null。
  Future<List<KnowledgeReferenceItem>> search({
    required String baseId,
    required String query,
    int? topK,
    List<String>? allowedIds,
  }) async {
    final tokens = _tokenize(query);
    if (tokens.isEmpty) return const [];
    final base = await _dao.getBase(baseId);
    if (base == null) return const [];

    final rows = await _dao.searchChunks(baseId, tokens);
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
          text: row.content,
          itemId: row.itemId,
          similarity: matchedTokens / tokens.length,
          occurrences: occurrences,
        ),
      );
    }

    scored.sort((a, b) {
      final bySimilarity = b.similarity.compareTo(a.similarity);
      if (bySimilarity != 0) return bySimilarity;
      return b.occurrences.compareTo(a.occurrences);
    });

    final limit = topK ?? base.topK;
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
    required this.text,
    required this.itemId,
    required this.similarity,
    required this.occurrences,
  });

  final String text;
  final String itemId;
  final double similarity;
  final int occurrences;
}
