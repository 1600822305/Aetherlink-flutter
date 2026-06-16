import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/model_catalog.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway_factory.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_model_catalog.dart';
import 'package:aetherlink_flutter/features/models/application/model_providers.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/models/domain/repositories/model_repository.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

part 'model_access.g.dart';

/// App-level composition seam for cross-feature access to the model store.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's
/// `application` / `data`; only its `domain` is allowed. `chat` and `settings`
/// both need the model store, so the providers that wire it are composed here
/// in `app/` (the composition root, which may depend on any feature). Consumers
/// import this file plus `models`' pure-Dart `domain` types — never
/// `models/application` directly.
///
/// These delegate to `models`' own repository provider, so there is a single
/// repository instance (and a single Drift handle) behind every cross-feature
/// read/write.

/// The model-provider persistence port. Writes (settings CRUD) go through the
/// [ModelStore] controller; this is also the source the read providers query.
@Riverpod(keepAlive: true)
ModelRepository appModelRepository(Ref ref) =>
    ref.watch(modelRepositoryProvider);

/// All persisted providers in user-defined order. Empty on a fresh install.
/// Reads the repository directly so [ModelStore] can refresh it by invalidating
/// this provider after a write.
@riverpod
Future<List<ModelProvider>> appModelProviders(Ref ref) =>
    ref.watch(appModelRepositoryProvider).getProviders();

/// A single provider by [id], or `null` when unknown.
@riverpod
Future<ModelProvider?> appModelProvider(Ref ref, String id) async {
  final providers = await ref.watch(appModelProvidersProvider.future);
  for (final provider in providers) {
    if (provider.id == id) return provider;
  }
  return null;
}

/// The app-level current chat model, or `null` when none is selected. Derived
/// from [appModelProviders] (the first model flagged `isDefault`), so it
/// refreshes whenever the provider store changes.
@riverpod
Future<CurrentModel?> appCurrentModel(Ref ref) async {
  final providers = await ref.watch(appModelProvidersProvider.future);
  return findCurrentModel(providers);
}

/// The model-catalog port for `自动获取模型`. Composed here (the root may depend
/// on `chat/data`) so the settings UI can list a provider's models through the
/// pure-Dart port without importing `chat`'s `data`. Tests override it with a
/// fake catalog.
@Riverpod(keepAlive: true)
LlmModelCatalog appModelCatalog(Ref ref) => LlmModelCatalogImpl();

/// The LLM gateway factory for the settings 测试模式 (per-model connectivity
/// test). Re-exposed from `chat`'s composed factory so the settings UI can run
/// a one-shot `streamChat` through the pure-Dart port without importing `chat`'s
/// `application` directly (the import-boundary rule only constrains
/// feature↔feature edges — `app/` is the composition root).
@Riverpod(keepAlive: true)
LlmGatewayFactory appLlmGatewayFactory(Ref ref) =>
    ref.watch(llmGatewayFactoryProvider);

/// Write API over the model store for the settings UI. Every mutation persists
/// through the [ModelRepository] port and then invalidates
/// [appModelProviders] so the lists and the current-model selection refresh.
///
/// Kept alive because callers only `read` it to fire a mutation (no widget
/// watches it): an autoDispose notifier could be disposed between the awaited
/// write and the `ref.invalidate` that follows, throwing.
@Riverpod(keepAlive: true)
class ModelStore extends _$ModelStore {
  @override
  void build() {}

  ModelRepository get _repo => ref.read(appModelRepositoryProvider);

  Future<void> saveProvider(ModelProvider provider) async {
    await _repo.saveProvider(provider);
    ref.invalidate(appModelProvidersProvider);
  }

  Future<void> deleteProvider(String id) async {
    await _repo.deleteProvider(id);
    ref.invalidate(appModelProvidersProvider);
  }

  Future<void> reorderProviders(List<String> orderedIds) async {
    await _repo.reorderProviders(orderedIds);
    ref.invalidate(appModelProvidersProvider);
  }

  /// Sets the app-level current chat model, clearing `isDefault` on every other
  /// model and setting it on ([providerId], [modelId]). Persists only the
  /// providers whose models actually changed.
  Future<void> selectCurrentModel({
    required String providerId,
    required String modelId,
  }) async {
    final providers = await _repo.getProviders();
    final updated = providersWithCurrentModel(
      providers,
      providerId: providerId,
      modelId: modelId,
    );
    for (var i = 0; i < providers.length; i++) {
      if (updated[i] != providers[i]) {
        await _repo.saveProvider(updated[i]);
      }
    }
    ref.invalidate(appModelProvidersProvider);
  }

  /// Merges [models] into [providerId]'s model list (de-duplicating by id, new
  /// entries appended; existing models keep their config) and persists. Used by
  /// the detail page after fetching a provider's catalog.
  Future<void> addModels({
    required String providerId,
    required List<Model> models,
  }) async {
    if (models.isEmpty) return;
    final provider = await _repo.getProvider(providerId);
    if (provider == null) return;
    final existingIds = {for (final m in provider.models) m.id};
    final additions = [
      for (final m in models)
        if (existingIds.add(m.id)) m,
    ];
    if (additions.isEmpty) return;
    await _repo.saveProvider(
      provider.copyWith(models: [...provider.models, ...additions]),
    );
    ref.invalidate(appModelProvidersProvider);
  }
}
