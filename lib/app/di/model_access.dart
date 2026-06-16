import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/models/application/model_providers.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/models/domain/repositories/model_repository.dart';
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
}
