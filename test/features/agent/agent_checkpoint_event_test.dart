import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_compaction.dart';
import 'package:aetherlink_flutter/features/agent/data/datasources/local/agent_converters.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

void main() {
  final at = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  group('CheckpointEvent 编解码', () {
    test('kind 为 checkpoint，payload 往返无损', () {
      final event = CheckpointEvent(
        id: 'ck-1',
        seq: 3,
        at: at,
        commit: 'abc123def456',
        label: '修复登录问题',
      );
      expect(agentEventKind(event), 'checkpoint');
      final decoded = decodeAgentEvent(
        id: event.id,
        seq: event.seq,
        at: event.at,
        kind: agentEventKind(event),
        payloadJson: encodeAgentEventPayload(event),
      );
      expect(decoded, isA<CheckpointEvent>());
      final checkpoint = decoded as CheckpointEvent;
      expect(checkpoint.commit, 'abc123def456');
      expect(checkpoint.label, '修复登录问题');
    });
  });

  group('检查点与上下文', () {
    test('foldCompactedEvents 跳过检查点（不进模型上下文）', () {
      final events = <AgentEvent>[
        CheckpointEvent(id: 'ck-1', seq: 1, at: at, commit: 'abc'),
        UserMessageEvent(id: 'um-1', seq: 2, at: at, text: '你好'),
      ];
      final folded = foldCompactedEvents(events);
      expect(folded, hasLength(1));
      expect(folded.single, isA<UserMessageEvent>());
    });

    test('contextCharsOf 对检查点计 0', () {
      final event =
          CheckpointEvent(id: 'ck-1', seq: 1, at: at, commit: 'abc');
      expect(contextCharsOf(event), 0);
    });
  });
}
