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
/// once onboarding is done. It seeds `true` and lives in memory only for M4.1 —
/// mirroring the M4.0 theme controller's "seam, not yet persisted" approach.
///
/// The original gated this on a persisted `first-time-user` flag. Persistence
/// here is a deliberate seam (see [restore]): where app preferences live
/// (shared_preferences vs a Drift settings table) is a separate decision, and
/// M4.1 adds no new dependencies — so the welcome page reappears on each cold
/// start until persistence is wired.
///
/// `keepAlive: true`: this is an app-level flag, not screen-scoped state — it
/// must survive the welcome page being disposed after navigation, so it is not
/// auto-disposed.

@ProviderFor(OnboardingController)
final onboardingControllerProvider = OnboardingControllerProvider._();

/// Tracks whether the first-time welcome page still needs to be shown.
///
/// The state is `true` for a first-time user (show the welcome page) and `false`
/// once onboarding is done. It seeds `true` and lives in memory only for M4.1 —
/// mirroring the M4.0 theme controller's "seam, not yet persisted" approach.
///
/// The original gated this on a persisted `first-time-user` flag. Persistence
/// here is a deliberate seam (see [restore]): where app preferences live
/// (shared_preferences vs a Drift settings table) is a separate decision, and
/// M4.1 adds no new dependencies — so the welcome page reappears on each cold
/// start until persistence is wired.
///
/// `keepAlive: true`: this is an app-level flag, not screen-scoped state — it
/// must survive the welcome page being disposed after navigation, so it is not
/// auto-disposed.
final class OnboardingControllerProvider
    extends $NotifierProvider<OnboardingController, bool> {
  /// Tracks whether the first-time welcome page still needs to be shown.
  ///
  /// The state is `true` for a first-time user (show the welcome page) and `false`
  /// once onboarding is done. It seeds `true` and lives in memory only for M4.1 —
  /// mirroring the M4.0 theme controller's "seam, not yet persisted" approach.
  ///
  /// The original gated this on a persisted `first-time-user` flag. Persistence
  /// here is a deliberate seam (see [restore]): where app preferences live
  /// (shared_preferences vs a Drift settings table) is a separate decision, and
  /// M4.1 adds no new dependencies — so the welcome page reappears on each cold
  /// start until persistence is wired.
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

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$onboardingControllerHash() =>
    r'9ca48f1e3eebe611470b0ebf068e649131c8ed38';

/// Tracks whether the first-time welcome page still needs to be shown.
///
/// The state is `true` for a first-time user (show the welcome page) and `false`
/// once onboarding is done. It seeds `true` and lives in memory only for M4.1 —
/// mirroring the M4.0 theme controller's "seam, not yet persisted" approach.
///
/// The original gated this on a persisted `first-time-user` flag. Persistence
/// here is a deliberate seam (see [restore]): where app preferences live
/// (shared_preferences vs a Drift settings table) is a separate decision, and
/// M4.1 adds no new dependencies — so the welcome page reappears on each cold
/// start until persistence is wired.
///
/// `keepAlive: true`: this is an app-level flag, not screen-scoped state — it
/// must survive the welcome page being disposed after navigation, so it is not
/// auto-disposed.

abstract class _$OnboardingController extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
