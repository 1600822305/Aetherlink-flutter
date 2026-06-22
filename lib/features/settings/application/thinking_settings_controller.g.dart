// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thinking_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the 思考过程设置 configuration (the original `settings.thinkingDisplayStyle`
/// / `thoughtAutoCollapse` / `thinkingToolInline`), so the appearance sub-page
/// and the chat thinking block stay pure views.
///
/// `keepAlive: true`: an app-level preference shared by the settings page and the
/// chat view. Hydrated from the Drift key/value store on first build and written
/// through on every change — the port of the web `dexieStorage.saveSetting` — so
/// the configuration survives a full restart.

@ProviderFor(ThinkingSettingsController)
final thinkingSettingsControllerProvider =
    ThinkingSettingsControllerProvider._();

/// Holds the 思考过程设置 configuration (the original `settings.thinkingDisplayStyle`
/// / `thoughtAutoCollapse` / `thinkingToolInline`), so the appearance sub-page
/// and the chat thinking block stay pure views.
///
/// `keepAlive: true`: an app-level preference shared by the settings page and the
/// chat view. Hydrated from the Drift key/value store on first build and written
/// through on every change — the port of the web `dexieStorage.saveSetting` — so
/// the configuration survives a full restart.
final class ThinkingSettingsControllerProvider
    extends $NotifierProvider<ThinkingSettingsController, ThinkingSettings> {
  /// Holds the 思考过程设置 configuration (the original `settings.thinkingDisplayStyle`
  /// / `thoughtAutoCollapse` / `thinkingToolInline`), so the appearance sub-page
  /// and the chat thinking block stay pure views.
  ///
  /// `keepAlive: true`: an app-level preference shared by the settings page and the
  /// chat view. Hydrated from the Drift key/value store on first build and written
  /// through on every change — the port of the web `dexieStorage.saveSetting` — so
  /// the configuration survives a full restart.
  ThinkingSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'thinkingSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$thinkingSettingsControllerHash();

  @$internal
  @override
  ThinkingSettingsController create() => ThinkingSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThinkingSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThinkingSettings>(value),
    );
  }
}

String _$thinkingSettingsControllerHash() =>
    r'b54d5052d1b2b11ed91c19143b9cdddfacc55e81';

/// Holds the 思考过程设置 configuration (the original `settings.thinkingDisplayStyle`
/// / `thoughtAutoCollapse` / `thinkingToolInline`), so the appearance sub-page
/// and the chat thinking block stay pure views.
///
/// `keepAlive: true`: an app-level preference shared by the settings page and the
/// chat view. Hydrated from the Drift key/value store on first build and written
/// through on every change — the port of the web `dexieStorage.saveSetting` — so
/// the configuration survives a full restart.

abstract class _$ThinkingSettingsController
    extends $Notifier<ThinkingSettings> {
  ThinkingSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ThinkingSettings, ThinkingSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThinkingSettings, ThinkingSettings>,
              ThinkingSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
