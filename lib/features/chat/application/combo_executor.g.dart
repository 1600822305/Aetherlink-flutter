// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'combo_executor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Resolves a combo configuration's model entries into actual Model+Provider
/// objects from the persisted providers.

@ProviderFor(resolveCombo)
final resolveComboProvider = ResolveComboFamily._();

/// Resolves a combo configuration's model entries into actual Model+Provider
/// objects from the persisted providers.

final class ResolveComboProvider
    extends
        $FunctionalProvider<
          AsyncValue<ComboResolution?>,
          ComboResolution?,
          FutureOr<ComboResolution?>
        >
    with $FutureModifier<ComboResolution?>, $FutureProvider<ComboResolution?> {
  /// Resolves a combo configuration's model entries into actual Model+Provider
  /// objects from the persisted providers.
  ResolveComboProvider._({
    required ResolveComboFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'resolveComboProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$resolveComboHash();

  @override
  String toString() {
    return r'resolveComboProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ComboResolution?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ComboResolution?> create(Ref ref) {
    final argument = this.argument as String;
    return resolveCombo(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ResolveComboProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$resolveComboHash() => r'cb83689803c9cb65962c046e20efc7b268c74c5d';

/// Resolves a combo configuration's model entries into actual Model+Provider
/// objects from the persisted providers.

final class ResolveComboFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ComboResolution?>, String> {
  ResolveComboFamily._()
    : super(
        retry: null,
        name: r'resolveComboProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Resolves a combo configuration's model entries into actual Model+Provider
  /// objects from the persisted providers.

  ResolveComboProvider call(String comboId) =>
      ResolveComboProvider._(argument: comboId, from: this);

  @override
  String toString() => r'resolveComboProvider';
}
