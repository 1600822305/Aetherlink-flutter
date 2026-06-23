// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'context_condense_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The provider is a thin shell that resolves all Ref-dependent values
/// *synchronously* and delegates to the stateless [ContextCondenseService].
/// Because the service itself never touches Ref, it is immune to provider
/// disposal during long-running async work.

@ProviderFor(contextCondenseService)
final contextCondenseServiceProvider = ContextCondenseServiceProvider._();

/// The provider is a thin shell that resolves all Ref-dependent values
/// *synchronously* and delegates to the stateless [ContextCondenseService].
/// Because the service itself never touches Ref, it is immune to provider
/// disposal during long-running async work.

final class ContextCondenseServiceProvider
    extends
        $FunctionalProvider<
          ContextCondenseService,
          ContextCondenseService,
          ContextCondenseService
        >
    with $Provider<ContextCondenseService> {
  /// The provider is a thin shell that resolves all Ref-dependent values
  /// *synchronously* and delegates to the stateless [ContextCondenseService].
  /// Because the service itself never touches Ref, it is immune to provider
  /// disposal during long-running async work.
  ContextCondenseServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contextCondenseServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contextCondenseServiceHash();

  @$internal
  @override
  $ProviderElement<ContextCondenseService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ContextCondenseService create(Ref ref) {
    return contextCondenseService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ContextCondenseService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ContextCondenseService>(value),
    );
  }
}

String _$contextCondenseServiceHash() =>
    r'8eefbac881b454539c7a40650935b353e06e5df4';
