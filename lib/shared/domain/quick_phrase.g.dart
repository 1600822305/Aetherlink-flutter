// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quick_phrase.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_QuickPhrase _$QuickPhraseFromJson(Map<String, dynamic> json) => _QuickPhrase(
  id: json['id'] as String,
  title: json['title'] as String,
  content: json['content'] as String,
  createdAt: (json['createdAt'] as num).toInt(),
  updatedAt: (json['updatedAt'] as num).toInt(),
  order: (json['order'] as num?)?.toInt(),
);

Map<String, dynamic> _$QuickPhraseToJson(_QuickPhrase instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'content': instance.content,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'order': ?instance.order,
    };
