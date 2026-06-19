/// Pure network-layer proxy settings. UI / persistence code converts its form
/// model into this value before constructing network clients.
class NetworkProxyConfig {
  const NetworkProxyConfig({
    required this.enabled,
    this.type = NetworkProxyType.http,
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.bypassRules = kDefaultNetworkProxyBypassRules,
  });

  final bool enabled;
  final NetworkProxyType type;
  final String host;
  final int port;
  final String? username;
  final String? password;
  final String bypassRules;

  bool get isValid => enabled && host.trim().isNotEmpty && port > 0;

  bool shouldBypass(String host) => shouldBypassNetworkProxy(host, bypassRules);
}

enum NetworkProxyType {
  http('http'),
  https('https'),
  socks5('socks5');

  const NetworkProxyType(this.value);

  final String value;

  static NetworkProxyType fromString(String value) {
    final normalized = value.trim().toLowerCase();
    for (final type in NetworkProxyType.values) {
      if (type.value == normalized) return type;
    }
    return NetworkProxyType.http;
  }
}

const String kDefaultNetworkProxyBypassRules =
    'localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,::1';

bool shouldBypassNetworkProxy(String host, String bypassRules) {
  final normalizedHost = _normalizeProxyHost(host);
  if (normalizedHost.isEmpty) return false;

  final rules = bypassRules.split(RegExp(r'[,;\s]+'));
  for (final rawRule in rules) {
    final rule = rawRule.trim().toLowerCase();
    if (rule.isEmpty) continue;
    if (rule == '*') return true;

    if (rule.startsWith('*.') || rule.startsWith('*')) {
      final suffix = rule.substring(1);
      if (suffix.isNotEmpty && normalizedHost.endsWith(suffix)) return true;
      continue;
    }

    if (rule.contains('/')) {
      if (_matchesIpv4Cidr(normalizedHost, rule)) return true;
      continue;
    }

    if (normalizedHost == rule) return true;
  }

  return false;
}

String _normalizeProxyHost(String host) {
  var normalized = host.trim().toLowerCase();
  if (normalized.startsWith('[') &&
      normalized.endsWith(']') &&
      normalized.length > 2) {
    normalized = normalized.substring(1, normalized.length - 1);
  }
  final zoneIndex = normalized.indexOf('%');
  if (zoneIndex > 0) normalized = normalized.substring(0, zoneIndex);
  if (normalized.endsWith('.')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

bool _matchesIpv4Cidr(String host, String cidr) {
  final parts = cidr.split('/');
  if (parts.length != 2) return false;

  final address = _parseIpv4(host);
  final network = _parseIpv4(parts[0].trim());
  final prefixLength = int.tryParse(parts[1].trim());
  if (address == null || network == null || prefixLength == null) return false;
  if (prefixLength < 0 || prefixLength > 32) return false;

  final mask = prefixLength == 0
      ? 0
      : (0xFFFFFFFF << (32 - prefixLength)) & 0xFFFFFFFF;
  return (address & mask) == (network & mask);
}

int? _parseIpv4(String value) {
  final parts = value.split('.');
  if (parts.length != 4) return null;
  var result = 0;
  for (final part in parts) {
    if (part.isEmpty) return null;
    final byte = int.tryParse(part);
    if (byte == null || byte < 0 || byte > 255) return null;
    result = (result << 8) | byte;
  }
  return result;
}
