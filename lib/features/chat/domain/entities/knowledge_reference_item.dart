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
  }) = _KnowledgeReferenceItem;

  factory KnowledgeReferenceItem.fromJson(Map<String, dynamic> json) =>
      _$KnowledgeReferenceItemFromJson(json);
}
