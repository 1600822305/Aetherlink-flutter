import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_terminal_focus.dart';

void main() {
  group('terminalToolSessionRef', () {
    test('优先取结果里的 sessionId（默认会话也有）', () {
      expect(
        terminalToolSessionRef(
          argsDetail: '{"command":"ls","session":"build"}',
          resultDetail: '{"success":true,"data":{"sessionId":"s3-k3f"}}',
        ),
        's3-k3f',
      );
    });

    test('结果还没有（运行中）时取参数 session / session_id', () {
      expect(
        terminalToolSessionRef(argsDetail: '{"command":"ls","session":"b"}'),
        'b',
      );
      expect(
        terminalToolSessionRef(
          argsDetail: '{"action":"output","session_id":"s2-abc"}',
        ),
        's2-abc',
      );
    });

    test('都没有 / 参数非法时返回 null', () {
      expect(terminalToolSessionRef(argsDetail: '{"command":"ls"}'), isNull);
      expect(terminalToolSessionRef(argsDetail: 'not json'), isNull);
      expect(terminalToolSessionRef(), isNull);
      expect(
        terminalToolSessionRef(argsDetail: '{"session":"  "}'),
        isNull,
      );
    });
  });

  group('agentTerminalFocusProvider', () {
    test('request 写入、consume 只清掉同一条请求', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(agentTerminalFocusProvider.notifier);
      notifier.request('t1', sessionRef: 's1');
      final first = container.read(agentTerminalFocusProvider)!;
      expect(first.taskId, 't1');
      expect(first.sessionRef, 's1');
      expect(first.fresh, isTrue);

      notifier.request('t1', sessionRef: 's2');
      notifier.consume(first); // 旧请求：不应清掉新的
      expect(container.read(agentTerminalFocusProvider)?.sessionRef, 's2');

      notifier.consume(container.read(agentTerminalFocusProvider)!);
      expect(container.read(agentTerminalFocusProvider), isNull);
    });
  });
}
