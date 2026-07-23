import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_browser/aetherlink_browser.dart';

class _FakeSession implements BrowserSession {
  bool closed = false;
  bool visible = false;
  bool crashedFlag = false;
  bool responsive = true;
  String? _lastUrl;
  String? restoreScheduled;

  @override
  bool get disposed => closed;

  @override
  bool get visibleAttached => visible;

  @override
  bool get crashed => crashedFlag;

  @override
  String? get lastUrl => _lastUrl;

  @override
  void scheduleRestore(String url) => restoreScheduled = url;

  @override
  Future<bool> isResponsive() async => responsive;

  @override
  Future<PageLoadResult> open(String url, {Duration? timeout}) async {
    _lastUrl = url;
    return PageLoadResult(title: 't', finalUrl: url);
  }

  @override
  Future<String> readText({String? selector}) async => 'text';

  @override
  Future<String?> currentUrl() async => null;

  @override
  Future<String> snapshotDom() async => 'snapshot';

  @override
  Future<InteractResult> click(String target) async =>
      const InteractResult(navigated: false, url: '', title: '');

  @override
  Future<InteractResult> fill(
    String target,
    String text, {
    bool submit = false,
  }) async => const InteractResult(navigated: false, url: '', title: '');

  @override
  Future<InteractResult> selectOption(String target, String value) async =>
      const InteractResult(navigated: false, url: '', title: '');

  @override
  Future<bool> waitFor(WaitForCondition condition, {Duration? timeout}) async =>
      true;

  @override
  Future<String> runScript(String script, {Duration? timeout}) async => '';

  @override
  Future<Uint8List> snapshot({
    SnapshotOptions options = const SnapshotOptions(),
  }) async => Uint8List(0);

  @override
  Future<void> close() async => closed = true;
}

int _liveCount(List<_FakeSession> all) => all.where((s) => !s.closed).length;

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

  test('同 id 复用会话，不同 id 建独立会话', () async {
    var created = 0;
    final manager = BrowserSessionManager(
      factory: () {
        created++;
        return _FakeSession();
      },
    );
    BrowserSession? a, b, c;
    await manager.run((s) async => a = s);
    await manager.run((s) async => b = s); // 缺省 = default
    await manager.run((s) async => c = s, sessionId: 'other');
    expect(identical(a, b), isTrue);
    expect(identical(a, c), isFalse);
    expect(created, 2);
    await manager.closeAll();
  });

  test('LRU 触底回收：超上限时回收最久未用的 agent 会话', () async {
    final sessions = <String, _FakeSession>{};
    String? next;
    final manager = BrowserSessionManager(
      factory: () => sessions[next!] = _FakeSession(),
      maxSessions: 2,
    );
    next = 'a';
    await manager.run((s) async {}, sessionId: 'a');
    next = 'b';
    await manager.run((s) async {}, sessionId: 'b');
    next = 'a';
    await manager.run((s) async {}, sessionId: 'a'); // a 变为最近使用
    next = 'c';
    await manager.run((s) async {}, sessionId: 'c');
    // 等回收（挂队列异步执行）落地。
    await Future<void>.delayed(Duration.zero);
    expect(sessions['b']!.closed, isTrue);
    expect(sessions['a']!.closed, isFalse);
    expect(sessions['c']!.closed, isFalse);
    await manager.closeAll();
  });

  test('handOff 只切换主导标记，不限制工具调用（宽松共驾）；takeOver 收回', () async {
    final manager = BrowserSessionManager(factory: _FakeSession.new);
    await manager.run((s) async {});
    manager.handOff(null, note: '请完成登录', url: 'https://example.com/login');
    expect(manager.ownershipOf(null), SessionOwnership.delegatedToUser);
    // 宽松共驾：交接期间 agent 工具仍可调用。
    await manager.run((s) async {});
    final info = manager.sessionInfos.singleWhere((i) => i.id == 'default');
    expect(info.handOffNote, '请完成登录');
    expect(info.handOffUrl, 'https://example.com/login');
    manager.takeOver(null);
    expect(manager.ownershipOf(null), SessionOwnership.agent);
    await manager.run((s) async {});
    await manager.closeAll();
  });

  test('用户控制中的会话不参与空闲释放', () async {
    _FakeSession? last;
    final manager = BrowserSessionManager(
      factory: () => last = _FakeSession(),
      idleTimeout: const Duration(milliseconds: 50),
    );
    await manager.run((s) async {});
    manager.handOff(null);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(last!.closed, isFalse);
    await manager.closeAll();
  });

  test('释放后无特殊状态的条目从 sessionInfos 移除（不累积幽灵条目）', () async {
    final manager = BrowserSessionManager(
      factory: _FakeSession.new,
      idleTimeout: const Duration(milliseconds: 50),
    );
    await manager.run((s) async {}, sessionId: 'a');
    expect(manager.sessionInfos.map((i) => i.id), contains('a'));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(manager.sessionInfos.map((i) => i.id), isNot(contains('a')));
    await manager.closeAll();
  });

  test('handOff/takeOver/userClaim 对未知会话不创建幽灵条目', () async {
    final manager = BrowserSessionManager(factory: _FakeSession.new);
    manager.handOff('ghost1', note: 'x');
    manager.takeOver('ghost2');
    manager.userClaim('ghost3');
    expect(manager.sessionInfos, isEmpty);
    await manager.closeAll();
  });

  test('共驾可见挂载的会话不被空闲回收', () async {
    _FakeSession? last;
    final manager = BrowserSessionManager(
      factory: () => last = _FakeSession(),
      idleTimeout: const Duration(milliseconds: 50),
    );
    await manager.run((s) async {});
    last!.visible = true;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(last!.closed, isFalse);
    await manager.closeAll();
  });

  test('共驾可见挂载的会话不被 LRU 回收', () async {
    final sessions = <String, _FakeSession>{};
    String? next;
    final manager = BrowserSessionManager(
      factory: () => sessions[next!] = _FakeSession(),
      maxSessions: 2,
    );
    next = 'a';
    await manager.run((s) async {}, sessionId: 'a');
    sessions['a']!.visible = true;
    next = 'b';
    await manager.run((s) async {}, sessionId: 'b');
    next = 'c';
    await manager.run((s) async {}, sessionId: 'c');
    await Future<void>.delayed(Duration.zero);
    expect(sessions['a']!.closed, isFalse); // 可见挂载被跳过。
    expect(sessions['b']!.closed, isTrue);
    await manager.closeAll();
  });

  test('LRU 回收完成后才新建：存活数不瞬时超上限', () async {
    final live = <_FakeSession>[];
    var peak = 0;
    final manager = BrowserSessionManager(
      factory: () {
        final s = _FakeSession();
        live.add(s);
        peak = peak > _liveCount(live) ? peak : _liveCount(live);
        return s;
      },
      maxSessions: 1,
    );
    await manager.run((s) async {}, sessionId: 'a');
    await manager.run((s) async {}, sessionId: 'b');
    await manager.run((s) async {}, sessionId: 'c');
    expect(peak, 1);
    await manager.closeAll();
  });

  test('全部会话在用户控制中且达上限时新建报 sessionLimit', () async {
    final manager = BrowserSessionManager(
      factory: _FakeSession.new,
      maxSessions: 1,
    );
    await manager.run((s) async {}, sessionId: 'a');
    manager.userClaim('a');
    expect(
      () => manager.run((s) async {}, sessionId: 'b'),
      throwsA(
        isA<BrowserException>().having(
          (e) => e.kind,
          'kind',
          BrowserErrorKind.sessionLimit,
        ),
      ),
    );
    await manager.closeAll();
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

  test('空闲回收后重建的会话预约透明恢复上次 URL', () async {
    final all = <_FakeSession>[];
    final manager = BrowserSessionManager(
      factory: () {
        final s = _FakeSession();
        all.add(s);
        return s;
      },
      idleTimeout: const Duration(milliseconds: 50),
    );
    await manager.run((s) => s.open('https://example.com/a'));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(all.single.closed, isTrue);
    await manager.run((s) async {});
    expect(all, hasLength(2));
    expect(all[1].restoreScheduled, 'https://example.com/a');
    await manager.closeAll();
  });

  test('崩溃的会话在下次调用前主动重建并透明恢复', () async {
    final all = <_FakeSession>[];
    final manager = BrowserSessionManager(
      factory: () {
        final s = _FakeSession();
        all.add(s);
        return s;
      },
    );
    await manager.run((s) => s.open('https://example.com/x'));
    all.single.crashedFlag = true;
    _FakeSession? used;
    await manager.run((s) async => used = s as _FakeSession);
    expect(all, hasLength(2));
    expect(all.first.closed, isTrue);
    expect(identical(used, all[1]), isTrue);
    expect(all[1].restoreScheduled, 'https://example.com/x');
    await manager.closeAll();
  });

  test('闲置超过心跳阈值且探活失败的会话重建', () async {
    final all = <_FakeSession>[];
    final manager = BrowserSessionManager(
      factory: () {
        final s = _FakeSession();
        all.add(s);
        return s;
      },
      idleTimeout: const Duration(seconds: 30),
      heartbeatAfter: const Duration(milliseconds: 20),
    );
    await manager.run((s) => s.open('https://example.com/y'));
    all.single.responsive = false;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await manager.run((s) async {});
    expect(all, hasLength(2));
    expect(all.first.closed, isTrue);
    expect(all[1].restoreScheduled, 'https://example.com/y');
    await manager.closeAll();
  });

  test('心跳阈值内的会话不做探活', () async {
    final all = <_FakeSession>[];
    final manager = BrowserSessionManager(
      factory: () {
        final s = _FakeSession();
        all.add(s);
        return s;
      },
      heartbeatAfter: const Duration(seconds: 30),
    );
    await manager.run((s) => s.open('https://example.com/z'));
    all.single.responsive = false; // 阈值内不该被探测到。
    await manager.run((s) async {});
    expect(all, hasLength(1));
    expect(all.single.closed, isFalse);
    await manager.closeAll();
  });

  test('closeAll 后拒绝新调用', () async {
    final manager = BrowserSessionManager(factory: _FakeSession.new);
    await manager.run((s) async {});
    await manager.closeAll();
    expect(
      () => manager.run((s) async {}),
      throwsA(
        isA<BrowserException>().having(
          (e) => e.kind,
          'kind',
          BrowserErrorKind.sessionGone,
        ),
      ),
    );
  });
}
