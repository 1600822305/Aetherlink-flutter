// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_access.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(appModelRepository)
final appModelRepositoryProvider = AppModelRepositoryProvider._();

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

final class AppModelRepositoryProvider
    extends
        $FunctionalProvider<ModelRepository, ModelRepository, ModelRepository>
    with $Provider<ModelRepository> {
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
  AppModelRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appModelRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appModelRepositoryHash();

  @$internal
  @override
  $ProviderElement<ModelRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ModelRepository create(Ref ref) {
    return appModelRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelRepository>(value),
    );
  }
}

String _$appModelRepositoryHash() =>
    r'a7542390a5c8571ee808a59c3ea0b78621d38bf6';

/// All persisted providers in user-defined order. Empty on a fresh install.
/// Reads the repository directly so [ModelStore] can refresh it by invalidating
/// this provider after a write.

@ProviderFor(appModelProviders)
final appModelProvidersProvider = AppModelProvidersProvider._();

/// All persisted providers in user-defined order. Empty on a fresh install.
/// Reads the repository directly so [ModelStore] can refresh it by invalidating
/// this provider after a write.

final class AppModelProvidersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ModelProvider>>,
          List<ModelProvider>,
          FutureOr<List<ModelProvider>>
        >
    with
        $FutureModifier<List<ModelProvider>>,
        $FutureProvider<List<ModelProvider>> {
  /// All persisted providers in user-defined order. Empty on a fresh install.
  /// Reads the repository directly so [ModelStore] can refresh it by invalidating
  /// this provider after a write.
  AppModelProvidersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appModelProvidersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appModelProvidersHash();

  @$internal
  @override
  $FutureProviderElement<List<ModelProvider>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ModelProvider>> create(Ref ref) {
    return appModelProviders(ref);
  }
}

String _$appModelProvidersHash() => r'837e8c05c4bfc0fdc54a8e7188e14385bbcc05c2';

/// A single provider by [id], or `null` when unknown.

@ProviderFor(appModelProvider)
final appModelProviderProvider = AppModelProviderFamily._();

/// A single provider by [id], or `null` when unknown.

final class AppModelProviderProvider
    extends
        $FunctionalProvider<
          AsyncValue<ModelProvider?>,
          ModelProvider?,
          FutureOr<ModelProvider?>
        >
    with $FutureModifier<ModelProvider?>, $FutureProvider<ModelProvider?> {
  /// A single provider by [id], or `null` when unknown.
  AppModelProviderProvider._({
    required AppModelProviderFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'appModelProviderProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$appModelProviderHash();

  @override
  String toString() {
    return r'appModelProviderProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ModelProvider?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ModelProvider?> create(Ref ref) {
    final argument = this.argument as String;
    return appModelProvider(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AppModelProviderProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$appModelProviderHash() => r'93584ee3505823d79309d6e76aff5ce63735995e';

/// A single provider by [id], or `null` when unknown.

final class AppModelProviderFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ModelProvider?>, String> {
  AppModelProviderFamily._()
    : super(
        retry: null,
        name: r'appModelProviderProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A single provider by [id], or `null` when unknown.

  AppModelProviderProvider call(String id) =>
      AppModelProviderProvider._(argument: id, from: this);

  @override
  String toString() => r'appModelProviderProvider';
}

/// The app-level current chat model, or `null` when none is selected. Derived
/// from [appModelProviders] (the first model flagged `isDefault`), so it
/// refreshes whenever the provider store changes.

@ProviderFor(appCurrentModel)
final appCurrentModelProvider = AppCurrentModelProvider._();

/// The app-level current chat model, or `null` when none is selected. Derived
/// from [appModelProviders] (the first model flagged `isDefault`), so it
/// refreshes whenever the provider store changes.

final class AppCurrentModelProvider
    extends
        $FunctionalProvider<
          AsyncValue<CurrentModel?>,
          CurrentModel?,
          FutureOr<CurrentModel?>
        >
    with $FutureModifier<CurrentModel?>, $FutureProvider<CurrentModel?> {
  /// The app-level current chat model, or `null` when none is selected. Derived
  /// from [appModelProviders] (the first model flagged `isDefault`), so it
  /// refreshes whenever the provider store changes.
  AppCurrentModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appCurrentModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appCurrentModelHash();

  @$internal
  @override
  $FutureProviderElement<CurrentModel?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CurrentModel?> create(Ref ref) {
    return appCurrentModel(ref);
  }
}

String _$appCurrentModelHash() => r'ba18069a341eb110b9c2b1aace475c0cb0587daf';

/// The model-catalog port for `自动获取模型`. Composed here (the root may depend
/// on `chat/data`) so the settings UI can list a provider's models through the
/// pure-Dart port without importing `chat`'s `data`. Tests override it with a
/// fake catalog.

@ProviderFor(appModelCatalog)
final appModelCatalogProvider = AppModelCatalogProvider._();

/// The model-catalog port for `自动获取模型`. Composed here (the root may depend
/// on `chat/data`) so the settings UI can list a provider's models through the
/// pure-Dart port without importing `chat`'s `data`. Tests override it with a
/// fake catalog.

final class AppModelCatalogProvider
    extends
        $FunctionalProvider<LlmModelCatalog, LlmModelCatalog, LlmModelCatalog>
    with $Provider<LlmModelCatalog> {
  /// The model-catalog port for `自动获取模型`. Composed here (the root may depend
  /// on `chat/data`) so the settings UI can list a provider's models through the
  /// pure-Dart port without importing `chat`'s `data`. Tests override it with a
  /// fake catalog.
  AppModelCatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appModelCatalogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appModelCatalogHash();

  @$internal
  @override
  $ProviderElement<LlmModelCatalog> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LlmModelCatalog create(Ref ref) {
    return appModelCatalog(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LlmModelCatalog value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LlmModelCatalog>(value),
    );
  }
}

String _$appModelCatalogHash() => r'2642aa6fc0ca2550261234a54f941eb5ffe76f3a';

/// The LLM gateway factory for the settings 测试模式 (per-model connectivity
/// test). Re-exposed from `chat`'s composed factory so the settings UI can run
/// a one-shot `streamChat` through the pure-Dart port without importing `chat`'s
/// `application` directly (the import-boundary rule only constrains
/// feature↔feature edges — `app/` is the composition root).

@ProviderFor(appLlmGatewayFactory)
final appLlmGatewayFactoryProvider = AppLlmGatewayFactoryProvider._();

/// The LLM gateway factory for the settings 测试模式 (per-model connectivity
/// test). Re-exposed from `chat`'s composed factory so the settings UI can run
/// a one-shot `streamChat` through the pure-Dart port without importing `chat`'s
/// `application` directly (the import-boundary rule only constrains
/// feature↔feature edges — `app/` is the composition root).

final class AppLlmGatewayFactoryProvider
    extends
        $FunctionalProvider<
          LlmGatewayFactory,
          LlmGatewayFactory,
          LlmGatewayFactory
        >
    with $Provider<LlmGatewayFactory> {
  /// The LLM gateway factory for the settings 测试模式 (per-model connectivity
  /// test). Re-exposed from `chat`'s composed factory so the settings UI can run
  /// a one-shot `streamChat` through the pure-Dart port without importing `chat`'s
  /// `application` directly (the import-boundary rule only constrains
  /// feature↔feature edges — `app/` is the composition root).
  AppLlmGatewayFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appLlmGatewayFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appLlmGatewayFactoryHash();

  @$internal
  @override
  $ProviderElement<LlmGatewayFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LlmGatewayFactory create(Ref ref) {
    return appLlmGatewayFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LlmGatewayFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LlmGatewayFactory>(value),
    );
  }
}

String _$appLlmGatewayFactoryHash() =>
    r'275e14e3575e35c5ca63e825f60b2088ce45c161';

/// Write API over the model store for the settings UI. Every mutation persists
/// through the [ModelRepository] port and then invalidates
/// [appModelProviders] so the lists and the current-model selection refresh.
///
/// Kept alive because callers only `read` it to fire a mutation (no widget
/// watches it): an autoDispose notifier could be disposed between the awaited
/// write and the `ref.invalidate` that follows, throwing.

@ProviderFor(ModelStore)
final modelStoreProvider = ModelStoreProvider._();

/// Write API over the model store for the settings UI. Every mutation persists
/// through the [ModelRepository] port and then invalidates
/// [appModelProviders] so the lists and the current-model selection refresh.
///
/// Kept alive because callers only `read` it to fire a mutation (no widget
/// watches it): an autoDispose notifier could be disposed between the awaited
/// write and the `ref.invalidate` that follows, throwing.
final class ModelStoreProvider extends $NotifierProvider<ModelStore, void> {
  /// Write API over the model store for the settings UI. Every mutation persists
  /// through the [ModelRepository] port and then invalidates
  /// [appModelProviders] so the lists and the current-model selection refresh.
  ///
  /// Kept alive because callers only `read` it to fire a mutation (no widget
  /// watches it): an autoDispose notifier could be disposed between the awaited
  /// write and the `ref.invalidate` that follows, throwing.
  ModelStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelStoreHash();

  @$internal
  @override
  ModelStore create() => ModelStore();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$modelStoreHash() => r'810bc4ccc1b3c97fe89c1411f19bfc4a4b3f3c7f';

/// Write API over the model store for the settings UI. Every mutation persists
/// through the [ModelRepository] port and then invalidates
/// [appModelProviders] so the lists and the current-model selection refresh.
///
/// Kept alive because callers only `read` it to fire a mutation (no widget
/// watches it): an autoDispose notifier could be disposed between the awaited
/// write and the `ref.invalidate` that follows, throwing.

abstract class _$ModelStore extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
