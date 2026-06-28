import 'package:json_annotation/json_annotation.dart';

/// Discriminator for the [MessageBlock] union. Wire values mirror the original
/// `MessageBlockType` (`src/shared/types/newMessage.ts`) verbatim so persisted
/// blocks keep deserializing.
enum MessageBlockType {
  @JsonValue('unknown')
  unknown,
  @JsonValue('main_text')
  mainText,
  @JsonValue('thinking')
  thinking,
  @JsonValue('image')
  image,
  @JsonValue('video')
  video,
  @JsonValue('code')
  code,
  @JsonValue('tool')
  tool,
  @JsonValue('file')
  file,
  @JsonValue('error')
  error,
  @JsonValue('citation')
  citation,
  @JsonValue('translation')
  translation,
  @JsonValue('chart')
  chart,
  @JsonValue('math')
  math,
  @JsonValue('knowledge_reference')
  knowledgeReference,
  @JsonValue('context_summary')
  contextSummary,
  @JsonValue('memory_injection')
  memoryInjection,
}
