import 'dart:io';
import 'dart:typed_data';

import 'package:aetherlink_browser/aetherlink_browser.dart';
import 'package:aetherlink_flutter/shared/config/builtin_mcp_servers.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/browser/browser_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tool_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSession implements BrowserSession {
  _FakeSession({
    this.text = '',
    this.bytes,
    this.openError,
    this.readError,
  });

  final String text;
  final Uint8List? bytes;
  final BrowserException? openError;
  final BrowserException? readError;

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
    return const PageLoadResult(title: '示例页', finalUrl: 'https://example.com/');
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
    test('catalog 注册了只读三件套', () {
      final tools = builtinToolsFor(kBrowserServerName);
      expect(
        tools.map((t) => t.name),
        containsAll(['browser_open', 'browser_read', 'browser_snapshot']),
      );
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
