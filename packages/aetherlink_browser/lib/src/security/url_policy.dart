import 'dart:async';
import 'dart:io';

import '../models/browser_exception.dart';
import 'private_networks.dart';

/// DNS 解析函数（可注入 mock，测试无需真实网络）。
typedef HostResolver = Future<List<InternetAddress>> Function(String host);

/// 导航前 URL 安全策略（设计稿 §15.2 SSRF 防护，纯 Dart）：
/// ① 协议白名单仅 http/https；② 解析 DNS 后校验实际 IP 不落在
/// 内网/环回/链路本地/元数据等禁止段。重定向逐跳复检由调用方
/// 在 shouldOverrideUrlLoading 里对每个新目标重跑本校验。
///
/// 已知残余风险（DNS rebinding TOCTOU）：本策略自行 lookup 校验，
/// 而 WebView 加载时会另行解析 DNS，无法做到“按校验过的 IP 连接”
///（pin）。短 TTL 恶意域名可在两次解析间换成内网 IP。缓解：同一
/// 会话内的校验与逐跳复检共用 [dnsCacheTtl] 内的解析结果，决策一致
/// 并收窄重新解析窗口；无法完全消除，故内置浏览器不应被视为
/// 内网隔离边界。
class UrlPolicy {
  UrlPolicy({
    HostResolver? resolver,
    this.dnsCacheTtl = const Duration(seconds: 30),
  }) : _resolver = resolver ?? InternetAddress.lookup;

  final HostResolver _resolver;

  /// DNS 解析结果缓存时长：校验与逐跳复检共用同一结果。
  final Duration dnsCacheTtl;

  static const int _maxCacheEntries = 64;
  final Map<String, (DateTime, List<InternetAddress>)> _dnsCache = {};

  static const allowedSchemes = {'http', 'https'};

  /// 校验通过返回规范化 Uri；否则抛 [BrowserException]（分类
  /// [BrowserErrorKind.blockedUrl]），消息面向模型可读。
  Future<Uri> validate(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw BrowserException(
        BrowserErrorKind.blockedUrl,
        '无效 URL：$url（需要完整的 http/https 地址）',
      );
    }
    if (!allowedSchemes.contains(uri.scheme.toLowerCase())) {
      throw BrowserException(
        BrowserErrorKind.blockedUrl,
        '协议 ${uri.scheme} 已被安全策略拒绝（仅允许 http/https）',
      );
    }
    final literal = InternetAddress.tryParse(_stripBrackets(uri.host));
    final addresses = literal != null ? [literal] : await _lookup(uri.host);
    for (final address in addresses) {
      if (isForbiddenAddress(address)) {
        throw BrowserException(
          BrowserErrorKind.blockedUrl,
          '目标 ${uri.host}（${address.address}）位于内网/环回/元数据等禁止'
          '网段，已被安全策略拒绝',
        );
      }
    }
    return uri;
  }

  Future<List<InternetAddress>> _lookup(String host) async {
    final now = DateTime.now();
    final cached = _dnsCache[host];
    if (cached != null && now.difference(cached.$1) < dnsCacheTtl) {
      return cached.$2;
    }
    try {
      final addresses = await _resolver(host);
      if (addresses.isEmpty) {
        throw BrowserException(
          BrowserErrorKind.network,
          'DNS 解析失败：$host 无可用地址',
        );
      }
      if (_dnsCache.length >= _maxCacheEntries) {
        _dnsCache.removeWhere((_, v) => now.difference(v.$1) >= dnsCacheTtl);
        if (_dnsCache.length >= _maxCacheEntries) {
          _dnsCache.remove(_dnsCache.keys.first);
        }
      }
      _dnsCache[host] = (now, addresses);
      return addresses;
    } on SocketException catch (e) {
      throw BrowserException(
        BrowserErrorKind.network,
        'DNS 解析失败：$host（${e.message}）',
      );
    }
  }

  static String _stripBrackets(String host) =>
      host.startsWith('[') && host.endsWith(']')
      ? host.substring(1, host.length - 1)
      : host;
}
