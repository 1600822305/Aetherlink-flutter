// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thinking_settings_access.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-level composition seam exposing the 思考过程设置 ([ThinkingSettings]) to the
/// `chat` feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`,
/// so the chat thinking block cannot read [ThinkingSettingsController] (which
/// lives in `settings/application`) directly. It instead watches this provider
/// in `app/` (the composition root, which may depend on any feature) plus the
/// pure-Dart `shared/domain` [ThinkingSettings] type.
///
/// Reactively re-exposes the controller's state, so changing the display style
/// or auto-collapse in 外观设置 → 思考过程设置 re-renders the thinking block live.

@ProviderFor(thinkingSettings)
final thinkingSettingsProvider = ThinkingSettingsProvider._();

/// App-level composition seam exposing the 思考过程设置 ([ThinkingSettings]) to the
/// `chat` feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`,
/// so the chat thinking block cannot read [ThinkingSettingsController] (which
/// lives in `settings/application`) directly. It instead watches this provider
/// in `app/` (the composition root, which may depend on any feature) plus the
/// pure-Dart `shared/domain` [ThinkingSettings] type.
///
/// Reactively re-exposes the controller's state, so changing the display style
/// or auto-collapse in 外观设置 → 思考过程设置 re-renders the thinking block live.

final class ThinkingSettingsProvider
    extends
        $FunctionalProvider<
          ThinkingSettings,
          ThinkingSettings,
          ThinkingSettings
        >
    with $Provider<ThinkingSettings> {
  /// App-level composition seam exposing the 思考过程设置 ([ThinkingSettings]) to the
  /// `chat` feature.
  ///
  /// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
  /// Rule 3) forbids one feature from importing another feature's `application`,
  /// so the chat thinking block cannot read [ThinkingSettingsController] (which
  /// lives in `settings/application`) directly. It instead watches this provider
  /// in `app/` (the composition root, which may depend on any feature) plus the
  /// pure-Dart `shared/domain` [ThinkingSettings] type.
  ///
  /// Reactively re-exposes the controller's state, so changing the display style
  /// or auto-collapse in 外观设置 → 思考过程设置 re-renders the thinking block live.
  ThinkingSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'thinkingSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$thinkingSettingsHash();

  @$internal
  @override
  $ProviderElement<ThinkingSettings> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThinkingSettings create(Ref ref) {
    return thinkingSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThinkingSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThinkingSettings>(value),
    );
  }
}

String _$thinkingSettingsHash() => r'16d60bdecc9d8dfc6862d6c88b1b1c4efb509a10';
