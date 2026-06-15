// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'citation_source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CitationSource _$CitationSourceFromJson(Map<String, dynamic> json) =>
    _CitationSource(
      title: json['title'] as String?,
      url: json['url'] as String?,
      content: json['content'] as String?,
    );

Map<String, dynamic> _$CitationSourceToJson(_CitationSource instance) =>
    <String, dynamic>{
      'title': ?instance.title,
      'url': ?instance.url,
      'content': ?instance.content,
    };
