// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'behavior_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the 行为 settings (the original `settingsSlice` behavior fields), so
/// the 行为 page stays a pure view and the chat composer / haptic service can
/// read them.
///
/// `keepAlive: true`: an app-level preference shared by the settings page, the
/// chat composer (Enter-to-send) and the global haptic service. Hydrated from
/// the Drift key/value store on first build and written through on every change
/// so the configuration survives a full restart.

@ProviderFor(BehaviorSettingsController)
final behaviorSettingsControllerProvider =
    BehaviorSettingsControllerProvider._();

/// Holds the 行为 settings (the original `settingsSlice` behavior fields), so
/// the 行为 page stays a pure view and the chat composer / haptic service can
/// read them.
///
/// `keepAlive: true`: an app-level preference shared by the settings page, the
/// chat composer (Enter-to-send) and the global haptic service. Hydrated from
/// the Drift key/value store on first build and written through on every change
/// so the configuration survives a full restart.
final class BehaviorSettingsControllerProvider
    extends $NotifierProvider<BehaviorSettingsController, BehaviorSettings> {
  /// Holds the 行为 settings (the original `settingsSlice` behavior fields), so
  /// the 行为 page stays a pure view and the chat composer / haptic service can
  /// read them.
  ///
  /// `keepAlive: true`: an app-level preference shared by the settings page, the
  /// chat composer (Enter-to-send) and the global haptic service. Hydrated from
  /// the Drift key/value store on first build and written through on every change
  /// so the configuration survives a full restart.
  BehaviorSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'behaviorSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$behaviorSettingsControllerHash();

  @$internal
  @override
  BehaviorSettingsController create() => BehaviorSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BehaviorSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BehaviorSettings>(value),
    );
  }
}

String _$behaviorSettingsControllerHash() =>
    r'799a2454bf5d8ba617661294f20e7d2127de1732';

/// Holds the 行为 settings (the original `settingsSlice` behavior fields), so
/// the 行为 page stays a pure view and the chat composer / haptic service can
/// read them.
///
/// `keepAlive: true`: an app-level preference shared by the settings page, the
/// chat composer (Enter-to-send) and the global haptic service. Hydrated from
/// the Drift key/value store on first build and written through on every change
/// so the configuration survives a full restart.

abstract class _$BehaviorSettingsController
    extends $Notifier<BehaviorSettings> {
  BehaviorSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BehaviorSettings, BehaviorSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BehaviorSettings, BehaviorSettings>,
              BehaviorSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
