import 'package:freezed_annotation/freezed_annotation.dart';

part 'knowledge_reference_metadata.freezed.dart';
part 'knowledge_reference_metadata.g.dart';

/// Strongly-typed `metadata` for the knowledge-reference block. Mirrors the
/// inline `metadata` object on `KnowledgeReferenceMessageBlock`
/// (`src/shared/types/newMessage.ts`).
@freezed
abstract class KnowledgeReferenceMetadata with _$KnowledgeReferenceMetadata {
  const factory KnowledgeReferenceMetadata({
    String? fileName,
    String? fileId,
    String? knowledgeDocumentId,
    String? searchQuery,
    bool? isCombined,
    int? resultCount,
    List<KnowledgeReferenceMetadataResult>? results,
  }) = _KnowledgeReferenceMetadata;

  factory KnowledgeReferenceMetadata.fromJson(Map<String, dynamic> json) =>
      _$KnowledgeReferenceMetadataFromJson(json);
}

/// A single combined-search result entry inside [KnowledgeReferenceMetadata].
/// Mirrors the `results[]` item shape on `KnowledgeReferenceMessageBlock`
/// (`src/shared/types/newMessage.ts`).
@freezed
abstract class KnowledgeReferenceMetadataResult
    with _$KnowledgeReferenceMetadataResult {
  const factory KnowledgeReferenceMetadataResult({
    required int index,
    required String content,
    required double similarity,
    String? documentId,
  }) = _KnowledgeReferenceMetadataResult;

  factory KnowledgeReferenceMetadataResult.fromJson(
    Map<String, dynamic> json,
  ) => _$KnowledgeReferenceMetadataResultFromJson(json);
}
