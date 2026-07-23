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
class UrlPolicy {
  const UrlPolicy({HostResolver? resolver})
      : _resolver = resolver ?? InternetAddress.lookup;

  final HostResolver _resolver;

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
    try {
      final addresses = await _resolver(host);
      if (addresses.isEmpty) {
        throw BrowserException(
          BrowserErrorKind.network,
          'DNS 解析失败：$host 无可用地址',
        );
      }
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
