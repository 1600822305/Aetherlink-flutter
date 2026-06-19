// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tracks whether the first-time welcome page still needs to be shown.
///
/// The state is `true` for a first-time user (show the welcome page) and `false`
/// once onboarding is done. It hydrates from the Drift key/value store: the web
/// gated `/welcome` on whether `first-time-user` was absent
/// (`firstTimeUserValue === null`), so a missing key → still needs onboarding,
/// and any stored value → done.
///
/// `keepAlive: true`: this is an app-level flag, not screen-scoped state — it
/// must survive the welcome page being disposed after navigation, so it is not
/// auto-disposed.

@ProviderFor(OnboardingController)
final onboardingControllerProvider = OnboardingControllerProvider._();

/// Tracks whether the first-time welcome page still needs to be shown.
///
/// The state is `true` for a first-time user (show the welcome page) and `false`
/// once onboarding is done. It hydrates from the Drift key/value store: the web
/// gated `/welcome` on whether `first-time-user` was absent
/// (`firstTimeUserValue === null`), so a missing key → still needs onboarding,
/// and any stored value → done.
///
/// `keepAlive: true`: this is an app-level flag, not screen-scoped state — it
/// must survive the welcome page being disposed after navigation, so it is not
/// auto-disposed.
final class OnboardingControllerProvider
    extends $AsyncNotifierProvider<OnboardingController, bool> {
  /// Tracks whether the first-time welcome page still needs to be shown.
  ///
  /// The state is `true` for a first-time user (show the welcome page) and `false`
  /// once onboarding is done. It hydrates from the Drift key/value store: the web
  /// gated `/welcome` on whether `first-time-user` was absent
  /// (`firstTimeUserValue === null`), so a missing key → still needs onboarding,
  /// and any stored value → done.
  ///
  /// `keepAlive: true`: this is an app-level flag, not screen-scoped state — it
  /// must survive the welcome page being disposed after navigation, so it is not
  /// auto-disposed.
  OnboardingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingControllerHash();

  @$internal
  @override
  OnboardingController create() => OnboardingController();
}

String _$onboardingControllerHash() =>
    r'dd98b0fe6e593157639c1073a13e328e82641640';

/// Tracks whether the first-time welcome page still needs to be shown.
///
/// The state is `true` for a first-time user (show the welcome page) and `false`
/// once onboarding is done. It hydrates from the Drift key/value store: the web
/// gated `/welcome` on whether `first-time-user` was absent
/// (`firstTimeUserValue === null`), so a missing key → still needs onboarding,
/// and any stored value → done.
///
/// `keepAlive: true`: this is an app-level flag, not screen-scoped state — it
/// must survive the welcome page being disposed after navigation, so it is not
/// auto-disposed.

abstract class _$OnboardingController extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
