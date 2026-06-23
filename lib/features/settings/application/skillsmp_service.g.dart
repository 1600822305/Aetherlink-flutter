// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skillsmp_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Service for interacting with the SkillsMP public API.

@ProviderFor(SkillsMpService)
final skillsMpServiceProvider = SkillsMpServiceProvider._();

/// Service for interacting with the SkillsMP public API.
final class SkillsMpServiceProvider
    extends $NotifierProvider<SkillsMpService, String?> {
  /// Service for interacting with the SkillsMP public API.
  SkillsMpServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'skillsMpServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skillsMpServiceHash();

  @$internal
  @override
  SkillsMpService create() => SkillsMpService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$skillsMpServiceHash() => r'e56cdf85f6dbd158fdccdcc66c5098427204ce78';

/// Service for interacting with the SkillsMP public API.

abstract class _$SkillsMpService extends $Notifier<String?> {
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
