import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Windows 下所有浏览器会话共用一个可写的 WebView2 profile，
/// cookies / localStorage / 登录态跨会话、跨重启保留。
/// 其它平台系统 WebView 自带持久化，返回 null。
class BrowserWindowsEnvironment {
  BrowserWindowsEnvironment._();

  static final instance = BrowserWindowsEnvironment._();

  Future<WebViewEnvironment?>? _environment;

  Future<WebViewEnvironment?> get() {
    if (!Platform.isWindows) return Future.value(null);
    return _environment ??= _create();
  }

  Future<WebViewEnvironment?> _create() async {
    try {
      final root = await getApplicationSupportDirectory();
      final profile = Directory(p.join(root.path, 'browser', 'webview2'));
      await profile.create(recursive: true);
      return await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(userDataFolder: profile.path),
      );
    } catch (_) {
      // Runtime/profile 初始化失败不能毒化后续重试。
      _environment = null;
      rethrow;
    }
  }

  /// 该 URL 在内置浏览器里的 Cookie 头（下载时带上登录态）。失败返回 null。
  Future<String?> cookieHeaderFor(String url) async {
    try {
      final env = await get();
      final cookies = await CookieManager.instance(
        webViewEnvironment: env,
      ).getCookies(url: WebUri(url));
      if (cookies.isEmpty) return null;
      return cookies.map((c) => '${c.name}=${c.value}').join('; ');
    } catch (_) {
      return null;
    }
  }
}
