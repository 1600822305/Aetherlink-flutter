// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'top_toolbar_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the chat top-toolbar DIY configuration (the original
/// `settings.topToolbar.componentPositions` + `modelSelectorDisplayStyle`), so
/// the appearance 顶部工具栏设置 sub-page stays a pure view.
///
/// Hydrated from the Drift key/value store on first build and written through
/// on every change, so the layout survives a full restart (the web kept it in
/// the `settings` slice).
///
/// `keepAlive: true`: an app-level preference that must survive the settings
/// page being disposed when navigating away.

@ProviderFor(TopToolbarSettingsController)
final topToolbarSettingsControllerProvider =
    TopToolbarSettingsControllerProvider._();

/// Holds the chat top-toolbar DIY configuration (the original
/// `settings.topToolbar.componentPositions` + `modelSelectorDisplayStyle`), so
/// the appearance 顶部工具栏设置 sub-page stays a pure view.
///
/// Hydrated from the Drift key/value store on first build and written through
/// on every change, so the layout survives a full restart (the web kept it in
/// the `settings` slice).
///
/// `keepAlive: true`: an app-level preference that must survive the settings
/// page being disposed when navigating away.
final class TopToolbarSettingsControllerProvider
    extends
        $NotifierProvider<TopToolbarSettingsController, TopToolbarSettings> {
  /// Holds the chat top-toolbar DIY configuration (the original
  /// `settings.topToolbar.componentPositions` + `modelSelectorDisplayStyle`), so
  /// the appearance 顶部工具栏设置 sub-page stays a pure view.
  ///
  /// Hydrated from the Drift key/value store on first build and written through
  /// on every change, so the layout survives a full restart (the web kept it in
  /// the `settings` slice).
  ///
  /// `keepAlive: true`: an app-level preference that must survive the settings
  /// page being disposed when navigating away.
  TopToolbarSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'topToolbarSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$topToolbarSettingsControllerHash();

  @$internal
  @override
  TopToolbarSettingsController create() => TopToolbarSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TopToolbarSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TopToolbarSettings>(value),
    );
  }
}

String _$topToolbarSettingsControllerHash() =>
    r'48ab4cba8b5fb06211645bf841bf2631df743bee';

/// Holds the chat top-toolbar DIY configuration (the original
/// `settings.topToolbar.componentPositions` + `modelSelectorDisplayStyle`), so
/// the appearance 顶部工具栏设置 sub-page stays a pure view.
///
/// Hydrated from the Drift key/value store on first build and written through
/// on every change, so the layout survives a full restart (the web kept it in
/// the `settings` slice).
///
/// `keepAlive: true`: an app-level preference that must survive the settings
/// page being disposed when navigating away.

abstract class _$TopToolbarSettingsController
    extends $Notifier<TopToolbarSettings> {
  TopToolbarSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TopToolbarSettings, TopToolbarSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TopToolbarSettings, TopToolbarSettings>,
              TopToolbarSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
