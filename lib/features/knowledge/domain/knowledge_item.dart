/// 知识库条目的来源类型（设计文档 §4.1 / §8）。P0 只摄取 [note]（以及以
/// note 形态存入的 txt / md 文本）；[file] / [url] / [workspace] 在后续阶段
/// 点亮，此处提前落库。
enum KnowledgeItemType {
  file,
  url,
  note,
  workspace;

  static KnowledgeItemType fromName(String? name) {
    for (final type in KnowledgeItemType.values) {
      if (type.name == name) return type;
    }
    return KnowledgeItemType.note;
  }
}

/// 单个条目的摄取状态机（设计文档 §4.1 / §5）。P0 关键词模式下摄取在
/// [reading] → [chunking] → [completed] 之间流转（无 [embedding] 步）。
enum KnowledgeItemStatus {
  idle,
  reading,
  chunking,
  embedding,
  completed,
  failed;

  static KnowledgeItemStatus fromName(String? name) {
    for (final status in KnowledgeItemStatus.values) {
      if (status.name == name) return status;
    }
    return KnowledgeItemStatus.idle;
  }
}

/// 知识库里的一个条目（设计文档 §4.1 的 `knowledge_item` 表）。正文本身存在
/// `knowledge_content` 表（见 §4.2），此处只保留元数据。
class KnowledgeItem {
  const KnowledgeItem({
    required this.id,
    required this.baseId,
    required this.type,
    required this.source,
    required this.conceptId,
    required this.status,
    required this.createdAt,
    this.title,
    this.error,
    this.sourceFingerprint,
  });

  final String id;
  final String baseId;
  final KnowledgeItemType type;

  /// 原始来源：note 存标题、file 存路径、url 存链接、workspace 存 `Workspace.id`。
  final String source;

  /// 稳定寻址键（相对路径 / 标题），供 `kb_read` 精确定位。
  final String conceptId;

  /// 便于 UI 展示的标题（note 即笔记标题）。
  final String? title;
  final KnowledgeItemStatus status;

  /// 摄取失败原因（成功时为空）。
  final String? error;

  /// 来源指纹快照，JSON 编码（设计文档 §8.1）。仅 workspace 条目使用：记录摄取时
  /// 的 `{path, mtime, size}`，检索时异步比对以标记 `possiblyStale`。其它来源为空。
  final String? sourceFingerprint;

  final DateTime createdAt;
}
