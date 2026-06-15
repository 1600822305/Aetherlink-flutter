// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_view_mode_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the settings hub's "compact ↔ detailed" view mode for the application
/// layer (the page stays a pure view — no business logic, see
/// PROJECT_STRUCTURE / ADR-0009).
///
/// `true` = compact (titles only), `false` = detailed (titles + descriptions).
/// It seeds `false` (detailed is the default, matching the original) and lives
/// in memory only for this milestone — mirroring the M4.1 onboarding
/// controller's "seam, not yet persisted" approach.
///
/// The original persisted this under the `settings-compact-mode` localStorage
/// key. Where app preferences live (shared_preferences vs a Drift settings
/// table) is a separate decision, and this milestone adds no new persistence —
/// so the mode resets to detailed on each cold start until persistence is
/// wired.
///
/// `keepAlive: true`: this is an app-level UI preference, not screen-scoped
/// state — it must survive the settings page being disposed when navigating
/// into a sub-page and back, so it is not auto-disposed.

@ProviderFor(SettingsViewModeController)
final settingsViewModeControllerProvider =
    SettingsViewModeControllerProvider._();

/// Holds the settings hub's "compact ↔ detailed" view mode for the application
/// layer (the page stays a pure view — no business logic, see
/// PROJECT_STRUCTURE / ADR-0009).
///
/// `true` = compact (titles only), `false` = detailed (titles + descriptions).
/// It seeds `false` (detailed is the default, matching the original) and lives
/// in memory only for this milestone — mirroring the M4.1 onboarding
/// controller's "seam, not yet persisted" approach.
///
/// The original persisted this under the `settings-compact-mode` localStorage
/// key. Where app preferences live (shared_preferences vs a Drift settings
/// table) is a separate decision, and this milestone adds no new persistence —
/// so the mode resets to detailed on each cold start until persistence is
/// wired.
///
/// `keepAlive: true`: this is an app-level UI preference, not screen-scoped
/// state — it must survive the settings page being disposed when navigating
/// into a sub-page and back, so it is not auto-disposed.
final class SettingsViewModeControllerProvider
    extends $NotifierProvider<SettingsViewModeController, bool> {
  /// Holds the settings hub's "compact ↔ detailed" view mode for the application
  /// layer (the page stays a pure view — no business logic, see
  /// PROJECT_STRUCTURE / ADR-0009).
  ///
  /// `true` = compact (titles only), `false` = detailed (titles + descriptions).
  /// It seeds `false` (detailed is the default, matching the original) and lives
  /// in memory only for this milestone — mirroring the M4.1 onboarding
  /// controller's "seam, not yet persisted" approach.
  ///
  /// The original persisted this under the `settings-compact-mode` localStorage
  /// key. Where app preferences live (shared_preferences vs a Drift settings
  /// table) is a separate decision, and this milestone adds no new persistence —
  /// so the mode resets to detailed on each cold start until persistence is
  /// wired.
  ///
  /// `keepAlive: true`: this is an app-level UI preference, not screen-scoped
  /// state — it must survive the settings page being disposed when navigating
  /// into a sub-page and back, so it is not auto-disposed.
  SettingsViewModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsViewModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsViewModeControllerHash();

  @$internal
  @override
  SettingsViewModeController create() => SettingsViewModeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$settingsViewModeControllerHash() =>
    r'df5830d852d2574c33827e86469afc3d0f84cee1';

/// Holds the settings hub's "compact ↔ detailed" view mode for the application
/// layer (the page stays a pure view — no business logic, see
/// PROJECT_STRUCTURE / ADR-0009).
///
/// `true` = compact (titles only), `false` = detailed (titles + descriptions).
/// It seeds `false` (detailed is the default, matching the original) and lives
/// in memory only for this milestone — mirroring the M4.1 onboarding
/// controller's "seam, not yet persisted" approach.
///
/// The original persisted this under the `settings-compact-mode` localStorage
/// key. Where app preferences live (shared_preferences vs a Drift settings
/// table) is a separate decision, and this milestone adds no new persistence —
/// so the mode resets to detailed on each cold start until persistence is
/// wired.
///
/// `keepAlive: true`: this is an app-level UI preference, not screen-scoped
/// state — it must survive the settings page being disposed when navigating
/// into a sub-page and back, so it is not auto-disposed.

abstract class _$SettingsViewModeController extends $Notifier<bool> {
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
