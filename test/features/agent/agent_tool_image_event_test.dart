import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/data/datasources/local/agent_converters.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

void main() {
  test('ToolCallEvent 图片字段编解码往返', () {
    final event = ToolCallEvent(
      id: 'tc-1',
      seq: 1,
      at: DateTime.fromMillisecondsSinceEpoch(0),
      toolName: 'browser_snapshot',
      argSummary: 'example.com',
      state: AgentToolCallState.success,
      resultSummary: '已截图 · 768×1024',
      imagePath: '/data/agent_tool_images/tc-1.jpg',
      imageMimeType: 'image/jpeg',
    );
    final decoded = decodeAgentEvent(
      id: event.id,
      seq: event.seq,
      at: event.at,
      kind: agentEventKind(event),
      payloadJson: encodeAgentEventPayload(event),
    ) as ToolCallEvent;
    expect(decoded.imagePath, '/data/agent_tool_images/tc-1.jpg');
    expect(decoded.imageMimeType, 'image/jpeg');
  });

  test('无图片时 payload 不含图片键（旧数据前向兼容）', () {
    final event = ToolCallEvent(
      id: 'tc-2',
      seq: 2,
      at: DateTime.fromMillisecondsSinceEpoch(0),
      toolName: 'read_file',
      argSummary: 'a.dart',
      state: AgentToolCallState.success,
    );
    final payload = encodeAgentEventPayload(event);
    expect(payload, isNot(contains('imagePath')));
    final decoded = decodeAgentEvent(
      id: event.id,
      seq: event.seq,
      at: event.at,
      kind: agentEventKind(event),
      payloadJson: payload,
    ) as ToolCallEvent;
    expect(decoded.imagePath, isNull);
    expect(decoded.imageMimeType, isNull);
  });
}
