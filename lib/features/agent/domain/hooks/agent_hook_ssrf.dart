// http 型 hook 的 SSRF 防护（对标 Claude Code ssrfGuard）。

/// http hook 的 SSRF 防护（对标 Claude Code ssrfGuard）：判定解析出的
/// IP 是否属于 http hook 不应触达的地址段——私网、链路本地/云
/// metadata（169.254.169.254 等）、CGNAT 共享段、未指定地址。
/// loopback（127.0.0.0/8、::1）刻意放行：本机策略服务是 http hook 的
/// 主要使用场景。非法 IP 字面量返回 false（交给真实 DNS 路径处理）。
bool isBlockedAgentHookAddress(String address) {
  final v4 = _parseIPv4(address);
  if (v4 != null) return _isBlockedV4(v4);
  final v6 = _parseIPv6Groups(address);
  if (v6 != null) return _isBlockedV6(v6);
  return false;
}

List<int>? _parseIPv4(String address) {
  final parts = address.split('.');
  if (parts.length != 4) return null;
  final octets = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0 || n > 255) return null;
    octets.add(n);
  }
  return octets;
}

bool _isBlockedV4(List<int> o) {
  final a = o[0], b = o[1];
  // loopback 刻意放行
  if (a == 127) return false;
  // 0.0.0.0/8「本」网络
  if (a == 0) return true;
  // 10.0.0.0/8 私网
  if (a == 10) return true;
  // 169.254.0.0/16 链路本地（云 metadata）
  if (a == 169 && b == 254) return true;
  // 172.16.0.0/12 私网
  if (a == 172 && b >= 16 && b <= 31) return true;
  // 100.64.0.0/10 CGNAT 共享段（部分云 metadata，如阿里云 100.100.100.200）
  if (a == 100 && b >= 64 && b <= 127) return true;
  // 192.168.0.0/16 私网
  if (a == 192 && b == 168) return true;
  return false;
}

/// 把 IPv6 展开为 8 个 16 位组（支持 `::` 压缩与尾部点分 IPv4）；
/// 非法返回 null。
List<int>? _parseIPv6Groups(String address) {
  var addr = address.toLowerCase();
  if (!addr.contains(':')) return null;
  var tail = <int>[];
  if (addr.contains('.')) {
    final lastColon = addr.lastIndexOf(':');
    final v4 = _parseIPv4(addr.substring(lastColon + 1));
    if (v4 == null) return null;
    tail = [(v4[0] << 8) | v4[1], (v4[2] << 8) | v4[3]];
    addr = addr.substring(0, lastColon);
  }
  final dbl = addr.indexOf('::');
  List<String> head, rest;
  if (dbl == -1) {
    head = addr.split(':');
    rest = [];
  } else {
    if (addr.indexOf('::', dbl + 1) != -1) return null;
    final headStr = addr.substring(0, dbl);
    final restStr = addr.substring(dbl + 2);
    head = headStr.isEmpty ? [] : headStr.split(':');
    rest = restStr.isEmpty ? [] : restStr.split(':');
  }
  final target = 8 - tail.length;
  final fill = target - head.length - rest.length;
  if (dbl == -1 && fill != 0) return null;
  if (fill < 0) return null;
  final groups = <int>[];
  for (final h in [...head, ...List.filled(fill, '0'), ...rest]) {
    if (h.isEmpty || h.length > 4) return null;
    final n = int.tryParse(h, radix: 16);
    if (n == null || n < 0 || n > 0xffff) return null;
    groups.add(n);
  }
  groups.addAll(tail);
  return groups.length == 8 ? groups : null;
}

bool _isBlockedV6(List<int> g) {
  // ::1 loopback 刻意放行
  if (g.sublist(0, 7).every((n) => n == 0) && g[7] == 1) return false;
  // :: 未指定地址
  if (g.every((n) => n == 0)) return true;
  // IPv4-mapped（::ffff:a.b.c.d，含十六进制表示）→ 按内嵌 v4 判定，
  // 否则 ::ffff:a9fe:a9fe（=169.254.169.254）可绕过防护。
  if (g.sublist(0, 5).every((n) => n == 0) && g[5] == 0xffff) {
    return _isBlockedV4([g[6] >> 8, g[6] & 0xff, g[7] >> 8, g[7] & 0xff]);
  }
  final first = g[0];
  // fc00::/7 唯一本地地址
  if (first >= 0xfc00 && first <= 0xfdff) return true;
  // fe80::/10 链路本地
  if (first >= 0xfe80 && first <= 0xfebf) return true;
  return false;
}
