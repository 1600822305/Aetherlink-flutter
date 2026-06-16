// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(modelRepository)
final modelRepositoryProvider = ModelRepositoryProvider._();

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

final class ModelRepositoryProvider
    extends
        $FunctionalProvider<ModelRepository, ModelRepository, ModelRepository>
    with $Provider<ModelRepository> {
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
  ModelRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelRepositoryHash();

  @$internal
  @override
  $ProviderElement<ModelRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ModelRepository create(Ref ref) {
    return modelRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelRepository>(value),
    );
  }
}

String _$modelRepositoryHash() => r'f391240c09b75940ae4262f73876a5c1bf54af29';

/// All persisted providers in their user-defined order. Empty on a fresh
/// install (the seed is never written automatically).

@ProviderFor(modelProviders)
final modelProvidersProvider = ModelProvidersProvider._();

/// All persisted providers in their user-defined order. Empty on a fresh
/// install (the seed is never written automatically).

final class ModelProvidersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ModelProvider>>,
          List<ModelProvider>,
          FutureOr<List<ModelProvider>>
        >
    with
        $FutureModifier<List<ModelProvider>>,
        $FutureProvider<List<ModelProvider>> {
  /// All persisted providers in their user-defined order. Empty on a fresh
  /// install (the seed is never written automatically).
  ModelProvidersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelProvidersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelProvidersHash();

  @$internal
  @override
  $FutureProviderElement<List<ModelProvider>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ModelProvider>> create(Ref ref) {
    return modelProviders(ref);
  }
}

String _$modelProvidersHash() => r'864b2320c1e14172da1c440126a1eca28d1593eb';
