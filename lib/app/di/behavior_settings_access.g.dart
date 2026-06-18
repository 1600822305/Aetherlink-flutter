// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'behavior_settings_access.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-level composition seam exposing the 行为 settings ([BehaviorSettings]) to
/// the `chat` feature and the app root.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`,
/// so the chat composer cannot read [BehaviorSettingsController] (which lives in
/// `settings/application`) directly. It instead reads this provider in `app/`
/// (the composition root, which may depend on any feature) plus the pure-Dart
/// `shared/domain` [BehaviorSettings] type.
///
/// Reactively re-exposes the controller's state, so toggling Enter 发送 or a
/// 触觉反馈 option in 行为 settings takes effect immediately.

@ProviderFor(appBehaviorSettings)
final appBehaviorSettingsProvider = AppBehaviorSettingsProvider._();

/// App-level composition seam exposing the 行为 settings ([BehaviorSettings]) to
/// the `chat` feature and the app root.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`,
/// so the chat composer cannot read [BehaviorSettingsController] (which lives in
/// `settings/application`) directly. It instead reads this provider in `app/`
/// (the composition root, which may depend on any feature) plus the pure-Dart
/// `shared/domain` [BehaviorSettings] type.
///
/// Reactively re-exposes the controller's state, so toggling Enter 发送 or a
/// 触觉反馈 option in 行为 settings takes effect immediately.

final class AppBehaviorSettingsProvider
    extends
        $FunctionalProvider<
          BehaviorSettings,
          BehaviorSettings,
          BehaviorSettings
        >
    with $Provider<BehaviorSettings> {
  /// App-level composition seam exposing the 行为 settings ([BehaviorSettings]) to
  /// the `chat` feature and the app root.
  ///
  /// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
  /// Rule 3) forbids one feature from importing another feature's `application`,
  /// so the chat composer cannot read [BehaviorSettingsController] (which lives in
  /// `settings/application`) directly. It instead reads this provider in `app/`
  /// (the composition root, which may depend on any feature) plus the pure-Dart
  /// `shared/domain` [BehaviorSettings] type.
  ///
  /// Reactively re-exposes the controller's state, so toggling Enter 发送 or a
  /// 触觉反馈 option in 行为 settings takes effect immediately.
  AppBehaviorSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appBehaviorSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appBehaviorSettingsHash();

  @$internal
  @override
  $ProviderElement<BehaviorSettings> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BehaviorSettings create(Ref ref) {
    return appBehaviorSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BehaviorSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BehaviorSettings>(value),
    );
  }
}

String _$appBehaviorSettingsHash() =>
    r'b4d08096876cc1287c44c5afdff8246371ba2254';
