// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'knowledge_reference_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_KnowledgeReferenceItem _$KnowledgeReferenceItemFromJson(
  Map<String, dynamic> json,
) => _KnowledgeReferenceItem(
  index: (json['index'] as num).toInt(),
  content: json['content'] as String,
  similarity: (json['similarity'] as num).toDouble(),
  documentId: json['documentId'] as String?,
  knowledgeBaseId: json['knowledgeBaseId'] as String?,
  knowledgeBaseName: json['knowledgeBaseName'] as String?,
  sourceUrl: json['sourceUrl'] as String?,
);

Map<String, dynamic> _$KnowledgeReferenceItemToJson(
  _KnowledgeReferenceItem instance,
) => <String, dynamic>{
  'index': instance.index,
  'content': instance.content,
  'similarity': instance.similarity,
  'documentId': ?instance.documentId,
  'knowledgeBaseId': ?instance.knowledgeBaseId,
  'knowledgeBaseName': ?instance.knowledgeBaseName,
  'sourceUrl': ?instance.sourceUrl,
};
