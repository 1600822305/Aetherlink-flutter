import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_compaction.dart';
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
        commits: const {
          '/ws/app': 'abc123def456',
          '/ws/lib': 'fed654cba321',
        },
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
      expect(checkpoint.commits, {
        '/ws/app': 'abc123def456',
        '/ws/lib': 'fed654cba321',
      });
      expect(checkpoint.label, '修复登录问题');
    });

    test('旧单仓库 payload（commit 字符串）解码为空键映射', () {
      final decoded = decodeAgentEvent(
        id: 'ck-legacy',
        seq: 1,
        at: at,
        kind: 'checkpoint',
        payloadJson: jsonEncode({'commit': 'abc123', 'label': '旧数据'}),
      );
      final checkpoint = decoded as CheckpointEvent;
      expect(checkpoint.commits, {'': 'abc123'});
      expect(checkpoint.label, '旧数据');
    });
  });

  group('检查点与上下文', () {
    test('foldCompactedEvents 跳过检查点（不进模型上下文）', () {
      final events = <AgentEvent>[
        CheckpointEvent(id: 'ck-1', seq: 1, at: at, commits: const {'': 'abc'}),
        UserMessageEvent(id: 'um-1', seq: 2, at: at, text: '你好'),
      ];
      final folded = foldCompactedEvents(events);
      expect(folded, hasLength(1));
      expect(folded.single, isA<UserMessageEvent>());
    });

    test('contextCharsOf 对检查点计 0', () {
      final event = CheckpointEvent(
        id: 'ck-1',
        seq: 1,
        at: at,
        commits: const {'': 'abc'},
      );
      expect(contextCharsOf(event), 0);
    });
  });
}
