import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/knowledge_reference_item.dart';
import 'package:aetherlink_flutter/features/knowledge/data/datasources/local/knowledge_dao.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_chunking.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_embedder.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_embedding.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_file_processor.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_item.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_ranking.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_scope.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_url_fetcher.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_workspace_source.dart';

/// 一个条目切块的展示单元（[KnowledgeService.itemChunks] 的返回单元）。
class KnowledgeChunkPreview {
  const KnowledgeChunkPreview({
    required this.unitIndex,
    required this.content,
    required this.embedded,
  });

  final int unitIndex;
  final String content;
  final bool embedded;
}

/// 知识库核心服务（设计文档 §5 摄取 + §6 检索）。
///
/// 只依赖 [KnowledgeDao] 与一个可选的 [KnowledgeEmbedderResolver]（组合根注入，
/// 测试可传假实现或省略）。嵌入永远 best-effort：解析不到模型 / 调用失败都自动回退
/// 关键词检索，绝不中断。同一套核心未来供 UI（轨道 A）、聊天工具（轨道 B）、智能体
/// （轨道 C）复用；[search] 的 [allowedIds] 现在恒传 null，预留给智能体轨道（§9）。
class KnowledgeService {
  KnowledgeService(
    this._dao, {
    KnowledgeEmbedderResolver? embedderResolver,
    KnowledgeUrlFetcher? urlFetcher,
    KnowledgeWorkspaceSource? workspaceSource,
    KnowledgeFilePreprocessor? filePreprocessor,
  }) : _resolveEmbedder = embedderResolver,
       _fetchUrl = urlFetcher,
       _workspaceSource = workspaceSource,
       _preprocessFile = filePreprocessor;

  final KnowledgeDao _dao;
  final KnowledgeEmbedderResolver? _resolveEmbedder;
  final KnowledgeUrlFetcher? _fetchUrl;
  final KnowledgeWorkspaceSource? _workspaceSource;
  final KnowledgeFilePreprocessor? _preprocessFile;

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

  /// 把一个富文档交给库配置的云端预处理器转 Markdown 后摄取（设计文档 §5.2
  /// 云端预处理轨）。转好的 Markdown 作为权威快照落库（与 URL 抓取同一语义），
  /// 后续 refresh 直接从快照重建索引、不再重复调云端。库未配置处理器 / 未注入
  /// 预处理器 / 云端解析失败或结果为空都抛错交由调用方提示。
  Future<KnowledgeItem> addProcessedFile({
    required String baseId,
    required String fileName,
    required Uint8List bytes,
    String? sourcePath,
  }) async {
    final base = await _requireBase(baseId);
    final processor = KnowledgeFileProcessor.fromId(base.fileProcessorId);
    if (processor == null) {
      throw StateError('该库未配置云端解析器: $baseId');
    }
    final preprocess = _preprocessFile;
    if (preprocess == null) {
      throw StateError('未配置云端文件预处理器，无法摄取');
    }
    final markdown = await preprocess(
      processor: processor,
      fileName: fileName,
      bytes: bytes,
    );
    if (markdown.trim().isEmpty) {
      throw StateError('${processor.label} 解析结果为空: $fileName');
    }
    return addFile(
      baseId: baseId,
      fileName: fileName,
      text: markdown,
      sourcePath: sourcePath,
    );
  }

  /// 更新库级云端文件预处理器（§5.2）；传 null 回到本地解析轨。
  Future<void> setFileProcessor(String baseId, String? processorId) async {
    await _requireBase(baseId);
    final normalized = processorId?.trim();
    if (normalized != null &&
        normalized.isNotEmpty &&
        KnowledgeFileProcessor.fromId(normalized) == null) {
      throw StateError('未知的云端解析器: $normalized');
    }
    await _dao.updateBaseFileProcessor(
      baseId,
      (normalized == null || normalized.isEmpty) ? null : normalized,
    );
  }

  /// 设置库的所属分组（功能缺口⑦）；[groupName] 传 null 或空白移出分组。
  Future<void> setBaseGroup(String baseId, String? groupName) async {
    await _requireBase(baseId);
    final trimmed = groupName?.trim();
    await _dao.updateBaseGroup(
      baseId,
      (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    );
  }

  /// 重命名分组（功能缺口⑦）：组内所有库改挂到 [to]。空名视为坏输入抛错。
  Future<void> renameGroup(String from, String to) async {
    final trimmed = to.trim();
    if (trimmed.isEmpty) throw StateError('分组名不能为空');
    await _dao.renameGroup(from, trimmed);
  }

  /// 解散分组（功能缺口⑦）：组内所有库移回未分组，库本身保留。
  Future<void> dissolveGroup(String name) => _dao.dissolveGroup(name);

  /// 更新库的可编辑配置（名称 + RAG 参数）。参数非法（空名 / 切块参数越界）视为
  /// 坏输入抛错。切块参数变化后需调用方另行 [reindexBase] 才会对已有条目生效。
  Future<void> updateBaseConfig(
    String baseId, {
    required String name,
    required int chunkSize,
    required int chunkOverlap,
    required int topK,
    required double? threshold,
  }) async {
    await _requireBase(baseId);
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw StateError('名称不能为空');
    if (chunkSize < 100 || chunkSize > 10000) {
      throw StateError('切块大小需在 100–10000 之间');
    }
    if (chunkOverlap < 0 || chunkOverlap >= chunkSize) {
      throw StateError('切块重叠需 ≥ 0 且小于切块大小');
    }
    if (topK < 1 || topK > 50) throw StateError('topK 需在 1–50 之间');
    if (threshold != null && (threshold < 0 || threshold > 1)) {
      throw StateError('相似度阈值需在 0–1 之间');
    }
    await _dao.updateBaseConfig(
      baseId,
      name: trimmed,
      chunkSize: chunkSize,
      chunkOverlap: chunkOverlap,
      topK: topK,
      threshold: threshold,
    );
  }

  /// 抓取一个网页并摄取为条目（设计文档 §5「URL 抓取 → Markdown 快照」）。抓取器
  /// 由组合根注入（HTTP + HTML→Markdown），未注入时抛错。抓回的正文当作权威快照
  /// 落库（`type=url`、`source=url`），后续 refresh 直接从这份快照重建索引，不再
  /// 重新联网。`title` 显式给定时优先，否则用页面 `<title>`，再回落到 URL 本身。
  /// 抓取失败或内容为空视为坏输入抛错。
  Future<KnowledgeItem> addUrl({
    required String baseId,
    required String url,
    String? title,
  }) async {
    final base = await _requireBase(baseId);
    final normalized = url.trim();
    if (normalized.isEmpty) {
      throw StateError('URL 为空，无法摄取');
    }
    final fetcher = _fetchUrl;
    if (fetcher == null) {
      throw StateError('未配置 URL 抓取器，无法摄取网页');
    }
    final page = await fetcher(normalized);
    final text = page.markdown.trim();
    if (text.isEmpty) {
      throw StateError('URL 抓取到的内容为空: $normalized');
    }
    final explicit = title?.trim();
    final fetched = page.title?.trim();
    final label = (explicit != null && explicit.isNotEmpty)
        ? explicit
        : (fetched != null && fetched.isNotEmpty ? fetched : normalized);
    return _ingest(
      base: base,
      type: KnowledgeItemType.url,
      source: normalized,
      conceptId: normalized,
      title: label,
      text: text,
    );
  }

  /// 摄取一个工作区目录（设计文档 §8「workspace 目录源」）。经注入的
  /// [KnowledgeWorkspaceSource] 递归遍历 [workspaceId] 根目录下的文本文件，逐个当作
  /// 一条 `type=workspace` 条目落库，并把摄取时的 `{workspaceId, path, mtime, size}`
  /// 记为来源指纹（[KnowledgeItem.sourceFingerprint]），供 §8.1 的 staleness 检测在
  /// 检索时异步比对。未配置工作区源时抛错；目录里无可摄取文本时抛错（坏输入）。
  /// 返回成功摄取的条目列表。
  Future<List<KnowledgeItem>> addWorkspace({
    required String baseId,
    required String workspaceId,
  }) async {
    final base = await _requireBase(baseId);
    final source = _workspaceSource;
    if (source == null) {
      throw StateError('未配置工作区源，无法摄取目录');
    }
    final files = await source.listTextFiles(workspaceId);
    final ingestible = [
      for (final f in files)
        if (f.text.trim().isNotEmpty) f,
    ];
    if (ingestible.isEmpty) {
      throw StateError('工作区目录里没有可摄取的文本文件: $workspaceId');
    }
    final items = <KnowledgeItem>[];
    for (final file in ingestible) {
      final item = await _ingest(
        base: base,
        type: KnowledgeItemType.workspace,
        source: file.path,
        conceptId: file.path,
        title: file.name,
        text: file.text,
        sourceFingerprint: _encodeFingerprint(
          workspaceId: workspaceId,
          path: file.path,
          mtime: file.mtime,
          size: file.size,
        ),
      );
      items.add(item);
    }
    return items;
  }

  /// 把 workspace 条目的来源快照编成 JSON 存入 [KnowledgeItem.sourceFingerprint]。
  static String _encodeFingerprint({
    required String workspaceId,
    required String path,
    required int mtime,
    required int size,
  }) => jsonEncode({
    'workspaceId': workspaceId,
    'path': path,
    'mtime': mtime,
    'size': size,
  });

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
    String? sourceFingerprint,
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
      sourceFingerprint: sourceFingerprint,
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

  /// 某条目的全部切块（按 unitIndex 排序），供切块详情展示。[embedded]
  /// 表示该切块是否已有向量索引。
  Future<List<KnowledgeChunkPreview>> itemChunks(String itemId) async {
    final rows = await _dao.listItemChunks(itemId);
    return [
      for (final row in rows)
        KnowledgeChunkPreview(
          unitIndex: row.unitIndex,
          content: row.content,
          embedded: row.embeddingKey != null,
        ),
    ];
  }

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

  /// 失败恢复（设计文档 §11）：只补嵌本库里 `embeddingKey` 为空的切块（摄取时嵌入
  /// 失败/中断留下的待补索引），已嵌入的切块不重算、不重复扣费——比整库
  /// [reindexBase] 轻得多。关键词库 / 无嵌入器 / 无待补切块时直接返回 0；嵌入调用
  /// 失败同样返回 0（best-effort，下次再重试）。返回本次补嵌成功的切块数。
  Future<int> retryPendingEmbeddings(String baseId) async {
    final base = await _requireBase(baseId);
    final modelKey = base.embeddingModelKey;
    final resolver = _resolveEmbedder;
    if (resolver == null ||
        modelKey == null ||
        modelKey.isEmpty ||
        base.searchMode == KnowledgeSearchMode.keyword) {
      return 0;
    }
    final pending = await _dao.pendingEmbeddingChunks(baseId);
    if (pending.isEmpty) return 0;
    try {
      final embedder = await resolver(modelKey);
      if (embedder == null) return 0;

      final chunkKeys = <String, String>{};
      final keyToText = <String, String>{};
      for (final chunk in pending) {
        final key = computeEmbeddingKey(modelKey, chunk.content);
        chunkKeys[chunk.chunkId] = key;
        keyToText.putIfAbsent(key, () => chunk.content);
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

      // 只给「向量已落库（既存或本次新嵌）」的切块补键，嵌入仍缺失的下次再试。
      final resolved = <String, String>{
        for (final entry in chunkKeys.entries)
          if (existing.contains(entry.value) ||
              vectors.containsKey(entry.value))
            entry.key: entry.value,
      };
      if (resolved.isEmpty) return 0;
      await _dao.attachChunkEmbeddings(
        chunkKeys: resolved,
        embeddings: vectors,
      );
      return resolved.length;
    } catch (_) {
      // best-effort：嵌入器报错不影响已有数据，保持待补状态供下次重试。
      return 0;
    }
  }

  /// 某库当前待补嵌入的切块数（供 UI 展示「重试」入口）。关键词库恒为 0——
  /// 它本就不需要嵌入。
  Future<int> pendingEmbeddingCount(String baseId) async {
    final base = await _dao.getBase(baseId);
    if (base == null || base.searchMode == KnowledgeSearchMode.keyword) {
      return 0;
    }
    final pending = await _dao.pendingEmbeddingChunks(baseId);
    return pending.length;
  }

  /// 知识库整体存储占用软配额（设计文档 §11.1）：超过后只提示不拦截。
  static const int softStorageLimitBytes = 200 * 1024 * 1024;

  /// 存储占用汇总 + 软配额判定（设计文档 §11.1）。
  Future<({KnowledgeStorageStats stats, bool overSoftLimit})>
  storageUsage() async {
    final stats = await _dao.storageStats();
    return (
      stats: stats,
      overSoftLimit: stats.totalBytes > softStorageLimitBytes,
    );
  }

  /// 手动回收孤儿嵌入（设计文档 §11.1），返回回收行数。常规删除/重索引路径已
  /// 自动 GC，此入口供存储管理兜底。
  Future<int> gcOrphanEmbeddings() => _dao.gcOrphanEmbeddings();

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

    final List<KnowledgeReferenceItem> refs;
    switch (base.searchMode) {
      case KnowledgeSearchMode.keyword:
        refs = await _keywordSearch(base, query, limit);
      case KnowledgeSearchMode.vector:
        final scored = await _vectorScored(base, query);
        refs = scored == null
            ? await _keywordSearch(base, query, limit)
            : _toReferences(base, _applyThreshold(base, scored), limit);
      case KnowledgeSearchMode.hybrid:
        final vector = await _vectorScored(base, query);
        if (vector == null) {
          refs = await _keywordSearch(base, query, limit);
        } else {
          final keyword = await _keywordScored(base, query);
          refs = _hybridReferences(base, keyword, vector, limit);
        }
    }
    return _annotateStaleness(refs);
  }

  /// 为命中结果里的 workspace 条目标记「可能已过期」（设计文档 §8.1）。对结果中出现
  /// 的每个 workspace 条目，用存好的来源指纹与后端当前 `(mtime, size)` 异步比对：变化
  /// 或文件失联即置 `possiblyStale=true`。全程 best-effort——未配置工作区源、无
  /// workspace 条目、或任何比对错误都原样返回，绝不阻断检索。
  Future<List<KnowledgeReferenceItem>> _annotateStaleness(
    List<KnowledgeReferenceItem> refs,
  ) async {
    final source = _workspaceSource;
    if (source == null || refs.isEmpty) return refs;
    final itemIds = <String>{
      for (final r in refs)
        if (r.documentId != null) r.documentId!,
    };
    final staleIds = <String>{};
    for (final id in itemIds) {
      try {
        final item = await _dao.getItem(id);
        if (item == null || item.type != KnowledgeItemType.workspace) continue;
        final fp = _decodeFingerprint(item.sourceFingerprint);
        if (fp == null) continue;
        final stat = await source.statFile(fp.workspaceId, fp.path);
        if (stat == null || stat.mtime != fp.mtime || stat.size != fp.size) {
          staleIds.add(id);
        }
      } catch (_) {
        // best-effort：任何比对错误都不影响检索结果。
      }
    }
    if (staleIds.isEmpty) return refs;
    return [
      for (final r in refs)
        if (r.documentId != null && staleIds.contains(r.documentId))
          r.copyWith(possiblyStale: true)
        else
          r,
    ];
  }

  /// 解析存好的来源指纹 JSON；格式不符 / 缺字段返回 null（→ 跳过该条 staleness 比对）。
  static ({String workspaceId, String path, int mtime, int size})?
  _decodeFingerprint(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final workspaceId = decoded['workspaceId'];
      final path = decoded['path'];
      if (workspaceId is! String || path is! String) return null;
      return (
        workspaceId: workspaceId,
        path: path,
        mtime: (decoded['mtime'] as num?)?.toInt() ?? 0,
        size: (decoded['size'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
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
      // 只把「向量已落库（既存或本次新嵌）」的键写到切块上；嵌入缺失的切块保持
      // 空键（= 待补状态），供 [retryPendingEmbeddings] 事后补嵌。
      final resolved = <int, String>{
        for (final entry in keys.entries)
          if (existing.contains(entry.value) ||
              vectors.containsKey(entry.value))
            entry.key: entry.value,
      };
      if (resolved.isEmpty) return null;
      return (keys: resolved, vectors: vectors);
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
