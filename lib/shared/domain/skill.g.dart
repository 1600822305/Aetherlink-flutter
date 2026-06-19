// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Skill _$SkillFromJson(Map<String, dynamic> json) => _Skill(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  source: $enumDecode(_$SkillSourceEnumMap, json['source']),
  emoji: json['emoji'] as String?,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  content: json['content'] as String? ?? '',
  triggerPhrases:
      (json['triggerPhrases'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  mcpServerId: json['mcpServerId'] as String?,
  modelOverride: json['modelOverride'] as String?,
  temperatureOverride: (json['temperatureOverride'] as num?)?.toDouble(),
  version: json['version'] as String?,
  author: json['author'] as String?,
  enabled: json['enabled'] as bool? ?? false,
  usageCount: (json['usageCount'] as num?)?.toInt(),
  lastUsedAt: json['lastUsedAt'] as String?,
  createdAt: json['createdAt'] as String?,
  updatedAt: json['updatedAt'] as String?,
);

Map<String, dynamic> _$SkillToJson(_Skill instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'source': _$SkillSourceEnumMap[instance.source]!,
  'emoji': ?instance.emoji,
  'tags': instance.tags,
  'content': instance.content,
  'triggerPhrases': instance.triggerPhrases,
  'mcpServerId': ?instance.mcpServerId,
  'modelOverride': ?instance.modelOverride,
  'temperatureOverride': ?instance.temperatureOverride,
  'version': ?instance.version,
  'author': ?instance.author,
  'enabled': instance.enabled,
  'usageCount': ?instance.usageCount,
  'lastUsedAt': ?instance.lastUsedAt,
  'createdAt': ?instance.createdAt,
  'updatedAt': ?instance.updatedAt,
};

const _$SkillSourceEnumMap = {
  SkillSource.builtin: 'builtin',
  SkillSource.user: 'user',
  SkillSource.community: 'community',
};
