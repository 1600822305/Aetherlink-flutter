import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// Contract for model-provider persistence, owned by the `domain` layer and
/// implemented in `data` (dependency inversion; see `docs/ARCHITECTURE.md`).
///
/// Pure Dart: this file must not import Flutter / dio / drift / riverpod. It
/// covers the `model providers` store carried over from the original
/// IndexedDB schema (`src/shared/config/defaultModels.ts`).
abstract interface class ModelRepository {
  /// All providers in their user-defined order.
  Future<List<ModelProvider>> getProviders();

  Future<ModelProvider?> getProvider(String id);

  /// Inserts or updates a provider. New providers are appended to the end of
  /// the order; updating an existing provider keeps its position.
  Future<void> saveProvider(ModelProvider provider);

  Future<void> deleteProvider(String id);

  /// Reorders providers to match [orderedIds] (position = new order).
  Future<void> reorderProviders(List<String> orderedIds);

  /// Marks [modelId] as the default model within provider [providerId],
  /// clearing `isDefault` on that provider's other models.
  Future<void> setDefaultModel({
    required String providerId,
    required String modelId,
  });

  /// Sets the app-level current model: clears `isDefault` on every model of
  /// every provider and sets it on ([providerId], [modelId]), atomically — the
  /// store never observes a half-applied switch (two defaults, or none).
  Future<void> setCurrentModel({
    required String providerId,
    required String modelId,
  });
}
