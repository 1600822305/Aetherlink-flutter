import 'package:aetherlink_flutter/core/network/network_proxy_config.dart';

/// Persisted global network-proxy settings shown on the 设置 → 网络代理 page.
///
/// This type stays framework-free so both settings UI and app-level network
/// composition can share it without pulling presentation details into core.
class NetworkProxySettings {
  const NetworkProxySettings({
    this.enabled = false,
    this.type = NetworkProxyType.http,
    this.host = '',
    this.port = '8080',
    this.username = '',
    this.password = '',
    this.bypassRules = kDefaultNetworkProxyBypassRules,
  });

  factory NetworkProxySettings.fromJson(Map<String, dynamic> json) {
    return NetworkProxySettings(
      enabled: json['enabled'] == true,
      type: NetworkProxyType.fromString(json['type']?.toString() ?? ''),
      host: json['host']?.toString() ?? '',
      port: json['port']?.toString() ?? '8080',
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      bypassRules:
          json['bypassRules']?.toString() ?? kDefaultNetworkProxyBypassRules,
    );
  }

  final bool enabled;
  final NetworkProxyType type;
  final String host;
  final String port;
  final String username;
  final String password;
  final String bypassRules;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'type': type.value,
    'host': host,
    'port': port,
    'username': username,
    'password': password,
    'bypassRules': bypassRules,
  };

  NetworkProxyConfig? toConfig() {
    final parsedPort = int.tryParse(port.trim());
    if (!enabled ||
        host.trim().isEmpty ||
        parsedPort == null ||
        parsedPort <= 0) {
      return null;
    }
    final normalizedUser = username.trim();
    return NetworkProxyConfig(
      enabled: enabled,
      type: type,
      host: host.trim(),
      port: parsedPort,
      username: normalizedUser.isEmpty ? null : normalizedUser,
      password: password.isEmpty ? null : password,
      bypassRules: bypassRules.trim().isEmpty
          ? kDefaultNetworkProxyBypassRules
          : bypassRules.trim(),
    );
  }

  NetworkProxySettings copyWith({
    bool? enabled,
    NetworkProxyType? type,
    String? host,
    String? port,
    String? username,
    String? password,
    String? bypassRules,
  }) {
    return NetworkProxySettings(
      enabled: enabled ?? this.enabled,
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      bypassRules: bypassRules ?? this.bypassRules,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is NetworkProxySettings &&
            enabled == other.enabled &&
            type == other.type &&
            host == other.host &&
            port == other.port &&
            username == other.username &&
            password == other.password &&
            bypassRules == other.bypassRules;
  }

  @override
  int get hashCode =>
      Object.hash(enabled, type, host, port, username, password, bypassRules);
}
