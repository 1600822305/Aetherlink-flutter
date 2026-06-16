import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/models/application/default_model_providers.dart';
import 'package:aetherlink_flutter/features/models/data/repositories/model_repository_impl.dart';
import 'package:aetherlink_flutter/features/models/domain/repositories/model_repository.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

part 'model_providers.g.dart';

/// Application-layer DI seam + read view-model for model providers.
///
/// Upper layers depend on the [ModelRepository] port; [modelRepositoryProvider]
/// is the one place the `data` implementation is wired in (same composition
/// pattern as `chat_providers.dart`'s `chatRepositoryProvider`). An empty store
/// yields an empty list — a fresh install ships no providers, which the model
/// UI renders as its empty state.
///
/// NOTE (single-DB seam): this opens its own [AppDatabase] handle, mirroring
/// how `chat_providers.dart` opens the app-wide DB. The DB provider is not yet
/// hoisted into `core/database`, so each feature opens its own handle; sharing
/// a single instance across features is a small follow-up (point both at one
/// `core/database` provider) deliberately left out of this data-layer slice to
/// avoid touching the in-flight chat / settings tracks.

/// The model-provider persistence port, backed by Drift. The repository owns
/// the [AppDatabase], which is kept alive for the app's lifetime and closed
/// when the container disposes.
@Riverpod(keepAlive: true)
ModelRepository modelRepository(Ref ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return ModelRepositoryImpl(db);
}

/// All persisted providers in their user-defined order. Empty on a fresh
/// install (the seed is never written automatically).
@riverpod
Future<List<ModelProvider>> modelProviders(Ref ref) {
  return ref.watch(modelRepositoryProvider).getProviders();
}

/// Writes [defaultModelProviders] into the store — but only when it is empty,
/// so it is safe to call more than once. This is the explicit, opt-in seed
/// referenced by the handoff: it is NEVER run automatically (no provider
/// watches it), so first launch stays empty until a caller (e.g. a "restore
/// defaults" action) invokes it. Goes through the real [ModelRepository] port,
/// never a mock.
Future<void> seedDefaultModelProviders(ModelRepository repository) async {
  final existing = await repository.getProviders();
  if (existing.isNotEmpty) {
    return;
  }
  for (final provider in defaultModelProviders()) {
    await repository.saveProvider(provider);
  }
}
