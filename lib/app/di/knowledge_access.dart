import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/di/network_proxy_access.dart';
import 'package:aetherlink_flutter/core/network/dio_client.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/knowledge/data/knowledge_service.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_embedder.dart';
import 'package:aetherlink_flutter/features/memory/data/embedding_service.dart';
import 'package:aetherlink_flutter/features/memory/domain/embedding_model_key.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

part 'knowledge_access.g.dart';

/// App-level composition seam exposing [KnowledgeService].
///
/// Mirrors `memory_access.dart`: the import-boundary rule forbids the knowledge
/// feature from importing chat's `application`, but the single app-wide Drift
/// handle lives behind chat's `appDatabaseProvider`. So the service is composed
/// here in `app/` (the composition root) and the feature reaches it through
/// this seam. The embedder resolver is likewise composed here — the knowledge
/// core only holds the [KnowledgeEmbedderResolver] function, keeping it testable.
@Riverpod(keepAlive: true)
KnowledgeService knowledgeService(Ref ref) => KnowledgeService(
  ref.watch(appDatabaseProvider).knowledgeDao,
  embedderResolver: (embeddingModelKey) =>
      _resolveKnowledgeEmbedder(ref, embeddingModelKey),
);

/// Resolves a base's `embeddingModelKey` to a ready [KnowledgeEmbedder], or null
/// when the key is unset/malformed or its provider/model no longer exists (→ the
/// service falls back to keyword search). Reuses memory's key codec + model
/// resolution so the two features address embedding models identically.
Future<KnowledgeEmbedder?> _resolveKnowledgeEmbedder(
  Ref ref,
  String? embeddingModelKey,
) async {
  if (embeddingModelKey == null || embeddingModelKey.isEmpty) return null;
  final providers = await ref.read(appModelProvidersProvider.future);
  final model = _resolveEmbeddingModel(providers, embeddingModelKey);
  if (model == null) return null;
  final service = EmbeddingService(
    buildLlmDio(proxy: ref.read(appNetworkProxyConfigProvider)),
  );
  return _EmbeddingServiceEmbedder(service, model);
}

/// Resolves a `providerId\0modelId` key to a fully-merged [Model] (endpoint +
/// credentials via `effectiveModelFor`), or null when unset/malformed or the
/// provider/model no longer exists.
Model? _resolveEmbeddingModel(List<ModelProvider> providers, String? key) {
  final pair = decodeEmbeddingModelKey(key);
  if (pair == null) return null;
  final (providerId, modelId) = pair;
  for (final provider in providers) {
    if (provider.id != providerId) continue;
    for (final model in provider.models) {
      if (model.id == modelId) {
        return effectiveModelFor(
          CurrentModel(provider: provider, model: model),
        );
      }
    }
  }
  return null;
}

/// Adapts the memory feature's protocol-only [EmbeddingService] (which needs a
/// resolved [Model] per call) to the knowledge core's [KnowledgeEmbedder].
class _EmbeddingServiceEmbedder implements KnowledgeEmbedder {
  _EmbeddingServiceEmbedder(this._service, this._model);

  final EmbeddingService _service;
  final Model _model;

  @override
  Future<List<List<double>>> embed(List<String> texts) =>
      _service.embedAll(_model, texts);
}
