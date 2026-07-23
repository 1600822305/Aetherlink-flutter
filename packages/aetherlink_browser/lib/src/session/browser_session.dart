import 'dart:async';
import 'dart:convert' show jsonEncode;
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../interaction/interaction_js.dart';
import '../models/browser_exception.dart';
import '../models/interact_result.dart';
import '../models/page_load_result.dart';
import '../security/url_policy.dart';
import '../snapshot/element_target.dart';
import '../snapshot/screenshot.dart';
import 'page_load.dart';

/// 单页浏览器会话（设计稿 §3/§16）：导航 / 正文提取 / 截图。
/// 首版只读三件套；click/input 留后期（M4）。
abstract class BrowserSession {
  /// 打开 URL 并等待渲染。导航级超时默认 30s，超时截停并抛
  /// [BrowserErrorKind.navigationTimeout]；会话保留，页面可能部分
  /// 可读，可继续 readText/snapshot 或换 URL。
  Future<PageLoadResult> open(String url, {Duration? timeout});

  /// 提取当前页正文：优先 Readability，取不到回退 body.innerText；
  /// 结果经空白归一化（行尾空白去除、连续空行压缩）。
  /// [selector] 提供时取该元素文本。
  Future<String> readText({String? selector});

  /// 当前页面 URL（尚未打开任何页面时为 null）。
  Future<String?> currentUrl();

  /// 语义快照（升级设计 §2.1 M4a）：页面标题/URL/标题结构 +
  /// 带 `@N` 编号的可见交互元素列表。ref 映射存页面侧，每次调用
  /// 整体重建，旧编号一律失效。
  Future<String> snapshotDom();

  /// 点击元素（升级设计 §2.2 M4b）。[target] 支持 @N / role: / CSS；
  /// auto-wait 元素可见可用；点击后自动解析导航结果。
  Future<InteractResult> click(String target);

  /// 填表：原生 value setter + input/change 事件；[submit] 追加回车
  /// 提交（无导航时回退 form.requestSubmit）。
  Future<InteractResult> fill(
    String target,
    String text, {
    bool submit = false,
  });

  /// 下拉选择：按 value 精确匹配，其次按可见文本匹配。
  Future<InteractResult> selectOption(String target, String value);

  /// 等待条件成立。超时**返回 false 不抛异常**（借 ego-lite 语义，
  /// 让上层能分支处理）。
  Future<bool> waitFor(WaitForCondition condition, {Duration? timeout});

  /// 批量脚本（升级设计 §2.3 M4c）：在页面上下文执行一段异步 JS，
  /// 注入 `aether` helper facade（click/fill/press/selectOption/read/
  /// waitFor/query/sleep），脚本 `return` 值序列化后作为结果返回。
  Future<String> runScript(String script, {Duration? timeout});

  /// 截图（JPEG 字节，体积受 [options] 控制）。
  Future<Uint8List> snapshot({
    SnapshotOptions options = const SnapshotOptions(),
  });

  /// 释放 WebView。释放后任何调用抛 [BrowserErrorKind.sessionGone]。
  Future<void> close();

  bool get disposed;

  /// 渲染进程已崩溃/无响应（Android 低内存杀进程等）：会话管理器
  /// 据此在下次调用前主动重建，而不是等调用以奇怪错误失败。
  bool get crashed;

  /// 最后一次已知页面 URL（回收前保存，供透明恢复）。
  String? get lastUrl;

  /// 预约透明恢复：下次需要页面的调用（非 open）自动先打开该
  /// URL 续命，避免回收后直接报 sessionGone 让调用方自行处理。
  void scheduleRestore(String url);

  /// 廉价心跳探针：页内 JS 能否在短超时内求值（未打开页面时
  /// 返回 true 不报错）。管理器对闲置较久的会话用它提前发现挂死。
  Future<bool> isResponsive();

  /// 是否已被共驾页可见挂载（用户可能正在看）：会话管理器据此
  /// 跳过空闲释放与 LRU 回收，避免把用户眼前的页面销毁。
  bool get visibleAttached;
}

/// HeadlessInAppWebView 实现。生命周期由 SessionManager 管理，
/// 不要直接长期持有。
class HeadlessBrowserSession implements BrowserSession {
  HeadlessBrowserSession({UrlPolicy? urlPolicy, PageLoadPoller? poller})
    : _urlPolicy = urlPolicy ?? UrlPolicy(),
      _poller = poller ?? const PageLoadPoller();

  final UrlPolicy _urlPolicy;
  final PageLoadPoller _poller;

  HeadlessInAppWebView? _headless;
  InAppWebViewController? _controller;
  InAppWebViewKeepAlive? _keepAlive;
  bool _visibleAttached = false;
  int _runGeneration = 0;
  Completer<void>? _loadStart;
  Completer<void>? _loadStop;
  BrowserException? _blockedNavigation;
  bool _disposed = false;
  bool _crashed = false;
  String? _lastUrl;
  String? _pendingRestoreUrl;
  int _ctxTagCounter = 0;

  // ---- 共驾可见挂载（M4d）----
  // 共驾页用 InAppWebView(headlessWebView:) 把同一个原生 WebView 转为
  // 可见渲染；keepAlive 保证页面退出后原生 WebView 不被销毁，
  // 会话（及 agent 工具）继续可用。

  /// 尚未转可见时的 headless 实例（转换后为 null，改用 [keepAlive]）。
  HeadlessInAppWebView? get headlessWebView => _headless;

  /// 可见挂载的 keepAlive 句柄（首次访问时创建，会话内复用）。
  InAppWebViewKeepAlive get keepAlive => _keepAlive ??= InAppWebViewKeepAlive();

  /// 是否已被可见 InAppWebView 接管渲染。
  @override
  bool get visibleAttached => _visibleAttached;

  /// 可见 InAppWebView 创建完成：接管同一个原生 WebView 的控制器。
  void attachVisible(InAppWebViewController controller) {
    if (_disposed) return;
    _visibleAttached = true;
    _headless = null;
    _controller = controller;
  }

  /// 可见挂载使用：与 headless 回调同一套导航门控。
  void notifyLoadStart([String? url]) {
    if (url != null) _lastUrl = url;
    final loadStart = _loadStart;
    if (loadStart != null && !loadStart.isCompleted) loadStart.complete();
  }

  /// 可见挂载使用：只认本次导航（onLoadStart 之后）的完成信号。
  void notifyLoadStop([String? url]) {
    if (url != null) _lastUrl = url;
    if (_loadStart?.isCompleted != true) return;
    final loadStop = _loadStop;
    if (loadStop != null && !loadStop.isCompleted) loadStop.complete();
  }

  /// 可见挂载使用：与 headless 同一套逐跳 URL 安全复检。
  Future<NavigationActionPolicy> policeNavigation(
    NavigationAction action,
  ) async {
    final target = action.request.url;
    if (target == null) return NavigationActionPolicy.CANCEL;
    try {
      await _urlPolicy.validate(target.toString());
      return NavigationActionPolicy.ALLOW;
    } on BrowserException catch (e) {
      _blockedNavigation = e;
      return NavigationActionPolicy.CANCEL;
    }
  }

  /// JS 执行级超时（设计稿 §19.2）。
  static const _jsTimeout = Duration(seconds: 10);

  static String? _readabilityJs;
  static String? _domSnapshotJs;
  static String? _runHelpersJs;

  @override
  bool get disposed => _disposed;

  @override
  bool get crashed => _crashed;

  @override
  String? get lastUrl => _lastUrl;

  @override
  void scheduleRestore(String url) {
    _pendingRestoreUrl = url;
  }

  @override
  Future<bool> isResponsive() async {
    if (_crashed) return false;
    final controller = _controller;
    if (controller == null) return true; // 尚未建 WebView，无可挂死。
    try {
      await controller
          .evaluateJavascript(source: '1')
          .timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<PageLoadResult> open(String url, {Duration? timeout}) async {
    _ensureAlive();
    _pendingRestoreUrl = null; // 显式 open 优先于透明恢复。
    final uri = await _urlPolicy.validate(url);
    final controller = await _ensureWebView();
    // 新建两个门控再 loadUrl：导航真正开始（onLoadStart）前，旧页/
    // about:blank 的 readyState='complete' 和抢跑的 onLoadStop 都不作数。
    final loadStart = _loadStart = Completer<void>();
    final loadStop = _loadStop = Completer<void>();
    _blockedNavigation = null;
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri.uri(uri)));
    final poller = timeout == null
        ? _poller
        : PageLoadPoller(timeout: timeout, pollInterval: _poller.pollInterval);
    final completed = await poller.wait(
      loadStop: loadStop.future,
      probe: () async {
        if (!loadStart.isCompleted) return false;
        return await _probeReadyState();
      },
    );
    if (!completed) {
      await controller.stopLoading();
      // 重定向被 SSRF 复检拦下时页面会停在半路直到超时：
      // 把真实原因（blockedUrl）回填给调用方，而非笼统的超时。
      final blocked = _blockedNavigation;
      if (blocked != null) throw blocked;
      throw const BrowserException(
        BrowserErrorKind.navigationTimeout,
        '页面加载超时，已截停；会话保留，页面可能部分可读，'
        '可继续 browser_read/browser_snapshot 或换 URL',
      );
    }
    final title = await controller.getTitle() ?? '';
    final finalUrl = (await controller.getUrl())?.toString() ?? uri.toString();
    _lastUrl = finalUrl;
    return PageLoadResult(title: title, finalUrl: finalUrl);
  }

  @override
  Future<String> readText({String? selector}) async {
    _ensureAlive();
    await _requirePage();
    if (selector != null) {
      final text = await _evaluate(
        "document.querySelector(${_jsString(selector)})?.innerText ?? ''",
      );
      return _normalizeText((text as String?) ?? '');
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
    return _normalizeText((result as String?) ?? '');
  }

  @override
  Future<String> snapshotDom() async {
    _ensureAlive();
    await _requirePage();
    final js = await _loadDomSnapshotJs();
    final result = await _evaluate(js);
    var text = (result as String?) ?? '';
    if (text.trim().isEmpty) {
      // 页面刚导航/脚本刚改完 DOM 时偶发空结果，短延迟后重试一次。
      await Future<void>.delayed(const Duration(milliseconds: 300));
      text = ((await _evaluate(js)) as String?) ?? '';
    }
    if (text.trim().isEmpty) {
      throw const BrowserException(
        BrowserErrorKind.internal,
        '语义快照生成失败：页面未返回快照文本；可重新 browser_open 后重试',
      );
    }
    return normalizeExtractedText(text);
  }

  /// 交互前的 auto-wait：元素未就绪（invisible/disabled/notfound）时
  /// 重试的总时长与间隔（升级设计 §2.2）。
  static const _actionWait = Duration(seconds: 5);
  static const _actionPollInterval = Duration(milliseconds: 200);

  /// 动作后等待导航开始的宽限期与新页加载上限。求值结果丢失
  /// （JS 上下文被销毁）强暗示导航，用更长的宽限期免误报。
  static const _navigationGrace = Duration(milliseconds: 1200);
  static const _evalLostNavigationGrace = Duration(seconds: 4);
  static const _navigationWait = Duration(seconds: 15);

  @override
  Future<InteractResult> click(String target) =>
      _interact(ElementTarget.parse(target), buildClickJs);

  @override
  Future<InteractResult> fill(
    String target,
    String text, {
    bool submit = false,
  }) => _interact(
    ElementTarget.parse(target),
    (t) => buildFillJs(t, text, submit: submit),
  );

  @override
  Future<InteractResult> selectOption(String target, String value) => _interact(
    ElementTarget.parse(target),
    (t) => buildSelectOptionJs(t, value),
  );

  Future<InteractResult> _interact(
    ElementTarget target,
    String Function(ElementTarget) buildJs,
  ) async {
    _ensureAlive();
    final controller = await _requirePage();
    final preUrl = (await controller.getUrl())?.toString();
    // 上下文代标记：整页导航会销毁 JS 上下文把它抹掉，pushState
    // 类页内路由则保留——据此区分两种「URL 变了」，避免 @N 过度失效。
    final ctxTag = ++_ctxTagCounter;
    await _evaluate('window.__aetherCtxTag = $ctxTag;');
    // 新建导航门控再动作：动作可能触发导航（点链接/提交表单）。
    final loadStart = _loadStart = Completer<void>();
    final loadStop = _loadStop = Completer<void>();
    _blockedNavigation = null;
    final js = buildJs(target);
    final deadline = DateTime.now().add(_actionWait);
    // 求值结果为 null 通常是动作已触发导航、JS 上下文被销毁——
    // 不能当失败丢回包，交给导航解析兑底判定。
    var evalLost = false;
    while (true) {
      final status = (await _evaluate(js)) as String?;
      if (status == null) {
        evalLost = true;
        break;
      }
      if (status == 'ok') break;
      final retryable =
          status == 'invisible' || status == 'disabled' || status == 'notfound';
      if (!retryable || DateTime.now().isAfter(deadline)) {
        throw _interactError(target, status);
      }
      await Future<void>.delayed(_actionPollInterval);
    }
    final result = await _resolveNavigation(
      controller,
      loadStart,
      loadStop,
      preUrl,
      grace: evalLost ? _evalLostNavigationGrace : _navigationGrace,
      ctxTag: ctxTag,
    );
    if (evalLost && !result.navigated) {
      throw BrowserException(
        BrowserErrorKind.internal,
        '交互动作结果丢失（页面 JS 上下文可能被导航销毁）且未检测到导航；'
        '当前 URL: ${result.url}；请 browser_snapshot_dom 确认页面状态后再继续',
        transient: true,
      );
    }
    return result;
  }

  BrowserException _interactError(ElementTarget target, String status) {
    switch (status) {
      case 'stale':
        return const BrowserException(
          BrowserErrorKind.refStale,
          '@N 引用已失效（页面已导航或快照已重建），请重新 browser_snapshot_dom',
        );
      case 'notfound':
        return BrowserException(
          BrowserErrorKind.elementNotFound,
          '未找到元素 「$target」；可用 browser_snapshot_dom 查看当前可交互元素',
        );
      case 'invisible':
      case 'disabled':
        return BrowserException(
          BrowserErrorKind.elementNotFound,
          '元素 「$target」${status == 'disabled' ? '被禁用' : '不可见'}（已等待 '
          '${_actionWait.inSeconds}s）；页面可能仍在加载或需先展开/滚动',
          transient: true,
        );
      case 'notfillable-select':
        return BrowserException(
          BrowserErrorKind.elementNotFound,
          '目标 「$target」是下拉框（select），请改用 browser_select 选择选项',
        );
      case 'notfillable':
        return BrowserException(
          BrowserErrorKind.elementNotFound,
          '目标 「$target」不是可填写控件（input/textarea/contenteditable）；'
          '可用 browser_snapshot_dom 确认控件角色后换定位',
        );
      default:
        return BrowserException(BrowserErrorKind.internal, '交互动作失败：$status');
    }
  }

  /// 动作后解析导航：宽限期内 onLoadStart 未触发视为页内动作；
  /// 触发了则等新页加载完成（超时截停，页面部分可读）。
  /// 宽限期内持续轮询 URL 变化兑底：快导航/重定向链可能追不上
  /// onLoadStart 门控，URL 变了就按已导航处理（旧 @N 必须作废）；
  /// 只在宽限期末检查一次会漏掉检查后才开始的提交导航。
  Future<InteractResult> _resolveNavigation(
    InAppWebViewController controller,
    Completer<void> loadStart,
    Completer<void> loadStop,
    String? preUrl, {
    Duration grace = _navigationGrace,
    int? ctxTag,
  }) async {
    var started = false;
    final graceDeadline = DateTime.now().add(grace);
    while (true) {
      if (loadStart.isCompleted) {
        started = true;
        break;
      }
      // 忽略 fragment：锥点变化不重建 DOM，不应让旧 @N 被误判失效
      //（hash 路由 SPA 若真换了内容，交互时会报 stale 引导重新快照）。
      final url = (await controller.getUrl())?.toString();
      if (url != null &&
          url.isNotEmpty &&
          _stripFragment(url) != _stripFragment(preUrl ?? '')) {
        started = true;
        break;
      }
      if (DateTime.now().isAfter(graceDeadline)) break;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    var sameDocument = false;
    if (started) {
      final blocked = _blockedNavigation;
      if (blocked != null) throw blocked;
      final poller = PageLoadPoller(
        timeout: _navigationWait,
        pollInterval: _poller.pollInterval,
      );
      final completed = await poller.wait(
        loadStop: loadStop.future,
        probe: _probeReadyState,
      );
      if (!completed) await controller.stopLoading();
      final blockedLate = _blockedNavigation;
      if (blockedLate != null) throw blockedLate;
      // 上下文代标记幸存 = pushState 类页内路由（JS 上下文未销毁，
      // 旧 @N 仍有效）；整页导航会把标记抹掉。
      if (ctxTag != null && !loadStart.isCompleted) {
        try {
          sameDocument = (await _evaluate('window.__aetherCtxTag')) == ctxTag;
        } on BrowserException {
          sameDocument = false;
        }
      }
    }
    final url = (await controller.getUrl())?.toString() ?? '';
    if (url.isNotEmpty) _lastUrl = url;
    return InteractResult(
      navigated: started,
      sameDocument: sameDocument,
      url: url,
      title: await controller.getTitle() ?? '',
    );
  }

  /// 脚本级超时（默认 60s）：脚本内含多步 auto-wait/waitFor，
  /// 比单次 JS 求值宽。
  static const _runScriptTimeout = Duration(seconds: 60);

  static Future<String> _loadRunHelpersJs() async =>
      _runHelpersJs ??= await rootBundle.loadString(
        'packages/aetherlink_browser/assets/js/run_helpers.js',
      );

  @override
  Future<String> runScript(String script, {Duration? timeout}) async {
    _ensureAlive();
    final controller = await _requirePage();
    await _evaluate(await _loadRunHelpersJs());
    // 协作式取消代数：helper 工厂捕获当前代数，超时/新脚本递增后
    // 残留脚本在下一个检查点自行终止。
    _runGeneration++;
    await _evaluate('window.__aetherRunGen = $_runGeneration;');
    // 供 aether.snapshot() 页内重建 @N ref（与顶层 snapshotDom 同一套逻辑）。
    final snapshotSrc = await _loadDomSnapshotJs();
    await _evaluate(
      'window.__aetherSnapshot = function () { return (\n$snapshotSrc\n); };',
    );
    final body =
        '''
const aether = window.__aetherMakeHelpers();
return await (async () => {
$script
})();''';
    // 脚本内动作触发导航会销毁 JS 上下文，callAsyncJavaScript 永不
    // 回调——用导航门控兑底：新页加载完成后给结果回传一点时间，
    // 仍无结果则按「无返回值（被导航中断）」返回，而非等到超时。
    final loadStart = _loadStart = Completer<void>();
    final loadStop = _loadStop = Completer<void>();
    _blockedNavigation = null;
    final CallAsyncJavaScriptResult? result;
    try {
      result = await Future.any<CallAsyncJavaScriptResult?>([
        controller.callAsyncJavaScript(functionBody: body),
        _navigationDestroysContext(loadStart, loadStop),
      ]).timeout(timeout ?? _runScriptTimeout);
    } on TimeoutException {
      // 递增代数取消残留脚本（页内无法强杀，协作式自杀），
      // 避免其后续动作与下一个工具调用交错。
      _runGeneration++;
      try {
        await _evaluate('window.__aetherRunGen = $_runGeneration;');
      } on BrowserException {
        // 页面挂死/导航时取消信号发不进去也不阻塞报错。
      }
      throw BrowserException(
        BrowserErrorKind.scriptTimeout,
        '脚本执行超时（${(timeout ?? _runScriptTimeout).inSeconds}s）；'
        '残留脚本已取消，可拆分脚本或改用单步工具',
        transient: true,
      );
    }
    if (result == null) {
      // 页面导航/销毁会让执行上下文丢失，拿不到返回值。
      return '';
    }
    final error = result.error;
    if (error != null) {
      throw BrowserException(BrowserErrorKind.internal, '脚本执行出错：$error');
    }
    final value = result.value;
    if (value == null) return '';
    return value is String ? value : jsonEncode(value);
  }

  /// 等待「脚本触发的导航已销毁执行上下文」：导航开始 → 新页
  /// 加载完成（或超时截止）→ 短宽限期（若结果其实能回传，让它先赢）。
  Future<CallAsyncJavaScriptResult?> _navigationDestroysContext(
    Completer<void> loadStart,
    Completer<void> loadStop,
  ) async {
    await loadStart.future;
    final poller = PageLoadPoller(
      timeout: _navigationWait,
      pollInterval: _poller.pollInterval,
    );
    await poller.wait(loadStop: loadStop.future, probe: _probeReadyState);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return null;
  }

  @override
  Future<bool> waitFor(WaitForCondition condition, {Duration? timeout}) async {
    _ensureAlive();
    await _requirePage();
    if (condition.isEmpty) {
      throw const BrowserException(
        BrowserErrorKind.elementNotFound,
        'waitFor 需要提供 selector / urlContains / jsPredicate 之一',
      );
    }
    final selectorJs = condition.selector == null
        ? null
        : buildSelectorProbeJs(ElementTarget.parse(condition.selector!));
    final deadline = DateTime.now().add(timeout ?? const Duration(seconds: 10));
    while (true) {
      if (await _probeCondition(condition, selectorJs)) return true;
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(_actionPollInterval);
    }
  }

  Future<bool> _probeCondition(
    WaitForCondition condition,
    String? selectorJs,
  ) async {
    if (selectorJs != null) {
      if ((await _evaluate(selectorJs)) != true) return false;
    }
    final urlContains = condition.urlContains;
    if (urlContains != null) {
      final url = (await _controller?.getUrl())?.toString() ?? '';
      if (!url.contains(urlContains)) return false;
    }
    final predicate = condition.jsPredicate;
    if (predicate != null) {
      final result = await _evaluate(
        '(() => { try { return !!($predicate); } catch (e) { return false; } })()',
      );
      if (result != true) return false;
    }
    return true;
  }

  @override
  Future<String?> currentUrl() async {
    _ensureAlive();
    final controller = _controller;
    if (controller == null) return null;
    return (await controller.getUrl())?.toString();
  }

  @override
  Future<Uint8List> snapshot({
    SnapshotOptions options = const SnapshotOptions(),
  }) async {
    _ensureAlive();
    final controller = await _requirePage();
    final headless = _headless;
    if (headless == null) {
      // 已转可见挂载：无法调整尺寸，按当前视口截图。
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
    }
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
    final keepAlive = _keepAlive;
    _keepAlive = null;
    if (keepAlive != null) {
      await InAppWebViewController.disposeKeepAlive(keepAlive);
    }
  }

  Future<InAppWebViewController> _ensureWebView() async {
    final existing = _controller;
    if (existing != null) return existing;
    final created = Completer<InAppWebViewController>();
    final headless = HeadlessInAppWebView(
      initialSize: const Size(1024, 1536),
      initialSettings: InAppWebViewSettings(
        javaScriptCanOpenWindowsAutomatically: false,
        // headless 不支持真多窗口：开启后 target=_blank 等走
        // onCreateWindow 降级为当前窗口导航，而不是点了没反应。
        supportMultipleWindows: true,
        allowFileAccess: false,
        allowFileAccessFromFileURLs: false,
        allowUniversalAccessFromFileURLs: false,
      ),
      onWebViewCreated: (controller) {
        if (!created.isCompleted) created.complete(controller);
      },
      onLoadStart: (controller, url) => notifyLoadStart(url?.toString()),
      onLoadStop: (controller, url) => notifyLoadStop(url?.toString()),
      // 重定向/页内导航逐跳复检（设计稿 §15.2 第 3 条）。
      shouldOverrideUrlLoading: (controller, action) =>
          policeNavigation(action),
      // 新窗口降级：target=_blank / window.open 在当前窗口导航
      //（同样过 SSRF 复检），不创建新 WebView。
      onCreateWindow: (controller, action) async {
        final target = action.request.url;
        if (target != null &&
            await policeNavigation(action) == NavigationActionPolicy.ALLOW) {
          await controller.loadUrl(urlRequest: URLRequest(url: target));
        }
        return false;
      },
      // JS 对话框自动处理（对齐 Playwright 缺省 dismiss 语义）：
      // headless 无人可点，不处理会阻塞页面 JS，后续求值全部超时。
      onJsAlert: (controller, request) async => JsAlertResponse(
        handledByClient: true,
        action: JsAlertResponseAction.CONFIRM,
      ),
      onJsConfirm: (controller, request) async => JsConfirmResponse(
        handledByClient: true,
        action: JsConfirmResponseAction.CANCEL,
      ),
      onJsPrompt: (controller, request) async => JsPromptResponse(
        handledByClient: true,
        action: JsPromptResponseAction.CANCEL,
      ),
      // 渲染进程崩溃/无响应（Android 低内存常见）：标记后会话
      // 管理器在下次调用前主动重建并透明恢复，不等调用诡异失败。
      onRenderProcessGone: (controller, detail) {
        _crashed = true;
      },
      onRenderProcessUnresponsive: (controller, url) async {
        _crashed = true;
        return WebViewRenderProcessAction.TERMINATE;
      },
    );
    _headless = headless;
    await headless.run();
    return _controller = await created.future;
  }

  /// 探页面是否加载完成；导航中 JS 上下文可能不可用（求值超时/抛错），
  /// 按未完成处理而非向外抛——否则一次探活失败会把整次等待打死。
  Future<bool> _probeReadyState() async {
    try {
      return (await _evaluate("document.readyState")) == 'complete';
    } on BrowserException {
      return false;
    }
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
    if (_crashed) {
      throw const BrowserException(
        BrowserErrorKind.sessionGone,
        '浏览器渲染进程已崩溃（可能被系统回收），请重新 browser_open',
        transient: true,
      );
    }
  }

  /// 需要页面的调用入口：若有预约的透明恢复且尚无页面，先重开
  /// 上次 URL 续命（cookie 全局共享，登录态不丢）再继续。
  Future<InAppWebViewController> _requirePage() async {
    final pending = _pendingRestoreUrl;
    if (_controller == null && pending != null) {
      _pendingRestoreUrl = null;
      await open(pending);
    }
    return _ensureNavigated();
  }

  InAppWebViewController _ensureNavigated() {
    final controller = _controller;
    if (controller == null) {
      throw const BrowserException(
        BrowserErrorKind.sessionGone,
        '尚未打开任何页面（或会话空闲已被回收），请先 browser_open',
      );
    }
    return controller;
  }

  static Future<String> _loadReadabilityJs() async =>
      _readabilityJs ??= await rootBundle.loadString(
        'packages/aetherlink_browser/assets/js/readability.js',
      );

  static Future<String> _loadDomSnapshotJs() async =>
      _domSnapshotJs ??= await rootBundle.loadString(
        'packages/aetherlink_browser/assets/js/dom_snapshot.js',
      );

  static String _stripFragment(String url) {
    final i = url.indexOf('#');
    return i < 0 ? url : url.substring(0, i);
  }

  static String _jsString(String value) =>
      "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', r'\n').replaceAll('\r', r'\r')}'";

  static String _normalizeText(String text) => normalizeExtractedText(text);
}

/// 正文空白归一化（设计稿 §19.3 体积控制）：CRLF 统一、行尾空白去除、
/// 3 个以上连续换行压成 2 个，减少无意义字符占用上下文。
String normalizeExtractedText(String text) => text
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'[ \t]+(?=\n)'), '')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
