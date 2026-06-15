// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'citation_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CitationMetadata _$CitationMetadataFromJson(Map<String, dynamic> json) =>
    _CitationMetadata(
      searchQuery: json['searchQuery'] as String?,
      knowledgeBaseIds: (json['knowledgeBaseIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      knowledgeBaseNames: (json['knowledgeBaseNames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      webSearchProvider: json['webSearchProvider'] as String?,
    );

Map<String, dynamic> _$CitationMetadataToJson(_CitationMetadata instance) =>
    <String, dynamic>{
      'searchQuery': ?instance.searchQuery,
      'knowledgeBaseIds': ?instance.knowledgeBaseIds,
      'knowledgeBaseNames': ?instance.knowledgeBaseNames,
      'webSearchProvider': ?instance.webSearchProvider,
    };
