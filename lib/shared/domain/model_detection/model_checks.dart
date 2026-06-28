/// Runtime model capability checks — the primary API for callers.
///
/// v2 architecture: these read the **authoritative** structured fields on
/// [Model] (`capabilities`, `modelTypes`) and never run regexes. Capability
/// inference / registry lookup happens once at model-creation time (see
/// `model_enricher.dart`), which populates `capabilities`; here we only read.
///
/// Priority for every check:
///   1. `modelTypes` — explicit user/imported selection (override layer)
///   2. `capabilities` — the inferred/registry-populated flags
///   3. legacy top-level flags (`multimodal` / `imageGeneration` / …)
library;

import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_capabilities.dart';
import 'package:aetherlink_flutter/shared/domain/model_type.dart';

bool _hasType(Model model, ModelType type) => model.modelTypes?.contains(type) ?? false;

/// Maps detected [ModelCapabilities] to the [ModelType] chips shown in the
/// model editor. `chat` is implied for conversational models (everything that
/// is not a pure embedding/rerank/image generator).
Set<ModelType> capabilitiesToModelTypes(ModelCapabilities? c) {
  if (c == null) return {};
  final s = <ModelType>{};
  if (c.reasoning == true) s.add(ModelType.reasoning);
  if (c.vision == true || c.multimodal == true) s.add(ModelType.vision);
  if (c.functionCalling == true || c.toolUse == true) s.add(ModelType.functionCalling);
  if (c.webSearch == true) s.add(ModelType.webSearch);
  if (c.imageGeneration == true) s.add(ModelType.imageGen);
  if (c.videoGeneration == true) s.add(ModelType.videoGen);
  if (c.embedding == true) s.add(ModelType.embedding);
  if (c.rerank == true) s.add(ModelType.rerank);
  if (c.transcription == true) s.add(ModelType.transcription);
  if (c.translation == true) s.add(ModelType.translation);
  if (c.codeGen == true) s.add(ModelType.codeGen);

  final isData = c.embedding == true || c.rerank == true;
  final isPureImage = c.imageGeneration == true &&
      !(c.reasoning == true || c.functionCalling == true || c.vision == true);
  if (!isData && !isPureImage) s.add(ModelType.chat);
  return s;
}

/// Vision / image-input capable.
bool isVisionModel(Model model) {
  if (_hasType(model, ModelType.vision)) return true;
  final c = model.capabilities;
  if (c?.vision == true || c?.multimodal == true) return true;
  return model.multimodal == true;
}

/// Reasoning / thinking capable.
bool isReasoningModel(Model model) {
  if (_hasType(model, ModelType.reasoning)) return true;
  return model.capabilities?.reasoning == true;
}

/// Embedding model.
bool isEmbeddingModel(Model model) {
  if (_hasType(model, ModelType.embedding)) return true;
  return model.capabilities?.embedding == true;
}

/// Reranking model.
bool isRerankModel(Model model) {
  if (_hasType(model, ModelType.rerank)) return true;
  return model.capabilities?.rerank == true;
}

/// Function-calling / tool-use capable.
bool isFunctionCallingModel(Model model) {
  if (_hasType(model, ModelType.functionCalling) || _hasType(model, ModelType.tool)) {
    return true;
  }
  final c = model.capabilities;
  return c?.functionCalling == true || c?.toolUse == true;
}

/// Web-search capable.
bool isWebSearchModel(Model model) {
  if (_hasType(model, ModelType.webSearch)) return true;
  return model.capabilities?.webSearch == true;
}

/// Chat-style image generation capable.
bool isGenerateImageModel(Model model) {
  if (_hasType(model, ModelType.imageGen)) return true;
  if (model.capabilities?.imageGeneration == true) return true;
  return model.imageGeneration == true;
}

/// Video generation capable.
bool isGenerateVideoModel(Model model) {
  if (_hasType(model, ModelType.videoGen)) return true;
  if (model.capabilities?.videoGeneration == true) return true;
  return model.videoGeneration == true;
}
