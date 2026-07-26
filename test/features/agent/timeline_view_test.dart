import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/timeline_blocks.dart';
import 'package:aetherlink_flutter/features/agent/application/timeline_view.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/working_indicator_tile.dart';

void main() {
  final at = DateTime(2026, 1, 1);
  var seq = 0;

  ToolCallEvent tool(AgentToolCallState state, {String? id}) => ToolCallEvent(
        id: id ?? 'e${++seq}',
        seq: seq,
        at: at,
        toolName: 'read_file',
        argSummary: 'a.dart',
        state: state,
      );

  AssistantTextEvent text({bool streaming = false, String? id}) =>
      AssistantTextEvent(
        id: id ?? 'e${++seq}',
        seq: seq,
        at: at,
        text: '结论',
        streaming: streaming,
      );

  ReasoningEvent reasoning({bool streaming = false}) => ReasoningEvent(
        id: 'e${++seq}',
        seq: seq,
        at: at,
        text: '思考',
        streaming: streaming,
      );

  UserMessageEvent userMsg({String? replyTo}) => UserMessageEvent(
        id: 'e${++seq}',
        seq: seq,
        at: at,
        text: '指令',
        replyToQuestionId: replyTo,
      );

  UserQuestionEvent question({String? id}) => UserQuestionEvent(
        id: id ?? 'e${++seq}',
        seq: seq,
        at: at,
        question: '选哪个？',
      );

  PlanUpdateEvent plan() => PlanUpdateEvent(
        id: 'e${++seq}',
        seq: seq,
        at: at,
        items: const [
          AgentPlanItem(
            content: '第一步',
            status: AgentPlanItemStatus.inProgress,
          ),
        ],
      );

  CompactionEvent compaction({bool revoked = false, String? id}) =>
      CompactionEvent(
        id: id ?? 'e${++seq}',
        seq: seq,
        at: at,
        coveredCount: 3,
        summary: '摘要',
        revoked: revoked,
      );

  /// 块结构等价断言（与全量 buildTimelineBlocks 对拍）。
  void expectSameBlocks(List<TimelineBlock> a, List<TimelineBlock> b) {
    expect(a.length, b.length);
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      expect(x.runtimeType, y.runtimeType);
      if (x is SingleBlock && y is SingleBlock) {
        expect(identical(x.event, y.event), isTrue);
      } else if (x is SegmentBlock && y is SegmentBlock) {
        expect(x.events.length, y.events.length);
        for (var j = 0; j < x.events.length; j++) {
          expect(identical(x.events[j], y.events[j]), isTrue);
        }
      }
    }
  }

  List<AgentEvent> sampleEvents() => [
        userMsg(),
        plan(),
        reasoning(),
        tool(AgentToolCallState.success),
        tool(AgentToolCallState.success),
        text(),
        question(),
        userMsg(replyTo: 'e7'),
        compaction(),
        tool(AgentToolCallState.success),
        tool(AgentToolCallState.failure),
        text(streaming: true),
      ];

  test('与全量 buildTimelineBlocks 逐前缀对拍等价', () {
    for (final collapse in [true, false]) {
      for (final running in [true, false]) {
        seq = 0;
        final all = sampleEvents();
        final fold = AgentTimelineFold();
        for (var n = 0; n <= all.length; n++) {
          final events = all.sublist(0, n);
          final view = fold.fold(
            events,
            collapse: collapse,
            running: running,
          );
          expectSameBlocks(
            view.blocks,
            buildTimelineBlocks(events, collapse: collapse, running: running),
          );
          expect(
            view.latestPlan,
            latestPlan(events),
            reason: 'n=$n collapse=$collapse',
          );
          expect(view.hasLiveEvent, !needsWorkingIndicator(events));
          expect(
            view.pendingQuestion?.id,
            latestPendingUserQuestion(events)?.id,
          );
        }
      }
    }
  });

  test('同一列表实例短路返回同一视图实例', () {
    seq = 0;
    final events = sampleEvents();
    final fold = AgentTimelineFold();
    final v1 = fold.fold(events, collapse: true, running: true);
    final v2 = fold.fold(events, collapse: true, running: true);
    expect(identical(v1, v2), isTrue);
  });

  test('追加事件后已收尾前缀块实例复用', () {
    seq = 0;
    final head = [
      tool(AgentToolCallState.success),
      text(),
    ];
    final fold = AgentTimelineFold();
    final v1 = fold.fold(head, collapse: true, running: true);
    final v2 = fold.fold(
      [...head, text(streaming: true)],
      collapse: true,
      running: true,
    );
    expect(identical(v1.blocks[0], v2.blocks[0]), isTrue);
    expect(identical(v1.blocks[1], v2.blocks[1]), isTrue);
  });

  test('尾部实况事件原地更新（同 id 新实例）推导正确', () {
    seq = 0;
    final head = [text(), tool(AgentToolCallState.running, id: 'live')];
    final fold = AgentTimelineFold();
    final v1 = fold.fold(head, collapse: true, running: true);
    expect(v1.hasLiveEvent, isTrue);

    final done = [
      head[0],
      tool(AgentToolCallState.success, id: 'live'),
      text(id: 'tail'),
    ];
    final v2 = fold.fold(done, collapse: true, running: true);
    expect(v2.hasLiveEvent, isFalse);
    expectSameBlocks(
      v2.blocks,
      buildTimelineBlocks(done, running: true),
    );
  });

  test('前缀事件原地变更（压缩撤销）触发整体重折且结果正确', () {
    seq = 0;
    final c1 = compaction(id: 'c1');
    final c2 = compaction(id: 'c2');
    final tail = text();
    final fold = AgentTimelineFold();
    final v1 = fold.fold([c1, c2, tail], collapse: true, running: false);
    expect(v1.latestActiveCompactionId, 'c2');

    final c2Revoked = compaction(id: 'c2', revoked: true);
    final v2 =
        fold.fold([c1, c2Revoked, tail], collapse: true, running: false);
    expect(v2.latestActiveCompactionId, 'c1');
  });

  test('事件列表删减（回滚）整体重折', () {
    seq = 0;
    final all = sampleEvents();
    final fold = AgentTimelineFold();
    fold.fold(all, collapse: true, running: true);
    final shrunk = all.sublist(0, 4);
    final view = fold.fold(shrunk, collapse: true, running: false);
    expectSameBlocks(view.blocks, buildTimelineBlocks(shrunk));
    expect(view.userInputCount, 1);
  });

  test('collapse 切换后重折为对应结构', () {
    seq = 0;
    final events = [
      tool(AgentToolCallState.success),
      tool(AgentToolCallState.success),
      text(),
    ];
    final fold = AgentTimelineFold();
    final collapsed = fold.fold(events, collapse: true, running: true);
    expect(collapsed.blocks.first, isA<SegmentBlock>());
    final flat = fold.fold(events, collapse: false, running: true);
    expect(flat.blocks.whereType<SegmentBlock>(), isEmpty);
  });

  test('提问/回答推导：pendingQuestion 与 answersByQuestionId', () {
    seq = 0;
    final q1 = question(id: 'q1');
    final fold = AgentTimelineFold();
    final v1 = fold.fold([userMsg(), q1], collapse: true, running: true);
    expect(v1.pendingQuestion?.id, 'q1');
    expect(v1.userInputCount, 2);

    final answer = userMsg(replyTo: 'q1');
    final v2 =
        fold.fold([userMsg(), q1, answer], collapse: true, running: true);
    expect(v2.pendingQuestion, isNull);
    expect(identical(v2.answersByQuestionId['q1'], answer), isTrue);
    expect(v2.userInputCount, 3);
  });
}
