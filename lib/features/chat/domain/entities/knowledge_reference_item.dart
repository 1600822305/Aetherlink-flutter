import 'package:freezed_annotation/freezed_annotation.dart';

part 'knowledge_reference_item.freezed.dart';
part 'knowledge_reference_item.g.dart';

/// A single knowledge-base citation entry (unified citation system). Mirrors
/// `KnowledgeReferenceItem` (`src/shared/types/newMessage.ts`).
@freezed
abstract class KnowledgeReferenceItem with _$KnowledgeReferenceItem {
  const factory KnowledgeReferenceItem({
    required int index,
    required String content,
    required double similarity,
    String? documentId,
    String? knowledgeBaseId,
    String? knowledgeBaseName,
    String? sourceUrl,

    /// 命中片段所属来源可能已过期（设计文档 §8.1）。仅 workspace 条目会置真：
    /// 检索时异步比对来源指纹发现 mtime/size 变化或文件失联时标记，仅提示不拦截。
    bool? possiblyStale,
  }) = _KnowledgeReferenceItem;

  factory KnowledgeReferenceItem.fromJson(Map<String, dynamic> json) =>
      _$KnowledgeReferenceItemFromJson(json);
}
