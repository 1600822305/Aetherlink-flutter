import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 人机共驾用的可见 WebView（升级设计 §2.4 M4d）：agent hand off 后，
/// 用户在这里亲自操作（登录/验证码/滑块）。它与 headless 会话是不同的
/// WebView 实例，但 cookie/登录态全局共享（WebView 平台特性），所以
/// 用户在这里完成登录后，agent 收回的 headless 会话直接复用登录态。
class CoDriveWebView extends StatefulWidget {
  const CoDriveWebView({super.key, this.initialUrl, this.onUrlChanged});

  /// 初始加载的页面（通常是 hand off 时 agent 所在的 URL）。
  final String? initialUrl;

  final ValueChanged<String>? onUrlChanged;

  @override
  State<CoDriveWebView> createState() => _CoDriveWebViewState();
}

class _CoDriveWebViewState extends State<CoDriveWebView> {
  @override
  Widget build(BuildContext context) {
    final url = widget.initialUrl;
    return InAppWebView(
      initialUrlRequest: url == null || url.isEmpty
          ? null
          : URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        // 用户亲自驾驶：只限制协议，不做 SSRF 网段复检（用户本来就能
        // 用系统浏览器访问任何地址；这里防的是被诱导跳非 Web 协议）。
        allowsBackForwardNavigationGestures: true,
      ),
      shouldOverrideUrlLoading: (controller, action) async {
        final scheme = action.request.url?.scheme.toLowerCase();
        return (scheme == 'http' || scheme == 'https')
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL;
      },
      onUpdateVisitedHistory: (controller, url, isReload) {
        final s = url?.toString();
        if (s != null) widget.onUrlChanged?.call(s);
      },
    );
  }
}
