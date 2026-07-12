/// 时间线分块：把事件流切成「单条事件 / 折叠工作段」两种块，
/// 纯函数，UI 与折叠规则解耦（改折叠策略只动这里）。
library;

import 'dart:convert';

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

/// 段内代码行变更统计（Devin 风格段头 +N −N）：从写类工具的
/// 完整参数里估算——content/replace 行数计增、search 行数计减，
/// diff 文本按 +/− 前缀行计。仅统计成功的调用。
({int added, int removed}) segmentLineStats(SegmentBlock block) {
  var added = 0, removed = 0;
  int lines(String s) => s.isEmpty ? 0 : '\n'.allMatches(s).length + 1;

  void countArgs(Map<String, dynamic> args) {
    final content = args['content'];
    if (content is String) added += lines(content);
    final search = args['search'];
    if (search is String) removed += lines(search);
    final replace = args['replace'];
    if (replace is String) added += lines(replace);
    final diff = args['diff'];
    if (diff is String) {
      for (final line in const LineSplitter().convert(diff)) {
        if (line.startsWith('+') && !line.startsWith('+++')) added++;
        if (line.startsWith('-') && !line.startsWith('---')) removed++;
      }
    }
    final edits = args['edits'];
    if (edits is List) {
      for (final e in edits) {
        if (e is Map<String, dynamic>) countArgs(e);
      }
    }
  }

  for (final e in block.toolCalls) {
    if (e.state != AgentToolCallState.success) continue;
    final raw = e.argsDetail;
    if (raw == null || raw.isEmpty) continue;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) countArgs(decoded);
    } on FormatException {
      // 非 JSON 参数不参与统计。
    }
  }
  return (added: added, removed: removed);
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
/// 工具调用及夹在其间的已定稿思考，折叠成摘要块（默认折叠，
/// 用户点段头展开）；执行中/待审批的工具行与流式思考保持实况展开。
/// [collapse] 关闭（侧边栏设置「自动折叠工作段」）时不折叠，
/// 所有事件平铺展示。
List<TimelineBlock> buildTimelineBlocks(
  List<AgentEvent> events, {
  bool collapse = true,
}) {
  final blocks = <TimelineBlock>[];
  var run = <AgentEvent>[];
  var runTools = 0;

  void flush() {
    if (collapse && runTools >= 1) {
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
