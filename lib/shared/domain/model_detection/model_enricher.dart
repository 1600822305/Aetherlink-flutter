/// One-time capability enrichment, performed at model-creation time.
///
/// v2 flow: when a model is fetched / added / imported, we populate its
/// [Model.capabilities] **once** so that all runtime checks (`model_checks.dart`)
/// can simply read the field. Resolution order:
///   1. Already populated (`capabilities` or `modelTypes` set) → preserve.
///      Backup/import data and explicit user selections win.
///   2. Bundled preset registry (`models.json`) → authoritative.
///   3. Regex inference from the id → fallback for unknown/custom models.
library;

import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_capabilities.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/capability_inference.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_registry.dart';

/// Resolves capabilities for a raw model [id]: preset registry first, then
/// regex inference. Returns `null` when neither yields anything.
///
/// [registry] must already be loaded ([ModelRegistry.ensureLoaded]).
ModelCapabilities? detectCapabilities(String id, {ModelRegistry? registry}) {
  final reg = registry ?? ModelRegistry.instance;
  return reg.capabilitiesFor(id) ?? inferCapabilitiesFromModelId(id);
}

/// Returns [model] with `capabilities` populated when it had none. Models that
/// already carry `capabilities` or an explicit `modelTypes` selection are
/// returned unchanged (their data is treated as authoritative).
Model enrichModelSync(Model model, {ModelRegistry? registry}) {
  if (model.capabilities != null) return model;
  if (model.modelTypes != null && model.modelTypes!.isNotEmpty) return model;
  final detected = detectCapabilities(model.id, registry: registry);
  if (detected == null) return model;
  return model.copyWith(capabilities: detected);
}

/// Async wrapper that ensures the preset registry is loaded before enriching.
Future<Model> enrichModel(Model model, {ModelRegistry? registry}) async {
  final reg = registry ?? ModelRegistry.instance;
  await reg.ensureLoaded();
  return enrichModelSync(model, registry: reg);
}

/// Enriches a batch of models, loading the registry once.
Future<List<Model>> enrichModels(List<Model> models, {ModelRegistry? registry}) async {
  if (models.isEmpty) return models;
  final reg = registry ?? ModelRegistry.instance;
  await reg.ensureLoaded();
  return [for (final m in models) enrichModelSync(m, registry: reg)];
}
