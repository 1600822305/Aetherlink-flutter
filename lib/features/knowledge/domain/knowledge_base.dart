import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_scope.dart';

/// 检索模式（设计文档 §6）。P0 只落地 [keyword]；[vector] / [hybrid] 在 P1
/// 接入嵌入后点亮。
enum KnowledgeSearchMode {
  vector,
  keyword,
  hybrid;

  static KnowledgeSearchMode fromName(String? name) {
    for (final mode in KnowledgeSearchMode.values) {
      if (mode.name == name) return mode;
    }
    return KnowledgeSearchMode.keyword;
  }
}

/// 切块策略：[structured] 结构感知（段落 → 行 → 句子逐级回退）；[delimiter]
/// 按用户自定义分隔符优先切分，切不动时回退结构感知级别。
enum KnowledgeChunkStrategy {
  structured,
  delimiter;

  static KnowledgeChunkStrategy fromName(String? name) {
    for (final strategy in KnowledgeChunkStrategy.values) {
      if (strategy.name == name) return strategy;
    }
    return KnowledgeChunkStrategy.structured;
  }
}

/// 知识库整体索引状态（设计文档 §4.1）。
enum KnowledgeBaseStatus {
  idle,
  indexing,
  completed,
  failed;

  static KnowledgeBaseStatus fromName(String? name) {
    for (final status in KnowledgeBaseStatus.values) {
      if (status.name == name) return status;
    }
    return KnowledgeBaseStatus.idle;
  }
}

/// 一个知识库的权威元数据（设计文档 §4.1 的 `knowledge_base` 表）。
///
/// [embeddingModelKey] / [dimensions] / [threshold] 在 P0 关键词模式下可空——
/// 它们只在 P1 接入嵌入后写入并锁定；此处提前建列，避免 P1 再做一次迁移。
class KnowledgeBase {
  const KnowledgeBase({
    required this.id,
    required this.name,
    required this.searchMode,
    required this.status,
    required this.scope,
    required this.createdAt,
    this.embeddingModelKey,
    this.dimensions,
    this.chunkSize = kDefaultChunkSize,
    this.chunkOverlap = kDefaultChunkOverlap,
    this.chunkStrategy = KnowledgeChunkStrategy.structured,
    this.chunkSeparator = kDefaultChunkSeparator,
    this.threshold,
    this.topK = kDefaultTopK,
    this.fileProcessorId,
    this.groupName,
    this.rerankModelKey,
  });

  /// 默认切块参数（设计文档 §5：P0 用简单定长切块，P1 再升级结构感知切块）。
  static const int kDefaultChunkSize = 1000;
  static const int kDefaultChunkOverlap = 200;
  static const int kDefaultTopK = 5;

  /// 默认分隔符（转义形式，同 CS：`\n\n` 表示空行）。仅 delimiter 策略使用。
  static const String kDefaultChunkSeparator = r'\n\n';

  final String id;
  final String name;
  final String? embeddingModelKey;
  final int? dimensions;
  final int chunkSize;
  final int chunkOverlap;

  /// 切块策略；[chunkSeparator] 是用户输入的转义形式分隔符（如 `\n\n`），
  /// 由切块器解转义后使用，仅 delimiter 策略生效。
  final KnowledgeChunkStrategy chunkStrategy;
  final String chunkSeparator;
  final KnowledgeSearchMode searchMode;
  final double? threshold;
  final int topK;
  final KnowledgeScope scope;
  final KnowledgeBaseStatus status;
  final DateTime createdAt;

  /// 云端文件预处理器 id（设计文档 §5.2 云端预处理轨）。为空时 PDF / DOCX
  /// 走默认本地解析轨；非空时对应 `KnowledgeFileProcessor.id`。
  final String? fileProcessorId;

  /// 所属分组名（功能缺口⑦）。轻量字符串分组：同名即同组，为空表示未分组。
  final String? groupName;

  /// 重排序模型 key（功能缺口⑥），编码同 [embeddingModelKey]。非空时检索
  /// 结果经 rerank 模型重排；为空保持原排序。
  final String? rerankModelKey;

  KnowledgeBase copyWith({
    String? name,
    String? embeddingModelKey,
    int? dimensions,
    KnowledgeSearchMode? searchMode,
    double? threshold,
    int? topK,
    KnowledgeScope? scope,
    KnowledgeBaseStatus? status,
  }) {
    return KnowledgeBase(
      id: id,
      name: name ?? this.name,
      embeddingModelKey: embeddingModelKey ?? this.embeddingModelKey,
      dimensions: dimensions ?? this.dimensions,
      chunkSize: chunkSize,
      chunkOverlap: chunkOverlap,
      chunkStrategy: chunkStrategy,
      chunkSeparator: chunkSeparator,
      searchMode: searchMode ?? this.searchMode,
      threshold: threshold ?? this.threshold,
      topK: topK ?? this.topK,
      scope: scope ?? this.scope,
      status: status ?? this.status,
      createdAt: createdAt,
      fileProcessorId: fileProcessorId,
      groupName: groupName,
      rerankModelKey: rerankModelKey,
    );
  }
}
