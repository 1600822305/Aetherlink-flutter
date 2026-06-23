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
}

String _$skillsMpServiceHash() => r'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0';

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
