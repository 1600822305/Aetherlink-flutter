// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_search_reference_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WebSearchReferenceItem _$WebSearchReferenceItemFromJson(
  Map<String, dynamic> json,
) => _WebSearchReferenceItem(
  index: (json['index'] as num).toInt(),
  title: json['title'] as String,
  url: json['url'] as String,
  snippet: json['snippet'] as String?,
  content: json['content'] as String?,
  provider: json['provider'] as String?,
);

Map<String, dynamic> _$WebSearchReferenceItemToJson(
  _WebSearchReferenceItem instance,
) => <String, dynamic>{
  'index': instance.index,
  'title': instance.title,
  'url': instance.url,
  'snippet': ?instance.snippet,
  'content': ?instance.content,
  'provider': ?instance.provider,
};
