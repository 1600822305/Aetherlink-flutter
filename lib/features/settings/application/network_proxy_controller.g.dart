// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_proxy_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the global HTTP / SOCKS proxy configuration. The page owns edits;
/// app-level network providers read the pure [NetworkProxySettings] value and
/// pass its validated [NetworkProxyConfig] into Dio builders.

@ProviderFor(NetworkProxyController)
final networkProxyControllerProvider = NetworkProxyControllerProvider._();

/// Holds the global HTTP / SOCKS proxy configuration. The page owns edits;
/// app-level network providers read the pure [NetworkProxySettings] value and
/// pass its validated [NetworkProxyConfig] into Dio builders.
final class NetworkProxyControllerProvider
    extends $NotifierProvider<NetworkProxyController, NetworkProxySettings> {
  /// Holds the global HTTP / SOCKS proxy configuration. The page owns edits;
  /// app-level network providers read the pure [NetworkProxySettings] value and
  /// pass its validated [NetworkProxyConfig] into Dio builders.
  NetworkProxyControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkProxyControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkProxyControllerHash();

  @$internal
  @override
  NetworkProxyController create() => NetworkProxyController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NetworkProxySettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NetworkProxySettings>(value),
    );
  }
}

String _$networkProxyControllerHash() =>
    r'608b02c27391b527afeae475b40072c9d9a32adf';

/// Holds the global HTTP / SOCKS proxy configuration. The page owns edits;
/// app-level network providers read the pure [NetworkProxySettings] value and
/// pass its validated [NetworkProxyConfig] into Dio builders.

abstract class _$NetworkProxyController
    extends $Notifier<NetworkProxySettings> {
  NetworkProxySettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<NetworkProxySettings, NetworkProxySettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NetworkProxySettings, NetworkProxySettings>,
              NetworkProxySettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
