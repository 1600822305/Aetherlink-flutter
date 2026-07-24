import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/services/streaming_keepalive_service.dart';

class _FakeOps implements KeepAlivePlatformOps {
  bool running = false;
  bool startShouldFail = false;
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Future<bool> isRunningService() async => running;

  @override
  Future<bool> ensureNotificationPermission() async => true;

  @override
  Future<bool> startService({
    required String title,
    required String text,
  }) async {
    startCalls++;
    if (startShouldFail) return false;
    running = true;
    return true;
  }

  @override
  Future<void> stopService() async {
    stopCalls++;
    running = false;
  }
}

Future<void> _sendLifecycle(WidgetTester tester, String state) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.lifecycle.name,
    SystemChannels.lifecycle.codec.encodeMessage(state),
    (_) {},
  );
  await tester.pump();
}

void main() {
  late _FakeOps ops;

  setUp(() {
    StreamingKeepAliveService.debugReset();
    ops = _FakeOps();
    StreamingKeepAliveService.debugOps = ops;
    StreamingKeepAliveService.debugSupportedOverride = true;
  });

  tearDown(StreamingKeepAliveService.debugReset);

  testWidgets('acquire 启动服务，全部 release 后停服务', (tester) async {
    await StreamingKeepAliveService.acquire('agent', title: 't', text: 'x');
    expect(ops.running, isTrue);

    await StreamingKeepAliveService.acquire('chat', title: 't2', text: 'x2');
    expect(ops.startCalls, 1);

    await StreamingKeepAliveService.release('agent');
    expect(ops.running, isTrue);

    await StreamingKeepAliveService.release('chat');
    expect(ops.running, isFalse);
    expect(ops.stopCalls, 1);
  });

  testWidgets('启动失败不再静默：回前台且持有方还在时补启', (tester) async {
    ops.startShouldFail = true;
    await StreamingKeepAliveService.acquire('agent', title: 't', text: 'x');
    expect(ops.running, isFalse);
    expect(ops.startCalls, 1);

    ops.startShouldFail = false;
    await _sendLifecycle(tester, 'AppLifecycleState.inactive');
    await _sendLifecycle(tester, 'AppLifecycleState.resumed');
    await tester.runAsync(() => StreamingKeepAliveService.ensureService());

    expect(ops.startCalls, greaterThanOrEqualTo(2));
    expect(ops.running, isTrue);
  });

  testWidgets('服务被系统中途停掉：回前台补启', (tester) async {
    await StreamingKeepAliveService.acquire('agent', title: 't', text: 'x');
    expect(ops.running, isTrue);

    ops.running = false; // 模拟系统杀掉前台服务
    await _sendLifecycle(tester, 'AppLifecycleState.paused');
    await _sendLifecycle(tester, 'AppLifecycleState.resumed');
    await tester.runAsync(() => StreamingKeepAliveService.ensureService());

    expect(ops.running, isTrue);
  });

  testWidgets('持有方已全部释放时回前台不重启服务', (tester) async {
    await StreamingKeepAliveService.acquire('agent', title: 't', text: 'x');
    await StreamingKeepAliveService.release('agent');
    expect(ops.running, isFalse);

    await tester.runAsync(() => StreamingKeepAliveService.ensureService());
    expect(ops.running, isFalse);
    expect(ops.startCalls, 1);
  });
}
