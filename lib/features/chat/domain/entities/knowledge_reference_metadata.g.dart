// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'knowledge_reference_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_KnowledgeReferenceMetadata _$KnowledgeReferenceMetadataFromJson(
  Map<String, dynamic> json,
) => _KnowledgeReferenceMetadata(
  fileName: json['fileName'] as String?,
  fileId: json['fileId'] as String?,
  knowledgeDocumentId: json['knowledgeDocumentId'] as String?,
  searchQuery: json['searchQuery'] as String?,
  isCombined: json['isCombined'] as bool?,
  resultCount: (json['resultCount'] as num?)?.toInt(),
  results: (json['results'] as List<dynamic>?)
      ?.map(
        (e) => KnowledgeReferenceMetadataResult.fromJson(
          e as Map<String, dynamic>,
        ),
      )
      .toList(),
);

Map<String, dynamic> _$KnowledgeReferenceMetadataToJson(
  _KnowledgeReferenceMetadata instance,
) => <String, dynamic>{
  'fileName': ?instance.fileName,
  'fileId': ?instance.fileId,
  'knowledgeDocumentId': ?instance.knowledgeDocumentId,
  'searchQuery': ?instance.searchQuery,
  'isCombined': ?instance.isCombined,
  'resultCount': ?instance.resultCount,
  'results': ?instance.results?.map((e) => e.toJson()).toList(),
};

_KnowledgeReferenceMetadataResult _$KnowledgeReferenceMetadataResultFromJson(
  Map<String, dynamic> json,
) => _KnowledgeReferenceMetadataResult(
  index: (json['index'] as num).toInt(),
  content: json['content'] as String,
  similarity: (json['similarity'] as num).toDouble(),
  documentId: json['documentId'] as String?,
);

Map<String, dynamic> _$KnowledgeReferenceMetadataResultToJson(
  _KnowledgeReferenceMetadataResult instance,
) => <String, dynamic>{
  'index': instance.index,
  'content': instance.content,
  'similarity': instance.similarity,
  'documentId': ?instance.documentId,
};
