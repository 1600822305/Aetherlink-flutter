// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auxiliary_model_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller that reads/writes the 7 default model selections + prompts
/// through the [ChatRepository] key/value store.

@ProviderFor(AuxiliaryModelController)
final auxiliaryModelControllerProvider = AuxiliaryModelControllerProvider._();

/// Controller that reads/writes the 7 default model selections + prompts
/// through the [ChatRepository] key/value store.
final class AuxiliaryModelControllerProvider
    extends $NotifierProvider<AuxiliaryModelController, AuxiliaryModelState> {
  /// Controller that reads/writes the 7 default model selections + prompts
  /// through the [ChatRepository] key/value store.
  AuxiliaryModelControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'auxiliaryModelControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$auxiliaryModelControllerHash();

  @$internal
  @override
  AuxiliaryModelController create() => AuxiliaryModelController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuxiliaryModelState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuxiliaryModelState>(value),
    );
  }
}

String _$auxiliaryModelControllerHash() =>
    r'1e5730e3a1c07b872e954d60ddb0a3504036b1d6';

/// Controller that reads/writes the 7 default model selections + prompts
/// through the [ChatRepository] key/value store.

abstract class _$AuxiliaryModelController
    extends $Notifier<AuxiliaryModelState> {
  AuxiliaryModelState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AuxiliaryModelState, AuxiliaryModelState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AuxiliaryModelState, AuxiliaryModelState>,
              AuxiliaryModelState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Resolves a stored model key to a display name like "Provider / Model".
/// Returns `null` if unresolvable.

@ProviderFor(auxiliaryModelDisplayName)
final auxiliaryModelDisplayNameProvider = AuxiliaryModelDisplayNameFamily._();

/// Resolves a stored model key to a display name like "Provider / Model".
/// Returns `null` if unresolvable.

final class AuxiliaryModelDisplayNameProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// Resolves a stored model key to a display name like "Provider / Model".
  /// Returns `null` if unresolvable.
  AuxiliaryModelDisplayNameProvider._({
    required AuxiliaryModelDisplayNameFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'auxiliaryModelDisplayNameProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$auxiliaryModelDisplayNameHash();

  @override
  String toString() {
    return r'auxiliaryModelDisplayNameProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    final argument = this.argument as String?;
    return auxiliaryModelDisplayName(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is AuxiliaryModelDisplayNameProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$auxiliaryModelDisplayNameHash() =>
    r'1caa9c39f95be2541a01410d14595cef8ba998af';

/// Resolves a stored model key to a display name like "Provider / Model".
/// Returns `null` if unresolvable.

final class AuxiliaryModelDisplayNameFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String?>, String?> {
  AuxiliaryModelDisplayNameFamily._()
    : super(
        retry: null,
        name: r'auxiliaryModelDisplayNameProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Resolves a stored model key to a display name like "Provider / Model".
  /// Returns `null` if unresolvable.

  AuxiliaryModelDisplayNameProvider call(String? modelKey) =>
      AuxiliaryModelDisplayNameProvider._(argument: modelKey, from: this);

  @override
  String toString() => r'auxiliaryModelDisplayNameProvider';
}
