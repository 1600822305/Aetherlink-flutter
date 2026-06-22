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
/// It seeds `false` (detailed is the default, matching the original), then
/// hydrates from the Drift key/value store on first build and writes through on
/// every toggle, so the choice survives a full restart (the web persisted this
/// under the `settings-compact-mode` localStorage key).
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
/// It seeds `false` (detailed is the default, matching the original), then
/// hydrates from the Drift key/value store on first build and writes through on
/// every toggle, so the choice survives a full restart (the web persisted this
/// under the `settings-compact-mode` localStorage key).
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
  /// It seeds `false` (detailed is the default, matching the original), then
  /// hydrates from the Drift key/value store on first build and writes through on
  /// every toggle, so the choice survives a full restart (the web persisted this
  /// under the `settings-compact-mode` localStorage key).
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
    r'df20aa948be0f87768b8c0c9403c1d4a2bbdb9d2';

/// Holds the settings hub's "compact ↔ detailed" view mode for the application
/// layer (the page stays a pure view — no business logic, see
/// PROJECT_STRUCTURE / ADR-0009).
///
/// `true` = compact (titles only), `false` = detailed (titles + descriptions).
/// It seeds `false` (detailed is the default, matching the original), then
/// hydrates from the Drift key/value store on first build and writes through on
/// every toggle, so the choice survives a full restart (the web persisted this
/// under the `settings-compact-mode` localStorage key).
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
