// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_block.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnknownBlock _$UnknownBlockFromJson(Map<String, dynamic> json) => UnknownBlock(
  id: json['id'] as String,
  messageId: json['messageId'] as String,
  status: $enumDecode(_$MessageBlockStatusEnumMap, json['status']),
  createdAt: const IsoDateTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: _$JsonConverterFromJson<String, DateTime>(
    json['updatedAt'],
    const IsoDateTimeConverter().fromJson,
  ),
  model: json['model'] == null
      ? null
      : Model.fromJson(json['model'] as Map<String, dynamic>),
  metadata: json['metadata'] as Map<String, dynamic>?,
  error: json['error'] as Map<String, dynamic>?,
  content: json['content'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$UnknownBlockToJson(UnknownBlock instance) =>
    <String, dynamic>{
      'id': instance.id,
      'messageId': instance.messageId,
      'status': _$MessageBlockStatusEnumMap[instance.status]!,
      'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
      'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
        instance.updatedAt,
        const IsoDateTimeConverter().toJson,
      ),
      'model': ?instance.model?.toJson(),
      'metadata': ?instance.metadata,
      'error': ?instance.error,
      'content': ?instance.content,
      'type': instance.$type,
    };

const _$MessageBlockStatusEnumMap = {
  MessageBlockStatus.pending: 'pending',
  MessageBlockStatus.processing: 'processing',
  MessageBlockStatus.streaming: 'streaming',
  MessageBlockStatus.success: 'success',
  MessageBlockStatus.error: 'error',
  MessageBlockStatus.paused: 'paused',
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);

MainTextBlock _$MainTextBlockFromJson(Map<String, dynamic> json) =>
    MainTextBlock(
      id: json['id'] as String,
      messageId: json['messageId'] as String,
      status: $enumDecode(_$MessageBlockStatusEnumMap, json['status']),
      createdAt: const IsoDateTimeConverter().fromJson(
        json['createdAt'] as String,
      ),
      updatedAt: _$JsonConverterFromJson<String, DateTime>(
        json['updatedAt'],
        const IsoDateTimeConverter().fromJson,
      ),
      model: json['model'] == null
          ? null
          : Model.fromJson(json['model'] as Map<String, dynamic>),
      metadata: json['metadata'] as Map<String, dynamic>?,
      error: json['error'] as Map<String, dynamic>?,
      content: json['content'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$MainTextBlockToJson(MainTextBlock instance) =>
    <String, dynamic>{
      'id': instance.id,
      'messageId': instance.messageId,
      'status': _$MessageBlockStatusEnumMap[instance.status]!,
      'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
      'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
        instance.updatedAt,
        const IsoDateTimeConverter().toJson,
      ),
      'model': ?instance.model?.toJson(),
      'metadata': ?instance.metadata,
      'error': ?instance.error,
      'content': instance.content,
      'type': instance.$type,
    };

ThinkingBlock _$ThinkingBlockFromJson(Map<String, dynamic> json) =>
    ThinkingBlock(
      id: json['id'] as String,
      messageId: json['messageId'] as String,
      status: $enumDecode(_$MessageBlockStatusEnumMap, json['status']),
      createdAt: const IsoDateTimeConverter().fromJson(
        json['createdAt'] as String,
      ),
      updatedAt: _$JsonConverterFromJson<String, DateTime>(
        json['updatedAt'],
        const IsoDateTimeConverter().fromJson,
      ),
      model: json['model'] == null
          ? null
          : Model.fromJson(json['model'] as Map<String, dynamic>),
      metadata: json['metadata'] as Map<String, dynamic>?,
      error: json['error'] as Map<String, dynamic>?,
      content: json['content'] as String,
      thinkingMillsec: (json['thinking_millsec'] as num?)?.toInt(),
      thinkingStartTime: (json['thinkingStartTime'] as num?)?.toInt(),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$ThinkingBlockToJson(ThinkingBlock instance) =>
    <String, dynamic>{
      'id': instance.id,
      'messageId': instance.messageId,
      'status': _$MessageBlockStatusEnumMap[instance.status]!,
      'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
      'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
        instance.updatedAt,
        const IsoDateTimeConverter().toJson,
      ),
      'model': ?instance.model?.toJson(),
      'metadata': ?instance.metadata,
      'error': ?instance.error,
      'content': instance.content,
      'thinking_millsec': ?instance.thinkingMillsec,
      'thinkingStartTime': ?instance.thinkingStartTime,
      'type': instance.$type,
    };

ImageBlock _$ImageBlockFromJson(Map<String, dynamic> json) => ImageBlock(
  id: json['id'] as String,
  messageId: json['messageId'] as String,
  status: $enumDecode(_$MessageBlockStatusEnumMap, json['status']),
  createdAt: const IsoDateTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: _$JsonConverterFromJson<String, DateTime>(
    json['updatedAt'],
    const IsoDateTimeConverter().fromJson,
  ),
  model: json['model'] == null
      ? null
      : Model.fromJson(json['model'] as Map<String, dynamic>),
  metadata: json['metadata'] as Map<String, dynamic>?,
  error: json['error'] as Map<String, dynamic>?,
  url: json['url'] as String,
  mimeType: json['mimeType'] as String,
  base64Data: json['base64Data'] as String?,
  width: (json['width'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
  size: (json['size'] as num?)?.toInt(),
  file: json['file'] == null
      ? null
      : MessageFileReference.fromJson(json['file'] as Map<String, dynamic>),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ImageBlockToJson(ImageBlock instance) =>
    <String, dynamic>{
      'id': instance.id,
      'messageId': instance.messageId,
      'status': _$MessageBlockStatusEnumMap[instance.status]!,
      'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
      'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
        instance.updatedAt,
        const IsoDateTimeConverter().toJson,
      ),
      'model': ?instance.model?.toJson(),
      'metadata': ?instance.metadata,
      'error': ?instance.error,
      'url': instance.url,
      'mimeType': instance.mimeType,
      'base64Data': ?instance.base64Data,
      'width': ?instance.width,
      'height': ?instance.height,
      'size': ?instance.size,
      'file': ?instance.file?.toJson(),
      'type': instance.$type,
    };

VideoBlock _$VideoBlockFromJson(Map<String, dynamic> json) => VideoBlock(
  id: json['id'] as String,
  messageId: json['messageId'] as String,
  status: $enumDecode(_$MessageBlockStatusEnumMap, json['status']),
  createdAt: const IsoDateTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: _$JsonConverterFromJson<String, DateTime>(
    json['updatedAt'],
    const IsoDateTimeConverter().fromJson,
  ),
  model: json['model'] == null
      ? null
      : Model.fromJson(json['model'] as Map<String, dynamic>),
  metadata: json['metadata'] as Map<String, dynamic>?,
  error: json['error'] as Map<String, dynamic>?,
  url: json['url'] as String,
  mimeType: json['mimeType'] as String,
  base64Data: json['base64Data'] as String?,
  width: (json['width'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
  size: (json['size'] as num?)?.toInt(),
  duration: (json['duration'] as num?)?.toInt(),
  poster: json['poster'] as String?,
  file: json['file'] == null
      ? null
      : MessageFileReference.fromJson(json['file'] as Map<String, dynamic>),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$VideoBlockToJson(VideoBlock instance) =>
    <String, dynamic>{
      'id': instance.id,
      'messageId': instance.messageId,
      'status': _$MessageBlockStatusEnumMap[instance.status]!,
      'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
      'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
        instance.updatedAt,
        const IsoDateTimeConverter().toJson,
      ),
      'model': ?instance.model?.toJson(),
      'metadata': ?instance.metadata,
      'error': ?instance.error,
      'url': instance.url,
      'mimeType': instance.mimeType,
      'base64Data': ?instance.base64Data,
      'width': ?instance.width,
      'height': ?instance.height,
      'size': ?instance.size,
      'duration': ?instance.duration,
      'poster': ?instance.poster,
      'file': ?instance.file?.toJson(),
      'type': instance.$type,
    };

CodeBlock _$CodeBlockFromJson(Map<String, dynamic> json) => CodeBlock(
  id: json['id'] as String,
  messageId: json['messageId'] as String,
  status: $enumDecode(_$MessageBlockStatusEnumMap, json['status']),
  createdAt: const IsoDateTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: _$JsonConverterFromJson<String, DateTime>(
    json['updatedAt'],
    const IsoDateTimeConverter().fromJson,
  ),
  model: json['model'] == null
      ? null
      : Model.fromJson(json['model'] as Map<String, dynamic>),
  metadata: json['metadata'] as Map<String, dynamic>?,
  error: json['error'] as Map<String, dynamic>?,
  content: json['content'] as String,
  language: json['language'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$CodeBlockToJson(CodeBlock instance) => <String, dynamic>{
  'id': instance.id,
  'messageId': instance.messageId,
  'status': _$MessageBlockStatusEnumMap[instance.status]!,
  'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
  'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
    instance.updatedAt,
    const IsoDateTimeConverter().toJson,
  ),
  'model': ?instance.model?.toJson(),
  'metadata': ?instance.metadata,
  'error': ?instance.error,
  'content': instance.content,
  'language': ?instance.language,
  'type': instance.$type,
};

ToolBlock _$ToolBlockFromJson(Map<String, dynamic> json) => ToolBlock(
  id: json['id'] as String,
  messageId: json['messageId'] as String,
  status: $enumDecode(_$MessageBlockStatusEnumMap, json['status']),
  createdAt: const IsoDateTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: _$JsonConverterFromJson<String, DateTime>(
    json['updatedAt'],
    const IsoDateTimeConverter().fromJson,
  ),
  model: json['model'] == null
      ? null
      : Model.fromJson(json['model'] as Map<String, dynamic>),
  metadata: json['metadata'] as Map<String, dynamic>?,
  error: json['error'] as Map<String, dynamic>?,
  toolId: json['toolId'] as String,
  toolName: json['toolName'] as String?,
  arguments: json['arguments'] as Map<String, dynamic>?,
  content: json['content'],
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ToolBlockToJson(ToolBlock instance) => <String, dynamic>{
  'id': instance.id,
  'messageId': instance.messageId,
  'status': _$MessageBlockStatusEnumMap[instance.status]!,
  'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
  'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
    instance.updatedAt,
    const IsoDateTimeConverter().toJson,
  ),
  'model': ?instance.model?.toJson(),
  'metadata': ?instance.metadata,
  'error': ?instance.error,
  'toolId': instance.toolId,
  'toolName': ?instance.toolName,
  'arguments': ?instance.arguments,
  'content': ?instance.content,
  'type': instance.$type,
};

FileBlock _$FileBlockFromJson(Map<String, dynamic> json) => FileBlock(
  id: json['id'] as String,
  messageId: json['messageId'] as String,
  status: $enumDecode(_$MessageBlockStatusEnumMap, json['status']),
  createdAt: const IsoDateTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: _$JsonConverterFromJson<String, DateTime>(
    json['updatedAt'],
    const IsoDateTimeConverter().fromJson,
  ),
  model: json['model'] == null
      ? null
      : Model.fromJson(json['model'] as Map<String, dynamic>),
  metadata: json['metadata'] as Map<String, dynamic>?,
  error: json['error'] as Map<String, dynamic>?,
  name: json['name'] as String,
  url: json['url'] as String,
  mimeType: json['mimeType'] as String,
  size: (json['size'] as num?)?.toInt(),
  file: json['file'] == null
      ? null
      : MessageFileReference.fromJson(json['file'] as Map<String, dynamic>),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$FileBlockToJson(FileBlock instance) => <String, dynamic>{
  'id': instance.id,
  'messageId': instance.messageId,
  'status': _$MessageBlockStatusEnumMap[instance.status]!,
  'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
  'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
    instance.updatedAt,
    const IsoDateTimeConverter().toJson,
  ),
  'model': ?instance.model?.toJson(),
  'metadata': ?instance.metadata,
  'error': ?instance.error,
  'name': instance.name,
  'url': instance.url,
  'mimeType': instance.mimeType,
  'size': ?instance.size,
  'file': ?instance.file?.toJson(),
  'type': instance.$type,
};

ErrorBlock _$ErrorBlockFromJson(Map<String, dynamic> json) => ErrorBlock(
  id: json['id'] as String,
  messageId: json['messageId'] as String,
  status: $enumDecode(_$MessageBlockStatusEnumMap, json['status']),
  createdAt: const IsoDateTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: _$JsonConverterFromJson<String, DateTime>(
    json['updatedAt'],
    const IsoDateTimeConverter().fromJson,
  ),
  model: json['model'] == null
      ? null
      : Model.fromJson(json['model'] as Map<String, dynamic>),
  metadata: json['metadata'] as Map<String, dynamic>?,
  error: json['error'] as Map<String, dynamic>?,
  content: json['content'] as String,
  message: json['message'] as String?,
  details: json['details'] as String?,
  code: json['code'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ErrorBlockToJson(ErrorBlock instance) =>
    <String, dynamic>{
      'id': instance.id,
      'messageId': instance.messageId,
      'status': _$MessageBlockStatusEnumMap[instance.status]!,
      'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
      'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
        instance.updatedAt,
        const IsoDateTimeConverter().toJson,
      ),
      'model': ?instance.model?.toJson(),
      'metadata': ?instance.metadata,
      'error': ?instance.error,
      'content': instance.content,
      'message': ?instance.message,
      'details': ?instance.details,
      'code': ?instance.code,
      'type': instance.$type,
    };

CitationBlock _$CitationBlockFromJson(
  Map<String, dynamic> json,
) => CitationBlock(
  id: json['id'] as String,
  messageId: json['messageId'] as String,
  status: $enumDecode(_$MessageBlockStatusEnumMap, json['status']),
  createdAt: const IsoDateTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: _$JsonConverterFromJson<String, DateTime>(
    json['updatedAt'],
    const IsoDateTimeConverter().fromJson,
  ),
  model: json['model'] == null
      ? null
      : Model.fromJson(json['model'] as Map<String, dynamic>),
  metadata: json['metadata'] as Map<String, dynamic>?,
  error: json['error'] as Map<String, dynamic>?,
  content: json['content'] as String,
  source: json['source'] as String?,
  url: json['url'] as String?,
  sources: (json['sources'] as List<dynamic>?)
      ?.map((e) => CitationSource.fromJson(e as Map<String, dynamic>))
      .toList(),
  response: json['response'],
  knowledge: (json['knowledge'] as List<dynamic>?)
      ?.map((e) => KnowledgeReferenceItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  webSearch: (json['webSearch'] as List<dynamic>?)
      ?.map((e) => WebSearchReferenceItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  citationMetadata: json['citationMetadata'] == null
      ? null
      : CitationMetadata.fromJson(
          json['citationMetadata'] as Map<String, dynamic>,
        ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$CitationBlockToJson(CitationBlock instance) =>
    <String, dynamic>{
      'id': instance.id,
      'messageId': instance.messageId,
      'status': _$MessageBlockStatusEnumMap[instance.status]!,
      'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
      'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
        instance.updatedAt,
        const IsoDateTimeConverter().toJson,
      ),
      'model': ?instance.model?.toJson(),
      'metadata': ?instance.metadata,
      'error': ?instance.error,
      'content': instance.content,
      'source': ?instance.source,
      'url': ?instance.url,
      'sources': ?instance.sources?.map((e) => e.toJson()).toList(),
      'response': ?instance.response,
      'knowledge': ?instance.knowledge?.map((e) => e.toJson()).toList(),
      'webSearch': ?instance.webSearch?.map((e) => e.toJson()).toList(),
      'citationMetadata': ?instance.citationMetadata?.toJson(),
      'type': instance.$type,
    };

TranslationBlock _$TranslationBlockFromJson(Map<String, dynamic> json) =>
    TranslationBlock(
      id: json['id'] as String,
      messageId: json['messageId'] as String,
      status: $enumDecode(_$MessageBlockStatusEnumMap, json['status']),
      createdAt: const IsoDateTimeConverter().fromJson(
        json['createdAt'] as String,
      ),
      updatedAt: _$JsonConverterFromJson<String, DateTime>(
        json['updatedAt'],
        const IsoDateTimeConverter().fromJson,
      ),
      model: json['model'] == null
          ? null
          : Model.fromJson(json['model'] as Map<String, dynamic>),
      metadata: json['metadata'] as Map<String, dynamic>?,
      error: json['error'] as Map<String, dynamic>?,
      content: json['content'] as String,
      sourceContent: json['sourceContent'] as String,
      sourceLanguage: json['sourceLanguage'] as String,
      targetLanguage: json['targetLanguage'] as String,
      sourceBlockId: json['sourceBlockId'] as String?,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$TranslationBlockToJson(TranslationBlock instance) =>
    <String, dynamic>{
      'id': instance.id,
      'messageId': instance.messageId,
      'status': _$MessageBlockStatusEnumMap[instance.status]!,
      'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
      'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
        instance.updatedAt,
        const IsoDateTimeConverter().toJson,
      ),
      'model': ?instance.model?.toJson(),
      'metadata': ?instance.metadata,
      'error': ?instance.error,
      'content': instance.content,
      'sourceContent': instance.sourceContent,
      'sourceLanguage': instance.sourceLanguage,
      'targetLanguage': instance.targetLanguage,
      'sourceBlockId': ?instance.sourceBlockId,
      'type': instance.$type,
    };

ChartBlock _$ChartBlockFromJson(Map<String, dynamic> json) => ChartBlock(
  id: json['id'] as String,
  messageId: json['messageId'] as String,
  status: $enumDecode(_$MessageBlockStatusEnumMap, json['status']),
  createdAt: const IsoDateTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: _$JsonConverterFromJson<String, DateTime>(
    json['updatedAt'],
    const IsoDateTimeConverter().fromJson,
  ),
  model: json['model'] == null
      ? null
      : Model.fromJson(json['model'] as Map<String, dynamic>),
  metadata: json['metadata'] as Map<String, dynamic>?,
  error: json['error'] as Map<String, dynamic>?,
  chartType: $enumDecode(_$ChartTypeEnumMap, json['chartType']),
  data: json['data'],
  options: json['options'] as Map<String, dynamic>?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ChartBlockToJson(ChartBlock instance) =>
    <String, dynamic>{
      'id': instance.id,
      'messageId': instance.messageId,
      'status': _$MessageBlockStatusEnumMap[instance.status]!,
      'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
      'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
        instance.updatedAt,
        const IsoDateTimeConverter().toJson,
      ),
      'model': ?instance.model?.toJson(),
      'metadata': ?instance.metadata,
      'error': ?instance.error,
      'chartType': _$ChartTypeEnumMap[instance.chartType]!,
      'data': ?instance.data,
      'options': ?instance.options,
      'type': instance.$type,
    };

const _$ChartTypeEnumMap = {
  ChartType.bar: 'bar',
  ChartType.line: 'line',
  ChartType.pie: 'pie',
  ChartType.scatter: 'scatter',
};

MathBlock _$MathBlockFromJson(Map<String, dynamic> json) => MathBlock(
  id: json['id'] as String,
  messageId: json['messageId'] as String,
  status: $enumDecode(_$MessageBlockStatusEnumMap, json['status']),
  createdAt: const IsoDateTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: _$JsonConverterFromJson<String, DateTime>(
    json['updatedAt'],
    const IsoDateTimeConverter().fromJson,
  ),
  model: json['model'] == null
      ? null
      : Model.fromJson(json['model'] as Map<String, dynamic>),
  metadata: json['metadata'] as Map<String, dynamic>?,
  error: json['error'] as Map<String, dynamic>?,
  content: json['content'] as String,
  displayMode: json['displayMode'] as bool,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$MathBlockToJson(MathBlock instance) => <String, dynamic>{
  'id': instance.id,
  'messageId': instance.messageId,
  'status': _$MessageBlockStatusEnumMap[instance.status]!,
  'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
  'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
    instance.updatedAt,
    const IsoDateTimeConverter().toJson,
  ),
  'model': ?instance.model?.toJson(),
  'metadata': ?instance.metadata,
  'error': ?instance.error,
  'content': instance.content,
  'displayMode': instance.displayMode,
  'type': instance.$type,
};

KnowledgeReferenceBlock _$KnowledgeReferenceBlockFromJson(
  Map<String, dynamic> json,
) => KnowledgeReferenceBlock(
  id: json['id'] as String,
  messageId: json['messageId'] as String,
  status: $enumDecode(_$MessageBlockStatusEnumMap, json['status']),
  createdAt: const IsoDateTimeConverter().fromJson(json['createdAt'] as String),
  updatedAt: _$JsonConverterFromJson<String, DateTime>(
    json['updatedAt'],
    const IsoDateTimeConverter().fromJson,
  ),
  model: json['model'] == null
      ? null
      : Model.fromJson(json['model'] as Map<String, dynamic>),
  metadata: json['metadata'] == null
      ? null
      : KnowledgeReferenceMetadata.fromJson(
          json['metadata'] as Map<String, dynamic>,
        ),
  error: json['error'] as Map<String, dynamic>?,
  content: json['content'] as String,
  knowledgeBaseId: json['knowledgeBaseId'] as String,
  source: json['source'] as String?,
  similarity: (json['similarity'] as num?)?.toDouble(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$KnowledgeReferenceBlockToJson(
  KnowledgeReferenceBlock instance,
) => <String, dynamic>{
  'id': instance.id,
  'messageId': instance.messageId,
  'status': _$MessageBlockStatusEnumMap[instance.status]!,
  'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
  'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
    instance.updatedAt,
    const IsoDateTimeConverter().toJson,
  ),
  'model': ?instance.model?.toJson(),
  'metadata': ?instance.metadata?.toJson(),
  'error': ?instance.error,
  'content': instance.content,
  'knowledgeBaseId': instance.knowledgeBaseId,
  'source': ?instance.source,
  'similarity': ?instance.similarity,
  'type': instance.$type,
};

ContextSummaryBlock _$ContextSummaryBlockFromJson(Map<String, dynamic> json) =>
    ContextSummaryBlock(
      id: json['id'] as String,
      messageId: json['messageId'] as String,
      status: $enumDecode(_$MessageBlockStatusEnumMap, json['status']),
      createdAt: const IsoDateTimeConverter().fromJson(
        json['createdAt'] as String,
      ),
      updatedAt: _$JsonConverterFromJson<String, DateTime>(
        json['updatedAt'],
        const IsoDateTimeConverter().fromJson,
      ),
      model: json['model'] == null
          ? null
          : Model.fromJson(json['model'] as Map<String, dynamic>),
      metadata: json['metadata'] as Map<String, dynamic>?,
      error: json['error'] as Map<String, dynamic>?,
      content: json['content'] as String,
      originalMessageCount: (json['originalMessageCount'] as num).toInt(),
      originalTokens: (json['originalTokens'] as num).toInt(),
      compressedTokens: (json['compressedTokens'] as num).toInt(),
      tokensSaved: (json['tokensSaved'] as num).toInt(),
      cost: (json['cost'] as num?)?.toDouble(),
      compressedAt: const IsoDateTimeConverter().fromJson(
        json['compressedAt'] as String,
      ),
      modelId: json['modelId'] as String?,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$ContextSummaryBlockToJson(
  ContextSummaryBlock instance,
) => <String, dynamic>{
  'id': instance.id,
  'messageId': instance.messageId,
  'status': _$MessageBlockStatusEnumMap[instance.status]!,
  'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
  'updatedAt': ?_$JsonConverterToJson<String, DateTime>(
    instance.updatedAt,
    const IsoDateTimeConverter().toJson,
  ),
  'model': ?instance.model?.toJson(),
  'metadata': ?instance.metadata,
  'error': ?instance.error,
  'content': instance.content,
  'originalMessageCount': instance.originalMessageCount,
  'originalTokens': instance.originalTokens,
  'compressedTokens': instance.compressedTokens,
  'tokensSaved': instance.tokensSaved,
  'cost': ?instance.cost,
  'compressedAt': const IsoDateTimeConverter().toJson(instance.compressedAt),
  'modelId': ?instance.modelId,
  'type': instance.$type,
};
