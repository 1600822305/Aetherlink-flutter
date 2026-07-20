/// 上下文压缩（compaction）的纯逻辑（设计初稿 §5.3 / 循环设计稿 ⑦）：
/// 事件流是审计事实源永不改写，压缩只作用于"进模型上下文的视图"。
/// 引擎（判断是否触发/选覆盖区间）与重放侧（di 的 _replayMessages）
/// 共用同一份折叠算法，保证 coveredCount 语义两边一致。
library;

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 把事件流折叠为"进上下文的条目序列"：
/// - 只保留会进 LLM 消息的事件（用户消息 / 非空助手文本 / 工具调用）；
/// - 遇到 [CompactionEvent] 时，其 coveredCount 个最早条目被移除，
///   压缩事件本身作为摘要条目插到队首（可被更晚的压缩再次覆盖）。
List<AgentEvent> foldCompactedEvents(List<AgentEvent> events) {
  final entries = <AgentEvent>[];
  for (final event in events) {
    switch (event) {
      case UserMessageEvent():
        entries.add(event);
      case UserQuestionEvent():
        entries.add(event);
      case AssistantTextEvent():
        if (event.text.isNotEmpty) entries.add(event);
      case ToolCallEvent():
        entries.add(event);
      case CompactionEvent():
        // 已撤销的压缩不参与折叠：视图恢复原样（引擎/重放两侧同一函数）。
        if (event.revoked) break;
        final n = event.coveredCount.clamp(0, entries.length);
        entries.removeRange(0, n);
        entries.insert(0, event);
      case ReasoningEvent() ||
            PlanUpdateEvent() ||
            CheckpointEvent() ||
            StatusChangeEvent():
        break;
    }
  }
  return entries;
}

/// 单个条目进上下文的字符量估算（token 估算的粗代理：中文 ≈1 字/token，
/// 英文 ≈4 字/token，取字符数做保守阈值即可，不追求精确）。
int contextCharsOf(AgentEvent event) => switch (event) {
      UserMessageEvent(:final text) => text.length,
      UserQuestionEvent(:final question, :final suggestions) =>
        question.length +
            suggestions.fold(0, (sum, item) => sum + item.length),
      AssistantTextEvent(:final text) => text.length,
      ToolCallEvent() => (event.argsDetail?.length ?? 0) +
          (event.resultDetail ?? event.resultSummary).length,
      CompactionEvent(:final summary) => summary.length,
      _ => 0,
    };

/// 条目序列的总字符量。
int totalContextChars(List<AgentEvent> entries) =>
    entries.fold(0, (sum, e) => sum + contextCharsOf(e));

/// 选出本次压缩要覆盖的前缀条目：从头累计，直到剩余尾部字符量
/// 降到 [keepChars] 以内为止；始终保留最近 [minKeepEntries] 个条目
/// 不被覆盖（近期上下文对模型最关键）。不足以覆盖时返回空列表。
List<AgentEvent> selectCompactionPrefix(
  List<AgentEvent> entries, {
  required int keepChars,
  int minKeepEntries = 8,
}) {
  if (entries.length <= minKeepEntries) return const [];
  var remaining = totalContextChars(entries);
  final maxCover = entries.length - minKeepEntries;
  var covered = 0;
  while (covered < maxCover && remaining > keepChars) {
    remaining -= contextCharsOf(entries[covered]);
    covered++;
  }
  if (covered == 0) return const [];
  return entries.sublist(0, covered);
}
