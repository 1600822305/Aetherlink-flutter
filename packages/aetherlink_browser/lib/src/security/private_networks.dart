import 'dart:io';

/// 禁止导航的 IP 段判定（设计稿 §15.2）：loopback / 私有 / 链路本地
/// （含云元数据 169.254.169.254）/ 未指定 / 组播 / 保留段。
/// 纯 Dart，无 WebView 依赖，可直接单测。
bool isForbiddenAddress(InternetAddress address) {
  if (address.isLoopback || address.isLinkLocal || address.isMulticast) {
    return true;
  }
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    return _isForbiddenV4(bytes);
  }
  return _isForbiddenV6(bytes);
}

bool _isForbiddenV4(List<int> b) {
  final first = b[0];
  final second = b[1];
  // 0.0.0.0/8 未指定；10/8、172.16/12、192.168/16 私有；
  // 100.64/10 CGNAT；192.0.0.0/24 保留；198.18/15 基准测试；
  // 240/4 保留（含 255.255.255.255 广播）。
  if (first == 0 || first == 10) return true;
  if (first == 100 && second >= 64 && second <= 127) return true;
  if (first == 172 && second >= 16 && second <= 31) return true;
  if (first == 192 && second == 168) return true;
  if (first == 192 && second == 0 && b[2] == 0) return true;
  if (first == 198 && (second == 18 || second == 19)) return true;
  if (first >= 240) return true;
  return false;
}

bool _isForbiddenV6(List<int> b) {
  // :: 未指定；fc00::/7 ULA（isSiteLocal 只覆盖 fec0::/10 旧站点本地）。
  if (b.every((x) => x == 0)) return true;
  if ((b[0] & 0xfe) == 0xfc) return true;
  // ::ffff:a.b.c.d IPv4 映射地址按 IPv4 规则复检。
  final isV4Mapped = b.take(10).every((x) => x == 0) &&
      b[10] == 0xff &&
      b[11] == 0xff;
  if (isV4Mapped) {
    final v4 = b.sublist(12);
    return v4[0] == 127 || _isForbiddenV4(v4) || (v4[0] == 169 && v4[1] == 254);
  }
  return false;
}
