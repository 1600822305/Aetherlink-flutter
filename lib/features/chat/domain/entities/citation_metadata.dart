import 'package:freezed_annotation/freezed_annotation.dart';

part 'citation_metadata.freezed.dart';
part 'citation_metadata.g.dart';

/// Metadata describing how a citation block was produced. Mirrors the inline
/// `citationMetadata` object on `CitationMessageBlock`
/// (`src/shared/types/newMessage.ts`).
@freezed
abstract class CitationMetadata with _$CitationMetadata {
  const factory CitationMetadata({
    String? searchQuery,
    List<String>? knowledgeBaseIds,
    List<String>? knowledgeBaseNames,
    String? webSearchProvider,
  }) = _CitationMetadata;

  factory CitationMetadata.fromJson(Map<String, dynamic> json) =>
      _$CitationMetadataFromJson(json);
}
