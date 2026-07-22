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

/// 单条工具的行统计缓存（按事件 id）：成功后参数不再变，避免每次
/// 重建都对全量 argsJson 重复 jsonDecode。
final Map<String, ({int added, int removed})> _lineStatsCache = {};

({int added, int removed}) _eventLineStats(String raw) {
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

  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) countArgs(decoded);
  } on FormatException {
    // 非 JSON 参数不参与统计。
  }
  return (added: added, removed: removed);
}

/// 段内代码行变更统计（Devin 风格段头 +N −N）：从写类工具的
/// 完整参数里估算——content/replace 行数计增、search 行数计减，
/// diff 文本按 +/− 前缀行计。仅统计成功的调用。
({int added, int removed}) segmentLineStats(SegmentBlock block) {
  if (_lineStatsCache.length > 4096) _lineStatsCache.clear();
  var added = 0, removed = 0;
  for (final e in block.toolCalls) {
    if (e.state != AgentToolCallState.success) continue;
    final raw = e.argsDetail;
    if (raw == null || raw.isEmpty) continue;
    final stats = _lineStatsCache[e.id] ??= _eventLineStats(raw);
    added += stats.added;
    removed += stats.removed;
  }
  return (added: added, removed: removed);
}

/// 最新计划快照（顶部计划纪要条数据源）；空快照表示计划已
/// 收尾清空，返 null 隐藏面板。
PlanUpdateEvent? latestPlan(List<AgentEvent> events) {
  PlanUpdateEvent? plan;
  for (final e in events) {
    if (e is PlanUpdateEvent) plan = e;
  }
  if (plan == null || plan.items.isEmpty) return null;
  return plan;
}

/// 工作段折叠（UI 稿 §4.1，段边界对标 Claude Code
/// collapseReadSearchGroups）：连续的**已完结**（success/failure/denied）
/// 工具调用及夹在其间的已定稿思考构成一个工作段；段只在被正文
/// 「收尾」后才折叠——助手定稿正文、用户消息或状态变化出现时段
/// 结束并折叠成摘要块。仍在推进中的段（后面只是执行中的工具/
/// 流式文本，或列表末尾且 [running] 为 true）保持实况平铺，
/// 避免刚跑完的工具在任务还没说结论前就被收起。
/// [collapse] 关闭（侧边栏设置「自动折叠工作段」）时不折叠，
/// 所有事件平铺展示。
List<TimelineBlock> buildTimelineBlocks(
  List<AgentEvent> events, {
  bool collapse = true,
  bool running = false,
}) {
  final blocks = <TimelineBlock>[];
  var run = <AgentEvent>[];
  var runTools = 0;

  void flush({required bool closed}) {
    if (collapse && closed && runTools >= 1) {
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
    } else if (finishedReasoning || e is PlanUpdateEvent) {
      // 计划更新与思考同款：随段内联展示，不打断折叠。
      run.add(e);
    } else {
      // 正文/用户消息/状态变化收尾段 → 折叠；执行中工具、流式
      // 文本等实况事件只是暂断，段保持展开。
      final closes = (e is AssistantTextEvent && !e.streaming) ||
          e is UserMessageEvent ||
          e is StatusChangeEvent;
      flush(closed: closes);
      blocks.add(SingleBlock(e));
    }
  }
  // 列表末尾：任务仍在跑说明段还没收尾，保持实况；已结束则折叠。
  flush(closed: !running);
  return blocks;
}
