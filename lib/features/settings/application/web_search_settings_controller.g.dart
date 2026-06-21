// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_search_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the web-search configuration (selected provider, max results, timeout).
/// Read by the chat controller to parameterize `builtin_web_search` and by the
/// settings page for the UI.

@ProviderFor(WebSearchSettingsController)
final webSearchSettingsControllerProvider =
    WebSearchSettingsControllerProvider._();

/// Holds the web-search configuration (selected provider, max results, timeout).
/// Read by the chat controller to parameterize `builtin_web_search` and by the
/// settings page for the UI.
final class WebSearchSettingsControllerProvider
    extends $NotifierProvider<WebSearchSettingsController, WebSearchSettings> {
  /// Holds the web-search configuration (selected provider, max results, timeout).
  /// Read by the chat controller to parameterize `builtin_web_search` and by the
  /// settings page for the UI.
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
    r'web_search_settings_controller_placeholder_hash';

/// Holds the web-search configuration (selected provider, max results, timeout).
/// Read by the chat controller to parameterize `builtin_web_search` and by the
/// settings page for the UI.

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
