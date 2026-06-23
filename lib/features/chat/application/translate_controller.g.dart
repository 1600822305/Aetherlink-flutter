// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'translate_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The selected source language `langCode`, or [kTranslateAutoLang]. Hydrated
/// from / written through to persisted storage.

@ProviderFor(TranslateSourceLanguage)
final translateSourceLanguageProvider = TranslateSourceLanguageProvider._();

/// The selected source language `langCode`, or [kTranslateAutoLang]. Hydrated
/// from / written through to persisted storage.
final class TranslateSourceLanguageProvider
    extends $NotifierProvider<TranslateSourceLanguage, String> {
  /// The selected source language `langCode`, or [kTranslateAutoLang]. Hydrated
  /// from / written through to persisted storage.
  TranslateSourceLanguageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'translateSourceLanguageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$translateSourceLanguageHash();

  @$internal
  @override
  TranslateSourceLanguage create() => TranslateSourceLanguage();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$translateSourceLanguageHash() =>
    r'8d8b9a6c6fc39a23c99d38759306ac56236d4d05';

/// The selected source language `langCode`, or [kTranslateAutoLang]. Hydrated
/// from / written through to persisted storage.

abstract class _$TranslateSourceLanguage extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The selected target language `langCode` (defaults to English). Hydrated from
/// / written through to persisted storage.

@ProviderFor(TranslateTargetLanguage)
final translateTargetLanguageProvider = TranslateTargetLanguageProvider._();

/// The selected target language `langCode` (defaults to English). Hydrated from
/// / written through to persisted storage.
final class TranslateTargetLanguageProvider
    extends $NotifierProvider<TranslateTargetLanguage, String> {
  /// The selected target language `langCode` (defaults to English). Hydrated from
  /// / written through to persisted storage.
  TranslateTargetLanguageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'translateTargetLanguageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$translateTargetLanguageHash();

  @$internal
  @override
  TranslateTargetLanguage create() => TranslateTargetLanguage();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$translateTargetLanguageHash() =>
    r'5acde2a30d19c959b5a203a93e728462a273d5f4';

/// The selected target language `langCode` (defaults to English). Hydrated from
/// / written through to persisted storage.

abstract class _$TranslateTargetLanguage extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The persisted translate model key (`providerId\u0000modelId`), or `null` to
/// fall back to the app's current chat model.
///
/// Single source of truth: [AuxiliaryModelController.translateModelKey].
/// This provider derives its state from the auxiliary controller so that
/// the sidebar translate page, message toolbar, and settings all share the
/// same selection.

@ProviderFor(TranslateModelSelection)
final translateModelSelectionProvider = TranslateModelSelectionProvider._();

/// The persisted translate model key (`providerId\u0000modelId`), or `null` to
/// fall back to the app's current chat model.
///
/// Single source of truth: [AuxiliaryModelController.translateModelKey].
/// This provider derives its state from the auxiliary controller so that
/// the sidebar translate page, message toolbar, and settings all share the
/// same selection.
final class TranslateModelSelectionProvider
    extends $NotifierProvider<TranslateModelSelection, String?> {
  /// The persisted translate model key (`providerId\u0000modelId`), or `null` to
  /// fall back to the app's current chat model.
  ///
  /// Single source of truth: [AuxiliaryModelController.translateModelKey].
  /// This provider derives its state from the auxiliary controller so that
  /// the sidebar translate page, message toolbar, and settings all share the
  /// same selection.
  TranslateModelSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'translateModelSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$translateModelSelectionHash();

  @$internal
  @override
  TranslateModelSelection create() => TranslateModelSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$translateModelSelectionHash() =>
    r'1b952c8d8faba62ac5dfb4093ad3ce745914a58e';

/// The persisted translate model key (`providerId\u0000modelId`), or `null` to
/// fall back to the app's current chat model.
///
/// Single source of truth: [AuxiliaryModelController.translateModelKey].
/// This provider derives its state from the auxiliary controller so that
/// the sidebar translate page, message toolbar, and settings all share the
/// same selection.

abstract class _$TranslateModelSelection extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The model used for translation: the persisted [TranslateModelSelection] when
/// it still resolves to a known model, otherwise the app's current chat model
/// (port of `getTranslateModel`'s "use the configured model or the first
/// available" fallback).

@ProviderFor(translateModel)
final translateModelProvider = TranslateModelProvider._();

/// The model used for translation: the persisted [TranslateModelSelection] when
/// it still resolves to a known model, otherwise the app's current chat model
/// (port of `getTranslateModel`'s "use the configured model or the first
/// available" fallback).

final class TranslateModelProvider
    extends
        $FunctionalProvider<
          AsyncValue<CurrentModel?>,
          CurrentModel?,
          FutureOr<CurrentModel?>
        >
    with $FutureModifier<CurrentModel?>, $FutureProvider<CurrentModel?> {
  /// The model used for translation: the persisted [TranslateModelSelection] when
  /// it still resolves to a known model, otherwise the app's current chat model
  /// (port of `getTranslateModel`'s "use the configured model or the first
  /// available" fallback).
  TranslateModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'translateModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$translateModelHash();

  @$internal
  @override
  $FutureProviderElement<CurrentModel?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CurrentModel?> create(Ref ref) {
    return translateModel(ref);
  }
}

String _$translateModelHash() => r'4e584a8f42bafcc301a47c9a419bc46a6bce1561';

/// The translation history list, newest first. Drift-backed port of the web
/// `getTranslateHistories` / `saveTranslateHistory` / … `localStorage` helpers.

@ProviderFor(TranslateHistoryStore)
final translateHistoryStoreProvider = TranslateHistoryStoreProvider._();

/// The translation history list, newest first. Drift-backed port of the web
/// `getTranslateHistories` / `saveTranslateHistory` / … `localStorage` helpers.
final class TranslateHistoryStoreProvider
    extends
        $AsyncNotifierProvider<TranslateHistoryStore, List<TranslateHistory>> {
  /// The translation history list, newest first. Drift-backed port of the web
  /// `getTranslateHistories` / `saveTranslateHistory` / … `localStorage` helpers.
  TranslateHistoryStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'translateHistoryStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$translateHistoryStoreHash();

  @$internal
  @override
  TranslateHistoryStore create() => TranslateHistoryStore();
}

String _$translateHistoryStoreHash() =>
    r'41e0605b5d7f2a1970a3bb915183ae283b8c7f7c';

/// The translation history list, newest first. Drift-backed port of the web
/// `getTranslateHistories` / `saveTranslateHistory` / … `localStorage` helpers.

abstract class _$TranslateHistoryStore
    extends $AsyncNotifier<List<TranslateHistory>> {
  FutureOr<List<TranslateHistory>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<TranslateHistory>>, List<TranslateHistory>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<TranslateHistory>>,
                List<TranslateHistory>
              >,
              AsyncValue<List<TranslateHistory>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
