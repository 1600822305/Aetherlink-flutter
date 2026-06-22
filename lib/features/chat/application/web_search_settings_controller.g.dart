// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_search_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WebSearchSettingsController)
final webSearchSettingsControllerProvider =
    WebSearchSettingsControllerProvider._();

final class WebSearchSettingsControllerProvider
    extends $NotifierProvider<WebSearchSettingsController, WebSearchSettings> {
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
    r'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

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
