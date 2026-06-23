// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_search_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Persists web-search settings as a single JSON blob (the Flutter port of the
/// web's `webSearchSlice`). Same hydrate-on-build pattern as
/// [SidebarSettingsController].

@ProviderFor(WebSearchSettingsController)
final webSearchSettingsControllerProvider =
    WebSearchSettingsControllerProvider._();

/// Persists web-search settings as a single JSON blob (the Flutter port of the
/// web's `webSearchSlice`). Same hydrate-on-build pattern as
/// [SidebarSettingsController].
final class WebSearchSettingsControllerProvider
    extends $NotifierProvider<WebSearchSettingsController, WebSearchSettings> {
  /// Persists web-search settings as a single JSON blob (the Flutter port of the
  /// web's `webSearchSlice`). Same hydrate-on-build pattern as
  /// [SidebarSettingsController].
  WebSearchSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'webSearchSettingsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$webSearchSettingsControllerHash();

  @$internal
  @override
  WebSearchSettingsController create() => WebSearchSettingsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WebSearchSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WebSearchSettings>(value),
    );
  }
}

String _$webSearchSettingsControllerHash() =>
    r'8dcfccf35c5cad0b890e7bce7a9809d703573890';

/// Persists web-search settings as a single JSON blob (the Flutter port of the
/// web's `webSearchSlice`). Same hydrate-on-build pattern as
/// [SidebarSettingsController].

abstract class _$WebSearchSettingsController
    extends $Notifier<WebSearchSettings> {
  WebSearchSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WebSearchSettings, WebSearchSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WebSearchSettings, WebSearchSettings>,
              WebSearchSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
