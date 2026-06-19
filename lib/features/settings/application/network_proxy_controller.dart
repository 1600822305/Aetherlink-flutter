import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/core/network/network_proxy_config.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/network_proxy_settings.dart';

part 'network_proxy_controller.g.dart';

/// Storage key for the global network proxy settings JSON blob.
const String kNetworkProxySettingsKey = 'networkProxySettings';

/// Holds the global HTTP / SOCKS proxy configuration. The page owns edits;
/// app-level network providers read the pure [NetworkProxySettings] value and
/// pass its validated [NetworkProxyConfig] into Dio builders.
@Riverpod(keepAlive: true)
class NetworkProxyController extends _$NetworkProxyController
    with JsonKvNotifier<NetworkProxySettings> {
  @override
  ChatRepository get kvStore => ref.read(appSettingsStoreProvider);

  @override
  String get storageKey => kNetworkProxySettingsKey;

  @override
  NetworkProxySettings fromStored(Map<String, dynamic> json) =>
      NetworkProxySettings.fromJson(json);

  @override
  Map<String, dynamic> toStored(NetworkProxySettings value) => value.toJson();

  @override
  NetworkProxySettings build() => hydrate(const NetworkProxySettings());

  void setEnabled(bool value) => persist(state.copyWith(enabled: value));

  void setType(NetworkProxyType value) => persist(state.copyWith(type: value));

  void setHost(String value) => persist(state.copyWith(host: value.trim()));

  void setPort(String value) => persist(state.copyWith(port: value.trim()));

  void setUsername(String value) => persist(state.copyWith(username: value));

  void setPassword(String value) => persist(state.copyWith(password: value));

  void setBypassRules(String value) =>
      persist(state.copyWith(bypassRules: value.trim()));
}
