// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'context_condense_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(contextCondenseService)
final contextCondenseServiceProvider = ContextCondenseServiceProvider._();

final class ContextCondenseServiceProvider
    extends
        $FunctionalProvider<
          ContextCondenseService,
          ContextCondenseService,
          ContextCondenseService
        >
    with $Provider<ContextCondenseService> {
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
    r'4c547f24483bc4f2632734831a8e0666cc6dfc68';
