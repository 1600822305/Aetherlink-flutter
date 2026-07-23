import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_browser/aetherlink_browser.dart';

class _FakeSession implements BrowserSession {
  bool closed = false;

  @override
  bool get disposed => closed;

  @override
  Future<PageLoadResult> open(String url, {Duration? timeout}) async =>
      PageLoadResult(title: 't', finalUrl: url);

  @override
  Future<String> readText({String? selector}) async => 'text';

  @override
  Future<String?> currentUrl() async => null;

  @override
  Future<Uint8List> snapshot({
    SnapshotOptions options = const SnapshotOptions(),
  }) async =>
      Uint8List(0);

  @override
  Future<void> close() async => closed = true;
}

void main() {
  test('并发调用互斥串行（按提交顺序）', () async {
    final manager = BrowserSessionManager(factory: _FakeSession.new);
    final order = <int>[];
    final gate = Completer<void>();
    final first = manager.run((s) async {
      await gate.future;
      order.add(1);
    });
    final second = manager.run((s) async => order.add(2));
    final third = manager.run((s) async => order.add(3));
    expect(order, isEmpty);
    gate.complete();
    await Future.wait([first, second, third]);
    expect(order, [1, 2, 3]);
  });

  test('单实例共享：多次 run 拿到同一个会话', () async {
    var created = 0;
    final manager = BrowserSessionManager(
      factory: () {
        created++;
        return _FakeSession();
      },
    );
    BrowserSession? a, b;
    await manager.run((s) async => a = s);
    await manager.run((s) async => b = s, sessionId: 'other');
    expect(identical(a, b), isTrue);
    expect(created, 1);
  });

  test('空闲超时释放，下次调用重建', () async {
    var created = 0;
    _FakeSession? last;
    final manager = BrowserSessionManager(
      factory: () {
        created++;
        return last = _FakeSession();
      },
      idleTimeout: const Duration(milliseconds: 50),
    );
    await manager.run((s) async {});
    final first = last!;
    expect(manager.hasLiveSession, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(first.closed, isTrue);
    expect(manager.hasLiveSession, isFalse);
    await manager.run((s) async {});
    expect(created, 2);
    await manager.closeAll();
  });

  test('连续 2 次超时类失败后重建 WebView', () async {
    var created = 0;
    _FakeSession? last;
    final manager = BrowserSessionManager(
      factory: () {
        created++;
        return last = _FakeSession();
      },
    );
    Future<void> failOnce() => manager
        .run<void>((s) async {
          throw const BrowserException(BrowserErrorKind.navigationTimeout, 'x');
        })
        .catchError((_) {});
    await failOnce();
    final first = last!;
    expect(first.closed, isFalse);
    await failOnce();
    expect(first.closed, isTrue);
    await manager.run((s) async {});
    expect(created, 2);
    await manager.closeAll();
  });

  test('成功调用重置连续失败计数', () async {
    var created = 0;
    final manager = BrowserSessionManager(
      factory: () {
        created++;
        return _FakeSession();
      },
    );
    Future<void> failOnce() => manager
        .run<void>((s) async {
          throw const BrowserException(BrowserErrorKind.scriptTimeout, 'x');
        })
        .catchError((_) {});
    await failOnce();
    await manager.run((s) async {});
    await failOnce();
    expect(created, 1);
    await manager.closeAll();
  });

  test('blockedUrl 等非超时失败不触发重建', () async {
    var created = 0;
    final manager = BrowserSessionManager(
      factory: () {
        created++;
        return _FakeSession();
      },
    );
    for (var i = 0; i < 3; i++) {
      await manager
          .run<void>((s) async {
            throw const BrowserException(BrowserErrorKind.blockedUrl, 'x');
          })
          .catchError((_) {});
    }
    expect(created, 1);
    await manager.closeAll();
  });

  test('closeAll 后拒绝新调用', () async {
    final manager = BrowserSessionManager(factory: _FakeSession.new);
    await manager.run((s) async {});
    await manager.closeAll();
    expect(
      () => manager.run((s) async {}),
      throwsA(
        isA<BrowserException>()
            .having((e) => e.kind, 'kind', BrowserErrorKind.sessionGone),
      ),
    );
  });
}
