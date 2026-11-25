import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/domain/mobile_background_settings.dart';
import 'package:aetherlink_flutter/shared/services/mobile_background.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.mobile_background');
  final calls = <MethodCall>[];
  late MobileBackgroundCoordinator coordinator;

  setUp(() async {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'sync' || call.method == 'getStatus'
              ? <String, dynamic>{}
              : null;
        });
    coordinator = MobileBackgroundCoordinator(
      channel: channel,
      platform: TargetPlatform.android,
    );
    await coordinator.configure(const MobileBackgroundSettings());
  });

  tearDown(() async {
    await coordinator.flush();
    coordinator.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<Map<dynamic, dynamic>> snapshots() => calls
      .where((c) => c.method == 'sync')
      .map((c) => c.arguments as Map<dynamic, dynamic>)
      .toList();

  test('chat 与 agent 任务共用一份快照，全部结束后任务列表清空', () async {
    await coordinator.start(
      id: 'chat:t1',
      conversationId: 'chat:t1',
      title: 'chat',
      cancel: () async {},
    );
    await coordinator.start(
      id: 'agent:a1',
      conversationId: 'agent:a1',
      title: 'agent',
      cancel: () async {},
    );
    expect((snapshots().last['tasks'] as List), hasLength(2));

    await coordinator.finish('chat:t1', BackgroundTaskOutcome.completed);
    expect((snapshots().last['tasks'] as List), hasLength(1));

    await coordinator.finish('agent:a1', BackgroundTaskOutcome.completed);
    await coordinator.flush();
    expect(snapshots().last['tasks'] as List, isEmpty);
    expect(
      (snapshots().last['terminal'] as Map)['outcome'],
      BackgroundTaskOutcome.completed.name,
    );
  });

  test('结束后的迟到 update 不会复活任务', () async {
    await coordinator.start(
      id: 'chat:t1',
      conversationId: 'chat:t1',
      title: 'chat',
      cancel: () async {},
    );
    await coordinator.finish('chat:t1', BackgroundTaskOutcome.completed);
    coordinator.update('chat:t1', phase: BackgroundTaskPhase.generating);
    await coordinator.flush();
    expect(coordinator.activeTaskIds, isEmpty);
    expect(snapshots().last['tasks'] as List, isEmpty);
  });

  test('原生 cancelTasks 回调取消对应任务', () async {
    var cancelled = false;
    await coordinator.start(
      id: 'agent:a1',
      conversationId: 'agent:a1',
      title: 'agent',
      cancel: () async => cancelled = true,
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('cancelTasks', {
              'ids': ['agent:a1'],
            }),
          ),
          (_) {},
        );
    await pumpEventQueue();
    expect(cancelled, isTrue);
  });

  test('通知深链在 opener 就绪前暂存，就绪后投递', () async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('openConversation', 'chat:t1'),
          ),
          (_) {},
        );
    String? opened;
    coordinator.setConversationOpener((id) => opened = id);
    expect(opened, 'chat:t1');
  });
}
