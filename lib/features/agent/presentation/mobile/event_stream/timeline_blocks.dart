/// 时间线分块：把事件流切成「单条事件 / 折叠工作段」两种块，
/// 纯函数，UI 与折叠规则解耦（改折叠策略只动这里）。
library;

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

sealed class TimelineBlock {
  const TimelineBlock();
}

class SingleBlock extends TimelineBlock {
  const SingleBlock(this.event);

  final AgentEvent event;
}

class SegmentBlock extends TimelineBlock {
  const SegmentBlock(this.events);

  final List<ToolCallEvent> events;
}

/// 最新计划快照（顶部计划纪要条数据源）。
PlanUpdateEvent? latestPlan(List<AgentEvent> events) {
  PlanUpdateEvent? plan;
  for (final e in events) {
    if (e is PlanUpdateEvent) plan = e;
  }
  return plan;
}

/// 工作段折叠（UI 稿 §4.1）：连续 ≥3 条**已完结**（success/failure/denied）
/// 的工具调用折叠成摘要块；执行中/待审批的工具行保持实况展开。
List<TimelineBlock> buildTimelineBlocks(List<AgentEvent> events) {
  final blocks = <TimelineBlock>[];
  var run = <ToolCallEvent>[];

  void flush() {
    if (run.length >= 3) {
      blocks.add(SegmentBlock(run));
    } else {
      blocks.addAll(run.map(SingleBlock.new));
    }
    run = [];
  }

  for (final e in events) {
    final finishedTool =
        e is ToolCallEvent &&
        (e.state == AgentToolCallState.success ||
            e.state == AgentToolCallState.failure ||
            e.state == AgentToolCallState.denied);
    if (finishedTool) {
      run.add(e);
    } else {
      flush();
      if (e is! PlanUpdateEvent) blocks.add(SingleBlock(e));
    }
  }
  flush();
  return blocks;
}
