import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/core/network/network_proxy_config.dart';
import 'package:aetherlink_flutter/features/settings/application/network_proxy_controller.dart';
import 'package:aetherlink_flutter/shared/domain/network_proxy_settings.dart';

part 'network_proxy_access.g.dart';

/// App-level composition seam exposing global proxy settings to networking
/// providers outside the settings feature.
@Riverpod(keepAlive: true)
NetworkProxySettings appNetworkProxySettings(Ref ref) =>
    ref.watch(networkProxyControllerProvider);

/// Validated network-layer proxy configuration, or null when disabled /
/// incomplete. Kept separate from the form model so network code never needs to
/// parse text fields.
@Riverpod(keepAlive: true)
NetworkProxyConfig? appNetworkProxyConfig(Ref ref) =>
    ref.watch(appNetworkProxySettingsProvider).toConfig();
