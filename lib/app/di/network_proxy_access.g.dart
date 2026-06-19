// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_proxy_access.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-level composition seam exposing global proxy settings to networking
/// providers outside the settings feature.

@ProviderFor(appNetworkProxySettings)
final appNetworkProxySettingsProvider = AppNetworkProxySettingsProvider._();

/// App-level composition seam exposing global proxy settings to networking
/// providers outside the settings feature.

final class AppNetworkProxySettingsProvider
    extends
        $FunctionalProvider<
          NetworkProxySettings,
          NetworkProxySettings,
          NetworkProxySettings
        >
    with $Provider<NetworkProxySettings> {
  /// App-level composition seam exposing global proxy settings to networking
  /// providers outside the settings feature.
  AppNetworkProxySettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appNetworkProxySettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appNetworkProxySettingsHash();

  @$internal
  @override
  $ProviderElement<NetworkProxySettings> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NetworkProxySettings create(Ref ref) {
    return appNetworkProxySettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkProxySettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkProxySettings>(value),
    );
  }
}

String _$appNetworkProxySettingsHash() =>
    r'72772658885af5331b319f2e13ccc278605f9131';

/// Validated network-layer proxy configuration, or null when disabled /
/// incomplete. Kept separate from the form model so network code never needs to
/// parse text fields.

@ProviderFor(appNetworkProxyConfig)
final appNetworkProxyConfigProvider = AppNetworkProxyConfigProvider._();

/// Validated network-layer proxy configuration, or null when disabled /
/// incomplete. Kept separate from the form model so network code never needs to
/// parse text fields.

final class AppNetworkProxyConfigProvider
    extends
        $FunctionalProvider<
          NetworkProxyConfig?,
          NetworkProxyConfig?,
          NetworkProxyConfig?
        >
    with $Provider<NetworkProxyConfig?> {
  /// Validated network-layer proxy configuration, or null when disabled /
  /// incomplete. Kept separate from the form model so network code never needs to
  /// parse text fields.
  AppNetworkProxyConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appNetworkProxyConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appNetworkProxyConfigHash();

  @$internal
  @override
  $ProviderElement<NetworkProxyConfig?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NetworkProxyConfig? create(Ref ref) {
    return appNetworkProxyConfig(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkProxyConfig? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkProxyConfig?>(value),
    );
  }
}

String _$appNetworkProxyConfigHash() =>
    r'285b42ec947b61922f79958d5531f950eafafa4f';
