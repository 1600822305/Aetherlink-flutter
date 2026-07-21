import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/timeline_blocks.dart';

void main() {
  final at = DateTime(2026, 1, 1);
  var seq = 0;

  ToolCallEvent tool(AgentToolCallState state) => ToolCallEvent(
        id: 'e${++seq}',
        seq: seq,
        at: at,
        toolName: 'read_file',
        argSummary: 'a.dart',
        state: state,
      );

  AssistantTextEvent text({bool streaming = false}) => AssistantTextEvent(
        id: 'e${++seq}',
        seq: seq,
        at: at,
        text: '结论',
        streaming: streaming,
      );

  test('正文收尾的段折叠为 SegmentBlock', () {
    final blocks = buildTimelineBlocks([
      tool(AgentToolCallState.success),
      tool(AgentToolCallState.success),
      text(),
    ], running: true);
    expect(blocks, hasLength(2));
    expect(blocks.first, isA<SegmentBlock>());
    expect((blocks.first as SegmentBlock).toolCalls, hasLength(2));
  });

  test('任务运行中、段未被正文收尾 → 保持平铺不折叠', () {
    final blocks = buildTimelineBlocks([
      tool(AgentToolCallState.success),
      tool(AgentToolCallState.success),
      tool(AgentToolCallState.running),
    ], running: true);
    expect(blocks.whereType<SegmentBlock>(), isEmpty);
    expect(blocks, hasLength(3));
  });

  test('流式正文不收尾段；定稿正文才折叠', () {
    final streamingBlocks = buildTimelineBlocks([
      tool(AgentToolCallState.success),
      text(streaming: true),
    ], running: true);
    expect(streamingBlocks.whereType<SegmentBlock>(), isEmpty);

    final finalBlocks = buildTimelineBlocks([
      tool(AgentToolCallState.success),
      text(),
    ], running: true);
    expect(finalBlocks.first, isA<SegmentBlock>());
  });

  test('任务已结束 → 末尾未收尾的段也折叠', () {
    final blocks = buildTimelineBlocks([
      tool(AgentToolCallState.success),
      tool(AgentToolCallState.failure),
    ]);
    expect(blocks.single, isA<SegmentBlock>());
  });

  test('collapse 关闭时全部平铺', () {
    final blocks = buildTimelineBlocks([
      tool(AgentToolCallState.success),
      text(),
    ], collapse: false);
    expect(blocks.whereType<SegmentBlock>(), isEmpty);
  });
}
