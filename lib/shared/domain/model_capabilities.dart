import 'package:freezed_annotation/freezed_annotation.dart';

part 'model_capabilities.freezed.dart';
part 'model_capabilities.g.dart';

/// Feature flags describing what a [Model] can do. Mirrors the inline
/// `capabilities` object on `Model` (`src/shared/types/index.ts`).
@freezed
abstract class ModelCapabilities with _$ModelCapabilities {
  const factory ModelCapabilities({
    bool? multimodal,
    bool? vision,
    bool? imageGeneration,
    bool? videoGeneration,
    bool? webSearch,
    bool? reasoning,
    bool? functionCalling,
    bool? toolUse,
    bool? embedding,
    bool? rerank,
    bool? codeGen,
    bool? translation,
    bool? transcription,
  }) = _ModelCapabilities;

  factory ModelCapabilities.fromJson(Map<String, dynamic> json) =>
      _$ModelCapabilitiesFromJson(json);
}
