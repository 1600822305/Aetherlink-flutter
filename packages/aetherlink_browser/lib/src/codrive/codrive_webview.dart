import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../session/browser_session.dart';

/// 人机共驾用的可见 WebView（升级设计 §2.4 M4d）：把会话的 headless
/// WebView 转为可见渲染——用户看到并操作的就是 agent 正在用的**同一个**
/// 原生 WebView（同页面、同登录态、同 JS 状态）。keepAlive 保证退出
/// 共驾页后原生 WebView 不销毁，agent 工具继续可用。
class CoDriveWebView extends StatefulWidget {
  const CoDriveWebView({
    super.key,
    required this.session,
    this.onUrlChanged,
    this.onProgress,
    this.onTitleChanged,
  });

  /// 要可见化的会话（必须是 headless 实现）。
  final HeadlessBrowserSession session;

  final ValueChanged<String>? onUrlChanged;

  /// 加载进度 0~1（地址栏进度条用）。
  final ValueChanged<double>? onProgress;

  /// 页面标题变化。
  final ValueChanged<String?>? onTitleChanged;

  @override
  State<CoDriveWebView> createState() => _CoDriveWebViewState();
}

class _CoDriveWebViewState extends State<CoDriveWebView> {
  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return InAppWebView(
      // 首次：接管 headless 实例；之后：headlessWebView 为 null，
      // 由同一个 keepAlive 复挂原生 WebView。
      headlessWebView: session.headlessWebView,
      keepAlive: session.keepAlive,
      webViewEnvironment: session.environment,
      initialSettings: session.viewSettings,
      onWebViewCreated: session.attachVisible,
      // 与 headless 完全同一套回调：导航门控、SSRF 复检、对话框、
      // 新窗口、崩溃处理，转可见后都不能丢。
      onLoadStart: (controller, url) {
        session.handleLoadStart(controller, url);
      },
      onLoadStop: (controller, url) {
        session.handleLoadStop(controller, url);
      },
      shouldOverrideUrlLoading: session.handleNavigation,
      onCreateWindow: session.handleCreateWindow,
      onCloseWindow: session.handleCloseWindow,
      onDownloadStartRequest: session.handleDownload,
      onJsAlert: session.handleJsAlert,
      onJsConfirm: session.handleJsConfirm,
      onJsPrompt: session.handleJsPrompt,
      onRenderProcessGone: session.handleRenderProcessGone,
      onRenderProcessUnresponsive: session.handleRenderProcessUnresponsive,
      onWebContentProcessDidTerminate:
          session.handleWebContentProcessTerminated,
      onProgressChanged: (controller, progress) =>
          widget.onProgress?.call(progress / 100.0),
      onTitleChanged: (controller, title) {
        session.noteTitle(title);
        widget.onTitleChanged?.call(title);
      },
      onUpdateVisitedHistory: (controller, url, isReload) {
        final s = url?.toString();
        if (s != null) widget.onUrlChanged?.call(s);
      },
    );
  }
}
