import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_browser/aetherlink_browser.dart';

void main() {
  test('onLoadStop 触发即完成', () async {
    const poller = PageLoadPoller(
      timeout: Duration(seconds: 2),
      pollInterval: Duration(milliseconds: 10),
    );
    final loadStop = Completer<void>();
    Timer(const Duration(milliseconds: 30), loadStop.complete);
    final ok = await poller.wait(
      loadStop: loadStop.future,
      probe: () async => false,
    );
    expect(ok, isTrue);
  });

  test('readyState 就绪即完成（loadStop 未触发）', () async {
    const poller = PageLoadPoller(
      timeout: Duration(seconds: 2),
      pollInterval: Duration(milliseconds: 10),
    );
    var polls = 0;
    final ok = await poller.wait(
      loadStop: Completer<void>().future,
      probe: () async => ++polls >= 3,
    );
    expect(ok, isTrue);
    expect(polls, 3);
  });

  test('超时返回 false 不抛异常', () async {
    const poller = PageLoadPoller(
      timeout: Duration(milliseconds: 80),
      pollInterval: Duration(milliseconds: 10),
    );
    final ok = await poller.wait(
      loadStop: Completer<void>().future,
      probe: () async => false,
    );
    expect(ok, isFalse);
  });

  test('probe 抛异常不中断轮询', () async {
    const poller = PageLoadPoller(
      timeout: Duration(seconds: 2),
      pollInterval: Duration(milliseconds: 10),
    );
    var polls = 0;
    final ok = await poller.wait(
      loadStop: Completer<void>().future,
      probe: () async {
        polls++;
        if (polls < 3) throw StateError('导航中');
        return true;
      },
    );
    expect(ok, isTrue);
  });
}
