// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_server.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_McpServer _$McpServerFromJson(Map<String, dynamic> json) => _McpServer(
  id: json['id'] as String,
  name: json['name'] as String,
  type: $enumDecode(_$McpServerTypeEnumMap, json['type']),
  isActive: json['isActive'] as bool? ?? false,
  description: json['description'] as String?,
  baseUrl: json['baseUrl'] as String?,
  headers: (json['headers'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  env: (json['env'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  args: (json['args'] as List<dynamic>?)?.map((e) => e as String).toList(),
  disabledTools: (json['disabledTools'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  toolPermissionOverrides:
      (json['toolPermissionOverrides'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
  provider: json['provider'] as String?,
  logoUrl: json['logoUrl'] as String?,
  tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
  category: $enumDecodeNullable(_$McpServerCategoryEnumMap, json['category']),
  command: json['command'] as String?,
  cwd: json['cwd'] as String?,
  timeout: (json['timeout'] as num?)?.toInt(),
);

Map<String, dynamic> _$McpServerToJson(_McpServer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': _$McpServerTypeEnumMap[instance.type]!,
      'isActive': instance.isActive,
      'description': ?instance.description,
      'baseUrl': ?instance.baseUrl,
      'headers': ?instance.headers,
      'env': ?instance.env,
      'args': ?instance.args,
      'disabledTools': ?instance.disabledTools,
      'toolPermissionOverrides': ?instance.toolPermissionOverrides,
      'provider': ?instance.provider,
      'logoUrl': ?instance.logoUrl,
      'tags': ?instance.tags,
      'category': ?_$McpServerCategoryEnumMap[instance.category],
      'command': ?instance.command,
      'cwd': ?instance.cwd,
      'timeout': ?instance.timeout,
    };

const _$McpServerTypeEnumMap = {
  McpServerType.inMemory: 'inMemory',
  McpServerType.sse: 'sse',
  McpServerType.streamableHttp: 'streamableHttp',
  McpServerType.stdio: 'stdio',
  McpServerType.httpStream: 'httpStream',
};

const _$McpServerCategoryEnumMap = {
  McpServerCategory.externalServer: 'external',
  McpServerCategory.builtin: 'builtin',
  McpServerCategory.assistant: 'assistant',
};
