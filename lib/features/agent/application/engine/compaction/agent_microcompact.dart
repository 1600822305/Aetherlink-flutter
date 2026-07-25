/// microcompact（压缩升级计划 ①，对标 Claude Code microCompact）：
/// 不调 LLM 的轻量降压——把较旧的可重取工具输出在「进模型上下文的
/// 视图」里替换成占位符。纯函数、无状态：引擎（字符量核算）与重放侧
/// （消息构建）对同一份折叠条目得到一致视图，与 foldCompactedEvents
/// 同款共享模式；事件流本体永不改写。
library;

import 'dart:math';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_compaction.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_compaction_trigger.dart';

/// 被清除的旧工具输出在上下文里的占位文本。
const String kMicroCompactClearedPlaceholder = '[旧工具输出已清除]';

/// 同参数重复调用被去重的旧输出在上下文里的占位文本。
const String kDedupedRepeatedReadPlaceholder = '[重复调用，输出已由后面同参数调用的最新结果取代]';

/// 同参数重复读去重（对标 CC 缓存编辑里的去重一招）：同一个
/// 可重取工具（[kMicroCompactableTools]）以同一份参数被调用多次
/// （agent 反复读同一文件是上下文膨胀头号来源）时，视图里只保留
/// 最后一次的输出，更旧的替换为占位符。无需阈值——旧重复输出对
/// 模型无增量信息。确定性纯函数，事件流本体永不改写；未命中时
/// 原样返回同一列表实例。
List<AgentEvent> dedupeRepeatedReads(List<AgentEvent> entries) {
  final seen = <String>{};
  List<AgentEvent>? result;
  for (var i = entries.length - 1; i >= 0; i--) {
    final event = entries[i];
    if (event is! ToolCallEvent) continue;
    if (!kMicroCompactableTools.contains(event.toolName)) continue;
    final detail = event.resultDetail;
    if (detail == null) continue;
    final key =
        '${event.toolName}\u0000${event.argsDetail ?? event.argSummary}';
    if (seen.add(key)) continue;
    if (detail.length <= kDedupedRepeatedReadPlaceholder.length) continue;
    result ??= List.of(entries);
    result[i] = _withClearedResult(
      event,
      placeholder: kDedupedRepeatedReadPlaceholder,
    );
  }
  return result ?? entries;
}

/// 可被 microcompact 清除输出的工具（对标 CC COMPACTABLE_TOOLS）：
/// 只清「可重取」的输出——终端 / 文件读 / 搜索 / 网络抓取 / 知识库
/// 检索类。CC 的白名单连 edit / write 也清；本项目刻意更保守：
/// 文件编辑的 diff 是语义结果（非可重取的现场输出），不清。
const Set<String> kMicroCompactableTools = {
  'terminal_execute',
  'terminal_session',
  'read_file',
  'list_files',
  'search_files',
  'get_file_info',
  'get_diagnostics',
  'fetch',
  'web_search',
  'searxng_search',
  'searxng_read_url',
  'metaso_search',
  'metaso_reader',
  'kb_search',
  'kb_read',
  // 内置浏览器（浏览器设计稿 §20.3）：网页内容可重取，同 fetch。
  // browser_snapshot 的文本结果很短且截图淘汰独立处理，不进白名单。
  'browser_open',
  'browser_read',
  'browser_snapshot_dom',
};

/// microcompact 触发阈值（字符，与 compaction 同款粗代理）：低于
/// LLM 压缩阈值（120k），构成「先 micro 后 LLM」的两级降压。引擎与
/// 重放侧都用本常量，保证两侧视图一致。
const int kMicroCompactTriggerChars = 80000;

/// 单条工具输出短于该字符数时不清（清了省不了多少，反而丢上下文）。
const int kMicroCompactMinClearChars = 2000;

/// 视图内最近保留的工具调用条数：最新的 N 条工具输出永不清除
/// （近期结果对模型最关键，对标 CC 的近期保护窗口）。
const int kMicroCompactKeepRecentToolCalls = 5;

/// 对折叠后的条目序列做 microcompact：总字符量超 [triggerChars] 时，
/// 从最旧开始把可清除工具（[kMicroCompactableTools]，且输出 ≥
/// [minClearChars]）的 resultDetail 替换为占位符，直到总量降到
/// [triggerChars] 以内或触达近期保护窗口（最近 [keepRecentToolCalls]
/// 条工具调用不动）。确定性纯函数：同一输入必得同一输出，引擎与
/// 重放侧无需同步状态。未触发时原样返回同一列表实例（零开销）。
List<AgentEvent> microCompactEntries(
  List<AgentEvent> entries, {
  required int triggerChars,
  int keepRecentToolCalls = kMicroCompactKeepRecentToolCalls,
  int minClearChars = kMicroCompactMinClearChars,
}) {
  var total = totalContextChars(entries);
  if (total <= triggerChars) return entries;

  // 近期保护窗口的起点：倒数第 keepRecentToolCalls 条工具调用的下标。
  var protectedFrom = entries.length;
  var seen = 0;
  for (var i = entries.length - 1; i >= 0; i--) {
    if (entries[i] is! ToolCallEvent) continue;
    seen++;
    protectedFrom = i;
    if (seen >= keepRecentToolCalls) break;
  }

  List<AgentEvent>? result;
  for (var i = 0; i < protectedFrom && total > triggerChars; i++) {
    final event = entries[i];
    if (event is! ToolCallEvent) continue;
    if (!kMicroCompactableTools.contains(event.toolName)) continue;
    final detail = event.resultDetail;
    if (detail == null || detail.length < minClearChars) continue;
    result ??= List.of(entries);
    result[i] = _withClearedResult(event);
    total -= detail.length - kMicroCompactClearedPlaceholder.length;
  }
  return result ?? entries;
}

// ── 工具结果聚合预算（对标 CC tool result budget）──

/// 超出总预算被摘录的工具结果里的省略标记文本（头尾之间）。
const String kToolResultBudgetStub = '[中间内容已省略：超出上下文工具结果总预算，需要完整内容可重新调用工具获取]';

/// 超预算摘录保留的头部 / 尾部字符数（对标 CC snip 思路：整条
/// 省略会让模型完全失忆，留头尾信息损失小得多）。
const int kToolResultExcerptHeadChars = 800;
const int kToolResultExcerptTailChars = 800;

/// 全部工具结果（resultDetail）在上下文视图里的总字符预算。
/// 单条已有 8000 字符截断落盘，但并发读取后一轮可产出十条以上，
/// 总量仍可能塞爆上下文；本预算在 microcompact 之后作为硬上限兜底。
const int kToolResultBudgetChars = 60000;

/// 工具结果总预算裁剪：所有 ToolCallEvent 的 resultDetail 总字符量超
/// [budgetChars] 时，从最旧开始把结果摘录为头尾片段 + 省略标记
/// （不限工具白名单，但最近 [keepRecentToolCalls] 条不动），直到降到
/// 预算内。与
/// [microCompactEntries] 同款确定性纯函数：事件流本体永不改写，
/// 引擎与重放侧共用同一视图。应在 microcompact 之后调用：先清
/// 可重取的旧输出，仍超预算才兜底省略其余最旧结果。
List<AgentEvent> applyToolResultBudget(
  List<AgentEvent> entries, {
  int budgetChars = kToolResultBudgetChars,
  int keepRecentToolCalls = kMicroCompactKeepRecentToolCalls,
}) {
  var total = 0;
  for (final event in entries) {
    if (event is ToolCallEvent) total += event.resultDetail?.length ?? 0;
  }
  if (total <= budgetChars) return entries;

  var protectedFrom = entries.length;
  var seen = 0;
  for (var i = entries.length - 1; i >= 0; i--) {
    if (entries[i] is! ToolCallEvent) continue;
    seen++;
    protectedFrom = i;
    if (seen >= keepRecentToolCalls) break;
  }

  List<AgentEvent>? result;
  for (var i = 0; i < protectedFrom && total > budgetChars; i++) {
    final event = entries[i];
    if (event is! ToolCallEvent) continue;
    final detail = event.resultDetail;
    if (detail == null || detail.length <= _kExcerptMinChars) continue;
    final excerpt = _excerptDetail(detail);
    result ??= List.of(entries);
    result[i] = _withClearedResult(event, placeholder: excerpt);
    total -= detail.length - excerpt.length;
  }
  return result ?? entries;
}

/// 短于此长度的结果不摘录（摘录后反而不省字符）。
const int _kExcerptMinChars =
    kToolResultExcerptHeadChars + kToolResultExcerptTailChars + 200;

String _excerptDetail(String detail) =>
    '${detail.substring(0, kToolResultExcerptHeadChars)}\n'
    '$kToolResultBudgetStub\n'
    '${detail.substring(detail.length - kToolResultExcerptTailChars)}';

// ── 统一降压流水线（引擎 / 重放 / 压缩协调 / 上下文明细共用入口）──

/// microcompact 的 token 触发比例：LLM 压缩在 0.92 才触发，micro
/// 应早得多（字符档位 80k vs 120k ≈ 两三开，换算≈ 0.92 × 2/3）。
const double kMicroCompactTriggerRatio = 0.6;

/// microcompact 触发阈值 token 化（与 compaction 的 token 判定同源）：
/// 有 API usage 的真实上下文 token 与模型窗口时，真实占用超过
/// 「micro 比例 × 有效窗口」就把字符阈值按超出比例等比收紧，
/// 让折叠量跟真实占用对齐（中文/代码 token 密度高，字符估算常常
/// 偏低致折叠过晚）。只收紧不放宽：拿不到 usage 或未超 token
/// 阈值时维持字符档兜底，超限 drain 降档等现有语义不变。
int effectiveMicroCompactTriggerChars({
  required int contextTokens,
  required int contextLimitTokens,
  required int estimatedChars,
  required int fallbackTriggerChars,
}) {
  if (contextTokens <= 0 || contextLimitTokens <= 0) {
    return fallbackTriggerChars;
  }
  final triggerTokens =
      (effectiveContextWindowTokens(contextLimitTokens) *
              kMicroCompactTriggerRatio)
          .floor();
  if (triggerTokens <= 0 || contextTokens <= triggerTokens) {
    return fallbackTriggerChars;
  }
  return min(
    fallbackTriggerChars,
    estimatedChars * triggerTokens ~/ contextTokens,
  );
}

/// 上下文视图单一入口：折叠已压缩事件 → 同参数重复读去重 →
/// microcompact（token 化触发）→ 工具结果总预算（头尾摘录）。
/// 引擎请求、重放侧消息构建、压缩触发核算、上下文明细都走这一个
/// 函数，保证四侧视图一致；确定性纯函数，事件流本体永不改写。
List<AgentEvent> buildContextView(
  List<AgentEvent> events, {
  bool microCompactEnabled = true,
  int microCompactTriggerChars = kMicroCompactTriggerChars,
  int contextTokens = 0,
  int contextLimitTokens = 0,
}) {
  final deduped = dedupeRepeatedReads(foldCompactedEvents(events));
  if (!microCompactEnabled) return applyToolResultBudget(deduped);
  final trigger = effectiveMicroCompactTriggerChars(
    contextTokens: contextTokens,
    contextLimitTokens: contextLimitTokens,
    estimatedChars: totalContextChars(deduped),
    fallbackTriggerChars: microCompactTriggerChars,
  );
  return applyToolResultBudget(
    microCompactEntries(deduped, triggerChars: trigger),
  );
}

ToolCallEvent _withClearedResult(
  ToolCallEvent event, {
  String placeholder = kMicroCompactClearedPlaceholder,
}) => ToolCallEvent(
  id: event.id,
  seq: event.seq,
  at: event.at,
  toolName: event.toolName,
  argSummary: event.argSummary,
  state: event.state,
  resultSummary: event.resultSummary,
  elapsed: event.elapsed,
  argsDetail: event.argsDetail,
  resultDetail: placeholder,
  resultOverflowPath: event.resultOverflowPath,
  imagePath: event.imagePath,
  imageMimeType: event.imageMimeType,
);
