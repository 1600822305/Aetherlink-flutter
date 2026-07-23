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
  });

  final String text;
  final String domSnapshot;
  final Uint8List? bytes;
  final BrowserException? openError;
  final BrowserException? readError;

  String? url;
  String? openedUrl;
  Duration? openedTimeout;
  String? readSelector;
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
        'browser_click',
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
    test('catalog 注册了只读工具集', () {
      final tools = builtinToolsFor(kBrowserServerName);
      expect(
        tools.map((t) => t.name),
        containsAll([
          'browser_open',
          'browser_read',
          'browser_snapshot',
          'browser_snapshot_dom',
        ]),
      );
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
