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

  final List<AgentEvent> events;

  Iterable<ToolCallEvent> get toolCalls => events.whereType<ToolCallEvent>();
}

/// 段头动词摘要：按段内占主导的工具类别给一句「在做什么」。
String segmentSummary(SegmentBlock block) {
  var read = 0, write = 0, exec = 0, other = 0;
  for (final e in block.toolCalls) {
    final name = e.toolName.toLowerCase();
    if (name.contains('terminal') || name.contains('execute')) {
      exec++;
    } else if (name.contains('write') ||
        name.contains('create') ||
        name.contains('edit') ||
        name.contains('diff') ||
        name.contains('replace') ||
        name.contains('insert') ||
        name.contains('delete') ||
        name.contains('rename') ||
        name.contains('move') ||
        name.contains('copy')) {
      write++;
    } else if (name.contains('read') ||
        name.contains('list') ||
        name.contains('search') ||
        name.contains('get') ||
        name.contains('fetch')) {
      read++;
    } else {
      other++;
    }
  }
  final max = [read, write, exec, other].reduce((a, b) => a > b ? a : b);
  if (max == 0) return '思考';
  if (max == exec) return '执行命令';
  if (max == write) return '修改文件';
  if (max == read) return '检索查看';
  return '调用工具';
}

/// 最新计划快照（顶部计划纪要条数据源）。
PlanUpdateEvent? latestPlan(List<AgentEvent> events) {
  PlanUpdateEvent? plan;
  for (final e in events) {
    if (e is PlanUpdateEvent) plan = e;
  }
  return plan;
}

/// 工作段折叠（UI 稿 §4.1）：连续的**已完结**（success/failure/denied）
/// 工具调用及夹在其间的已定稿思考，折叠成摘要块（工具 ≥3 条才折）；
/// 执行中/待审批的工具行与流式思考保持实况展开。
/// [collapseAll] 为 true 时（「折叠全部过程」）阈值降为 1，
/// 所有已完结工具/思考都收进段，只留叙述、用户消息等。
List<TimelineBlock> buildTimelineBlocks(
  List<AgentEvent> events, {
  bool collapseAll = false,
}) {
  final blocks = <TimelineBlock>[];
  var run = <AgentEvent>[];
  var runTools = 0;

  void flush() {
    final threshold = collapseAll ? 1 : 3;
    if (runTools >= threshold) {
      blocks.add(SegmentBlock(run));
    } else {
      blocks.addAll(run.map(SingleBlock.new));
    }
    run = [];
    runTools = 0;
  }

  for (final e in events) {
    final finishedTool =
        e is ToolCallEvent &&
        (e.state == AgentToolCallState.success ||
            e.state == AgentToolCallState.failure ||
            e.state == AgentToolCallState.denied);
    final finishedReasoning = e is ReasoningEvent && !e.streaming;
    if (finishedTool) {
      run.add(e);
      runTools++;
    } else if (finishedReasoning) {
      run.add(e);
    } else {
      flush();
      if (e is! PlanUpdateEvent) blocks.add(SingleBlock(e));
    }
  }
  flush();
  return blocks;
}
