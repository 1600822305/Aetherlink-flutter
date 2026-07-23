import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/browser_exception.dart';
import '../models/page_load_result.dart';
import '../security/url_policy.dart';
import '../snapshot/screenshot.dart';
import 'page_load.dart';

/// 单页浏览器会话（设计稿 §3/§16）：导航 / 正文提取 / 截图。
/// 首版只读三件套；click/input 留后期（M4）。
abstract class BrowserSession {
  /// 打开 URL 并等待渲染。导航级超时默认 30s，超时截停并抛
  /// [BrowserErrorKind.navigationTimeout]；会话保留，页面可能部分
  /// 可读，可继续 readText/snapshot 或换 URL。
  Future<PageLoadResult> open(String url, {Duration? timeout});

  /// 提取当前页正文：优先 Readability，取不到回退 body.innerText。
  /// [selector] 提供时取该元素文本。
  Future<String> readText({String? selector});

  /// 截图（JPEG 字节，体积受 [options] 控制）。
  Future<Uint8List> snapshot({SnapshotOptions options = const SnapshotOptions()});

  /// 释放 WebView。释放后任何调用抛 [BrowserErrorKind.sessionGone]。
  Future<void> close();

  bool get disposed;
}

/// HeadlessInAppWebView 实现。生命周期由 SessionManager 管理，
/// 不要直接长期持有。
class HeadlessBrowserSession implements BrowserSession {
  HeadlessBrowserSession({
    UrlPolicy? urlPolicy,
    PageLoadPoller? poller,
  })  : _urlPolicy = urlPolicy ?? const UrlPolicy(),
        _poller = poller ?? const PageLoadPoller();

  final UrlPolicy _urlPolicy;
  final PageLoadPoller _poller;

  HeadlessInAppWebView? _headless;
  InAppWebViewController? _controller;
  Completer<void>? _loadStart;
  Completer<void>? _loadStop;
  bool _disposed = false;

  /// JS 执行级超时（设计稿 §19.2）。
  static const _jsTimeout = Duration(seconds: 10);

  static String? _readabilityJs;

  @override
  bool get disposed => _disposed;

  @override
  Future<PageLoadResult> open(String url, {Duration? timeout}) async {
    _ensureAlive();
    final uri = await _urlPolicy.validate(url);
    final controller = await _ensureWebView();
    // 新建两个门控再 loadUrl：导航真正开始（onLoadStart）前，旧页/
    // about:blank 的 readyState='complete' 和抢跑的 onLoadStop 都不作数。
    final loadStart = _loadStart = Completer<void>();
    final loadStop = _loadStop = Completer<void>();
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri.uri(uri)));
    final poller = timeout == null
        ? _poller
        : PageLoadPoller(timeout: timeout, pollInterval: _poller.pollInterval);
    final completed = await poller.wait(
      loadStop: loadStop.future,
      probe: () async {
        if (!loadStart.isCompleted) return false;
        final state = await _evaluate("document.readyState");
        return state == 'complete';
      },
    );
    if (!completed) {
      await controller.stopLoading();
      throw const BrowserException(
        BrowserErrorKind.navigationTimeout,
        '页面加载超时，已截停；会话保留，页面可能部分可读，'
        '可继续 browser_read/browser_snapshot 或换 URL',
      );
    }
    final title = await controller.getTitle() ?? '';
    final finalUrl = (await controller.getUrl())?.toString() ?? uri.toString();
    return PageLoadResult(title: title, finalUrl: finalUrl);
  }

  @override
  Future<String> readText({String? selector}) async {
    _ensureAlive();
    _ensureNavigated();
    if (selector != null) {
      final text = await _evaluate(
        "document.querySelector(${_jsString(selector)})?.innerText ?? ''",
      );
      return (text as String?) ?? '';
    }
    final readability = await _loadReadabilityJs();
    final result = await _evaluate('''
      (() => {
        try {
          $readability
          const article = new Readability(
            document.cloneNode(true),
          ).parse();
          if (article && article.textContent &&
              article.textContent.trim().length > 0) {
            return (article.title ? article.title + '\\n\\n' : '') +
                article.textContent;
          }
        } catch (_) {}
        return document.body ? document.body.innerText : '';
      })()
    ''');
    return (result as String?) ?? '';
  }

  @override
  Future<Uint8List> snapshot({
    SnapshotOptions options = const SnapshotOptions(),
  }) async {
    _ensureAlive();
    final controller = _ensureNavigated();
    final headless = _headless!;
    final original = await headless.getSize() ?? const Size(1024, 1536);
    final width = options.maxWidth.toDouble().clamp(320.0, original.width);
    var height = original.height * (width / original.width);
    if (options.fullPage) {
      final contentHeight = await controller.getContentHeight() ?? 0;
      if (contentHeight > 0) {
        // 整页截图高度封顶 6 倍宽，防超长页面生成巨图。
        height = contentHeight.toDouble().clamp(height, width * 6);
      }
    }
    final resized = width != original.width || height != original.height;
    try {
      if (resized) {
        await headless.setSize(Size(width, height));
        // 给页面一点重排时间再截。
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      final bytes = await controller.takeScreenshot(
        screenshotConfiguration: ScreenshotConfiguration(
          compressFormat: CompressFormat.JPEG,
          quality: options.jpegQuality,
        ),
      );
      if (bytes == null) {
        throw const BrowserException(
          BrowserErrorKind.internal,
          '截图失败：WebView 未返回图像数据',
        );
      }
      return bytes;
    } finally {
      if (resized && !_disposed) {
        await headless.setSize(original);
      }
    }
  }

  @override
  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    _controller = null;
    final headless = _headless;
    _headless = null;
    await headless?.dispose();
  }

  Future<InAppWebViewController> _ensureWebView() async {
    final existing = _controller;
    if (existing != null) return existing;
    final created = Completer<InAppWebViewController>();
    final headless = HeadlessInAppWebView(
      initialSize: const Size(1024, 1536),
      initialSettings: InAppWebViewSettings(
        javaScriptCanOpenWindowsAutomatically: false,
        allowFileAccess: false,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
      ),
      onWebViewCreated: (controller) {
        if (!created.isCompleted) created.complete(controller);
      },
      onLoadStart: (controller, url) {
        final loadStart = _loadStart;
        if (loadStart != null && !loadStart.isCompleted) {
          loadStart.complete();
        }
      },
      onLoadStop: (controller, url) {
        // 只认本次导航（onLoadStart 之后）的完成信号。
        if (_loadStart?.isCompleted != true) return;
        final loadStop = _loadStop;
        if (loadStop != null && !loadStop.isCompleted) {
          loadStop.complete();
        }
      },
      shouldOverrideUrlLoading: (controller, action) async {
        // 重定向/页内导航逐跳复检（设计稿 §15.2 第 3 条）。
        final target = action.request.url;
        if (target == null) return NavigationActionPolicy.CANCEL;
        try {
          await _urlPolicy.validate(target.toString());
          return NavigationActionPolicy.ALLOW;
        } on BrowserException {
          return NavigationActionPolicy.CANCEL;
        }
      },
    );
    _headless = headless;
    await headless.run();
    return _controller = await created.future;
  }

  Future<dynamic> _evaluate(String source) async {
    final controller = _ensureNavigated();
    try {
      return await controller
          .evaluateJavascript(source: source)
          .timeout(_jsTimeout);
    } on TimeoutException {
      throw const BrowserException(
        BrowserErrorKind.scriptTimeout,
        '页面脚本执行超时（10s），页面可能已挂死；可重新 open 或换 URL',
      );
    }
  }

  void _ensureAlive() {
    if (_disposed) {
      throw const BrowserException(
        BrowserErrorKind.sessionGone,
        '浏览器会话已释放，请重新 browser_open',
      );
    }
  }

  InAppWebViewController _ensureNavigated() {
    final controller = _controller;
    if (controller == null) {
      throw const BrowserException(
        BrowserErrorKind.sessionGone,
        '尚未打开任何页面，请先 browser_open',
      );
    }
    return controller;
  }

  static Future<String> _loadReadabilityJs() async => _readabilityJs ??=
      await rootBundle.loadString(
        'packages/aetherlink_browser/assets/js/readability.js',
      );

  static String _jsString(String value) =>
      "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";
}
