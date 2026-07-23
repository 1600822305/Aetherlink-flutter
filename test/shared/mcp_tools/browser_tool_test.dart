import 'dart:io';
import 'dart:typed_data';

import 'package:aetherlink_browser/aetherlink_browser.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_microcompact.dart';
import 'package:aetherlink_flutter/shared/config/builtin_mcp_servers.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/browser/browser_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tool_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSession implements BrowserSession {
  _FakeSession({
    this.text = '',
    this.domSnapshot = '',
    this.bytes,
    this.openError,
    this.readError,
    this.interactError,
    this.interactResult = const InteractResult(
      navigated: false,
      url: 'https://example.com/',
      title: '示例页',
    ),
    this.waitForResult = true,
    this.scriptResult = '',
  });

  final String text;
  final String domSnapshot;
  final Uint8List? bytes;
  final BrowserException? openError;
  final BrowserException? readError;
  final BrowserException? interactError;
  final InteractResult interactResult;
  final bool waitForResult;
  final String scriptResult;

  String? url;
  String? openedUrl;
  Duration? openedTimeout;
  String? readSelector;
  String? clickedTarget;
  String? filledTarget;
  String? filledText;
  bool? filledSubmit;
  WaitForCondition? waitedCondition;
  Duration? waitedTimeout;
  String? ranScript;
  Duration? ranTimeout;
  SnapshotOptions? snapshotOptions;
  bool closed = false;

  @override
  Future<PageLoadResult> open(String url, {Duration? timeout}) async {
    final error = openError;
    if (error != null) throw error;
    openedUrl = url;
    openedTimeout = timeout;
    this.url = 'https://example.com/';
    return const PageLoadResult(title: '示例页', finalUrl: 'https://example.com/');
  }

  @override
  Future<String?> currentUrl() async => url;

  @override
  Future<String> snapshotDom() async {
    final error = readError;
    if (error != null) throw error;
    return domSnapshot;
  }

  @override
  Future<InteractResult> click(String target) async {
    final error = interactError;
    if (error != null) throw error;
    clickedTarget = target;
    return interactResult;
  }

  @override
  Future<InteractResult> fill(String target, String text,
      {bool submit = false}) async {
    final error = interactError;
    if (error != null) throw error;
    filledTarget = target;
    filledText = text;
    filledSubmit = submit;
    return interactResult;
  }

  @override
  Future<InteractResult> selectOption(String target, String value) async =>
      interactResult;

  @override
  Future<bool> waitFor(WaitForCondition condition, {Duration? timeout}) async {
    waitedCondition = condition;
    waitedTimeout = timeout;
    return waitForResult;
  }

  @override
  Future<String> runScript(String script, {Duration? timeout}) async {
    final error = interactError;
    if (error != null) throw error;
    ranScript = script;
    ranTimeout = timeout;
    return scriptResult;
  }

  @override
  Future<String> readText({String? selector}) async {
    final error = readError;
    if (error != null) throw error;
    readSelector = selector;
    return text;
  }

  @override
  Future<Uint8List> snapshot({
    SnapshotOptions options = const SnapshotOptions(),
  }) async {
    snapshotOptions = options;
    return bytes ?? Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> close() async => closed = true;

  @override
  bool get disposed => closed;
}

BrowserSessionManager _managerOf(_FakeSession session) =>
    BrowserSessionManager(factory: () => session);

void main() {
  group('runBrowserTool', () {
    test('未知工具名返回错误', () async {
      final result = await runBrowserTool(
        'browser_drag',
        {},
        manager: _managerOf(_FakeSession()),
      );
      expect(result.isError, isTrue);
      expect(result.text, contains('未知的工具'));
    });

    test('browser_open 缺 url 返回错误且不触发导航', () async {
      final session = _FakeSession();
      final result = await runBrowserTool(
        'browser_open',
        {},
        manager: _managerOf(session),
      );
      expect(result.isError, isTrue);
      expect(session.openedUrl, isNull);
    });

    test('browser_open 返回标题/最终 URL + 不可信边界包裹的预览', () async {
      final session = _FakeSession(text: '页面正文内容');
      final result = await runBrowserTool(
        'browser_open',
        {'url': 'https://example.com', 'timeout_seconds': 10},
        manager: _managerOf(session),
      );
      expect(result.isError, isFalse);
      expect(session.openedUrl, 'https://example.com');
      expect(session.openedTimeout, const Duration(seconds: 10));
      expect(result.text, contains('标题: 示例页'));
      expect(result.text, contains('最终 URL: https://example.com/'));
      expect(result.text,
          contains('<untrusted-web-content src="https://example.com/">'));
      expect(result.text, contains('页面正文内容'));
      expect(result.text, contains('</untrusted-web-content>'));
    });

    test('browser_open 预览提取失败不影响 open 成功', () async {
      final session = _FakeSession(
        readError: const BrowserException(
          BrowserErrorKind.scriptTimeout,
          '脚本超时',
        ),
      );
      final result = await runBrowserTool(
        'browser_open',
        {'url': 'https://example.com'},
        manager: _managerOf(session),
      );
      expect(result.isError, isFalse);
      expect(result.text, contains('标题: 示例页'));
    });

    test('browser_open 的 BrowserException 转分类错误消息', () async {
      final session = _FakeSession(
        openError: const BrowserException(
          BrowserErrorKind.blockedUrl,
          '禁止访问内网地址',
        ),
      );
      final result = await runBrowserTool(
        'browser_open',
        {'url': 'http://192.168.1.1'},
        manager: _managerOf(session),
      );
      expect(result.isError, isTrue);
      expect(result.text, contains('blockedUrl'));
      expect(result.text, contains('禁止访问内网地址'));
    });

    test('browser_read 包裹不可信边界并透传 selector', () async {
      final session = _FakeSession(text: '正文 abc');
      final result = await runBrowserTool(
        'browser_read',
        {'selector': '#main'},
        manager: _managerOf(session),
      );
      expect(result.isError, isFalse);
      expect(session.readSelector, '#main');
      expect(result.text, contains('<untrusted-web-content'));
      expect(result.text, contains('正文 abc'));
    });

    test('browser_read 边界 src 使用当前页面 URL（取不到时降级占位）',
        () async {
      final session = _FakeSession(text: '正文')..url = 'https://a.com/p';
      final result = await runBrowserTool(
        'browser_read',
        {},
        manager: _managerOf(session),
      );
      expect(
        result.text,
        contains('<untrusted-web-content src="https://a.com/p">'),
      );
      final noUrl = _FakeSession(text: '正文');
      final fallback = await runBrowserTool(
        'browser_read',
        {},
        manager: _managerOf(noUrl),
      );
      expect(
        fallback.text,
        contains('<untrusted-web-content src="当前页面">'),
      );
    });

    test('browser_read 分块：超长内容带续读提示', () async {
      final session = _FakeSession(text: 'a' * 6000);
      final result = await runBrowserTool(
        'browser_read',
        {'max_length': 5000},
        manager: _managerOf(session),
      );
      expect(result.isError, isFalse);
      expect(result.text, contains('<content_truncated>'));
      expect(result.text, contains('start_index=5000'));
    });

    test('browser_read start_index 越界返回错误', () async {
      final session = _FakeSession(text: 'abc');
      final result = await runBrowserTool(
        'browser_read',
        {'start_index': 100},
        manager: _managerOf(session),
      );
      expect(result.isError, isTrue);
      expect(result.text, contains('超出内容长度'));
    });

    test('browser_snapshot_dom 返回不可信边界包裹的语义快照 + ref 失效提示', () async {
      final session = _FakeSession(domSnapshot: '页面: 示例\n@1 button "登录"');
      session.url = 'https://example.com/';
      final result = await runBrowserTool(
        'browser_snapshot_dom',
        {},
        manager: _managerOf(session),
      );
      expect(result.isError, isFalse);
      expect(result.text,
          contains('<untrusted-web-content src="https://example.com/">'));
      expect(result.text, contains('@1 button'));
      expect(result.text, contains('@N 编号仅在本次快照后有效'));
    });

    test('browser_snapshot_dom 的 BrowserException 转分类错误消息', () async {
      final session = _FakeSession(
        readError: const BrowserException(
          BrowserErrorKind.sessionGone,
          '尚未打开任何页面',
        ),
      );
      final result = await runBrowserTool(
        'browser_snapshot_dom',
        {},
        manager: _managerOf(session),
      );
      expect(result.isError, isTrue);
      expect(result.text, contains('sessionGone'));
    });

    test('browser_click 返回导航结果与 ref 失效提示', () async {
      final session = _FakeSession(
        interactResult: const InteractResult(
          navigated: true,
          url: 'https://example.com/next',
          title: '下一页',
        ),
      );
      final result = await runBrowserTool(
        'browser_click',
        {'target': '@3'},
        manager: _managerOf(session),
      );
      expect(result.isError, isFalse);
      expect(session.clickedTarget, '@3');
      expect(result.text, contains('页面已导航'));
      expect(result.text, contains('下一页'));
      expect(result.text, contains('旧 @N 编号已失效'));
    });

    test('browser_click 缺 target 返回错误', () async {
      final result = await runBrowserTool(
        'browser_click',
        {},
        manager: _managerOf(_FakeSession()),
      );
      expect(result.isError, isTrue);
    });

    test('browser_click 的 refStale 转分类错误消息', () async {
      final session = _FakeSession(
        interactError: const BrowserException(
          BrowserErrorKind.refStale,
          '@N 引用已失效',
        ),
      );
      final result = await runBrowserTool(
        'browser_click',
        {'target': '@9'},
        manager: _managerOf(session),
      );
      expect(result.isError, isTrue);
      expect(result.text, contains('refStale'));
    });

    test('browser_input 透传 target/text/submit，未导航返回页内动作', () async {
      final session = _FakeSession();
      final result = await runBrowserTool(
        'browser_input',
        {'target': 'role:textbox:搜索', 'text': 'flutter', 'submit': true},
        manager: _managerOf(session),
      );
      expect(result.isError, isFalse);
      expect(session.filledTarget, 'role:textbox:搜索');
      expect(session.filledText, 'flutter');
      expect(session.filledSubmit, isTrue);
      expect(result.text, contains('页面未导航'));
    });

    test('browser_wait 条件成立/超时分支', () async {
      final session = _FakeSession();
      final ok = await runBrowserTool(
        'browser_wait',
        {'selector': '@1', 'timeout_seconds': 5},
        manager: _managerOf(session),
      );
      expect(ok.isError, isFalse);
      expect(ok.text, contains('条件已成立'));
      expect(session.waitedCondition?.selector, '@1');
      expect(session.waitedTimeout, const Duration(seconds: 5));

      final timedOut = await runBrowserTool(
        'browser_wait',
        {'url_contains': '/done'},
        manager: _managerOf(_FakeSession(waitForResult: false)),
      );
      expect(timedOut.isError, isFalse);
      expect(timedOut.text, contains('等待超时'));
    });

    test('browser_wait 无条件返回错误', () async {
      final result = await runBrowserTool(
        'browser_wait',
        {},
        manager: _managerOf(_FakeSession()),
      );
      expect(result.isError, isTrue);
    });

    test('browser_run 透传脚本/超时，返回值走不可信边界包裹', () async {
      final session = _FakeSession(scriptResult: '{"rows":3}');
      session.url = 'https://example.com/';
      final result = await runBrowserTool(
        'browser_run',
        {'script': 'return {rows: 3};', 'timeout_seconds': 30},
        manager: _managerOf(session),
      );
      expect(result.isError, isFalse);
      expect(session.ranScript, 'return {rows: 3};');
      expect(session.ranTimeout, const Duration(seconds: 30));
      expect(result.text,
          contains('<untrusted-web-content src="https://example.com/">'));
      expect(result.text, contains('{"rows":3}'));
    });

    test('browser_run 无返回值提示可能被导航中断', () async {
      final result = await runBrowserTool(
        'browser_run',
        {'script': 'aether.click("@1");'},
        manager: _managerOf(_FakeSession()),
      );
      expect(result.isError, isFalse);
      expect(result.text, contains('脚本无返回值'));
    });

    test('browser_run 缺 script 返回错误', () async {
      final result = await runBrowserTool(
        'browser_run',
        {},
        manager: _managerOf(_FakeSession()),
      );
      expect(result.isError, isTrue);
    });

    test('browser_snapshot 截图落盘并回填 imagePath/imageMimeType', () async {
      final session = _FakeSession(bytes: Uint8List.fromList([9, 8, 7, 6]));
      final dir = await Directory.systemTemp.createTemp('browser_shot_test');
      addTearDown(() => dir.delete(recursive: true));
      final result = await runBrowserTool(
        'browser_snapshot',
        {'full_page': true, 'max_width': 800},
        manager: _managerOf(session),
        screenshotDir: () async => dir,
      );
      expect(result.isError, isFalse);
      expect(session.snapshotOptions?.fullPage, isTrue);
      expect(session.snapshotOptions?.maxWidth, 800);
      expect(result.imageMimeType, 'image/jpeg');
      expect(result.imagePath, isNotNull);
      expect(await File(result.imagePath!).readAsBytes(), [9, 8, 7, 6]);
    });

    test('管理器已关闭时返回 sessionGone 错误而非抛异常', () async {
      final manager = _managerOf(_FakeSession());
      await manager.closeAll();
      final result = await runBrowserTool(
        'browser_read',
        {},
        manager: manager,
      );
      expect(result.isError, isTrue);
      expect(result.text, contains('sessionGone'));
    });
  });

  group('注册面', () {
    test('catalog 注册了完整浏览器工具集', () {
      final tools = builtinToolsFor(kBrowserServerName);
      expect(
        tools.map((t) => t.name),
        containsAll([
          'browser_open',
          'browser_read',
          'browser_snapshot',
          'browser_snapshot_dom',
          'browser_click',
          'browser_input',
          'browser_wait',
          'browser_run',
        ]),
      );
    });

    test('交互工具需审批，只读工具不需要', () {
      expect(browserToolNeedsConfirmation('browser_click'), isTrue);
      expect(browserToolNeedsConfirmation('browser_input'), isTrue);
      expect(browserToolNeedsConfirmation('browser_run'), isTrue);
      expect(browserToolNeedsConfirmation('browser_open'), isFalse);
      expect(browserToolNeedsConfirmation('browser_snapshot_dom'), isFalse);
      expect(browserToolNeedsConfirmation('browser_wait'), isFalse);
    });

    test('open/read/snapshot_dom 在 microcompact 白名单（网页内容可重取），snapshot 不在', () {
      expect(
        kMicroCompactableTools,
        containsAll(['browser_open', 'browser_read', 'browser_snapshot_dom']),
      );
      expect(kMicroCompactableTools, isNot(contains('browser_snapshot')));
    });

    test('@aether/browser 属于本地可执行内置服务器且在服务器目录里', () {
      expect(kLocallyRunnableBuiltins, contains(kBrowserServerName));
      expect(
        kBuiltinMcpServers.map((s) => s.name),
        contains(kBrowserServerName),
      );
    });
  });
}
