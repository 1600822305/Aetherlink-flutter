/// Bundled preset model registry — the **authoritative** capability source.
///
/// Loads the slimmed `assets/model_registry/models.json` (a build-time export
/// of cherry-studio's `provider-registry` data: id + capabilities + modalities
/// for ~2.7k known models) and indexes it by exact id and by
/// [normalizeModelId]. When a model id resolves here, its capabilities are
/// taken as ground truth; otherwise the regex inference fallback is used
/// (see `model_enricher.dart`).
///
/// Loaded lazily once and cached for the process lifetime. The asset is small
/// (~200 KB) so we keep it resident rather than expiring it.
library;

import 'dart:convert';

import 'package:aetherlink_flutter/shared/domain/model_capabilities.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_id_utils.dart';
import 'package:flutter/services.dart' show rootBundle;

const String _assetPath = 'assets/model_registry/models.json';

/// Maps the registry's wire vocabulary (capability slugs + modalities) onto the
/// app's [ModelCapabilities] flags. Returns `null` if nothing maps.
ModelCapabilities? mapRegistryEntryToCapabilities({
  required List<String> capabilities,
  required List<String> inputModalities,
}) {
  final caps = capabilities.toSet();
  final inputs = inputModalities.toSet();

  final vision = caps.contains('image-recognition') || inputs.contains('image');
  final multimodal = vision ||
      caps.contains('audio-recognition') ||
      caps.contains('video-recognition') ||
      inputs.contains('audio') ||
      inputs.contains('video');
  final functionCall = caps.contains('function-call');
  final reasoning = caps.contains('reasoning');
  final imageGen = caps.contains('image-generation');
  final videoGen = caps.contains('video-generation');
  final embedding = caps.contains('embedding');
  final rerank = caps.contains('rerank');
  final webSearch = caps.contains('web-search');
  final transcription = caps.contains('audio-transcript');

  if (!vision &&
      !multimodal &&
      !functionCall &&
      !reasoning &&
      !imageGen &&
      !videoGen &&
      !embedding &&
      !rerank &&
      !webSearch &&
      !transcription) {
    return null;
  }

  return ModelCapabilities(
    vision: vision ? true : null,
    multimodal: multimodal ? true : null,
    functionCalling: functionCall ? true : null,
    toolUse: functionCall ? true : null,
    reasoning: reasoning ? true : null,
    imageGeneration: imageGen ? true : null,
    videoGeneration: videoGen ? true : null,
    embedding: embedding ? true : null,
    rerank: rerank ? true : null,
    webSearch: webSearch ? true : null,
    transcription: transcription ? true : null,
  );
}

/// Lazily-loaded, process-lifetime cache of the bundled preset registry.
class ModelRegistry {
  ModelRegistry._();

  /// Test seam: build a registry directly from a JSON string (same shape as
  /// the asset) without touching the asset bundle.
  factory ModelRegistry.fromJsonString(String json) {
    final reg = ModelRegistry._();
    reg._ingest(json);
    reg._loaded = true;
    return reg;
  }

  /// Shared instance used by the enricher. Tests can construct their own via
  /// [ModelRegistry.fromJsonString].
  static final ModelRegistry instance = ModelRegistry._();

  final Map<String, ModelCapabilities> _byId = {};
  final Map<String, ModelCapabilities> _byNormId = {};
  final Map<String, ModelCapabilities> _bySizedNormId = {};
  bool _loaded = false;
  Future<void>? _loading;

  /// Loads + indexes the asset once. Safe to call repeatedly / concurrently.
  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      _ingest(raw);
    } catch (_) {
      // Missing/corrupt asset must not break model creation — inference still
      // covers it. Mark loaded so we don't retry every lookup.
    } finally {
      _loaded = true;
      _loading = null;
    }
  }

  void _ingest(String raw) {
    final decoded = jsonDecode(raw);
    final models = decoded is Map<String, dynamic> ? decoded['models'] : decoded;
    if (models is! List) return;
    for (final entry in models) {
      if (entry is! Map) continue;
      final id = entry['i']?.toString() ?? entry['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final caps = _stringList(entry['c'] ?? entry['capabilities']);
      final inputs = _stringList(entry['in'] ?? entry['inputModalities']);
      final mapped = mapRegistryEntryToCapabilities(capabilities: caps, inputModalities: inputs);
      if (mapped == null) continue;
      _byId[id] = mapped;
      _byId[id.toLowerCase()] ??= mapped;
      _byNormId.putIfAbsent(normalizeModelId(id), () => mapped);
      _bySizedNormId.putIfAbsent(normalizeModelId(id, keepParameterSize: true), () => mapped);
    }
  }

  static List<String> _stringList(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : const [];

  /// Look up capabilities for [modelId] (exact id → lowercase id → normalized
  /// id). Returns `null` when the model is not a known preset. Caller must
  /// have awaited [ensureLoaded].
  ModelCapabilities? capabilitiesFor(String modelId) {
    if (modelId.isEmpty) return null;
    final exact = _byId[modelId] ?? _byId[modelId.toLowerCase()];
    if (exact != null) return exact;
    // A registry-tag id (`gpt-oss:20b`) carries its size/quant AFTER a colon.
    // Match it size-first so `:20b` lands on `gpt-oss-20b`, never collapsing
    // onto the `gpt-oss-120b` sibling that shares the size-agnostic key. If no
    // exact-size row exists, return null rather than a wrong-size guess.
    if (colonVariantTagToHyphen(modelId) != modelId) {
      return _bySizedNormId[normalizeModelId(modelId, keepParameterSize: true)];
    }
    return _byNormId[normalizeModelId(modelId)];
  }

  /// Number of indexed preset models (distinct ids). For diagnostics/tests.
  int get size => _byId.length;
}
