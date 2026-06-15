import 'package:json_annotation/json_annotation.dart';

/// Capability category of a model. Wire values mirror `ModelType`
/// (`src/shared/types/index.ts`).
enum ModelType {
  @JsonValue('chat')
  chat,
  @JsonValue('vision')
  vision,
  @JsonValue('audio')
  audio,
  @JsonValue('embedding')
  embedding,
  @JsonValue('tool')
  tool,
  @JsonValue('reasoning')
  reasoning,
  @JsonValue('image_gen')
  imageGen,
  @JsonValue('video_gen')
  videoGen,
  @JsonValue('function_calling')
  functionCalling,
  @JsonValue('web_search')
  webSearch,
  @JsonValue('rerank')
  rerank,
  @JsonValue('code_gen')
  codeGen,
  @JsonValue('translation')
  translation,
  @JsonValue('transcription')
  transcription,
}
