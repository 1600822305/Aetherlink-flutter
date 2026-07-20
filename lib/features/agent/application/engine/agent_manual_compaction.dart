/// 手动压缩（压缩升级计划 ⑤，对标 Claude Code `/compact`）：
/// 用户主动触发的一次强制压缩——忽略触发阈值，仍走既有的折叠 +
/// microcompact 视图与 keep 前缀选择规则。空闲任务（暂停/完成/失败）
/// 由 runner 直接调用本函数；运行中任务经引擎的手动压缩信号在下一个
/// 安全点走同一函数。共享逻辑，两路语义一致。
library;

import 'package:aetherlink_flutter/features/agent/application/engine/agent_compaction.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_microcompact.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 一次手动压缩的结果。
sealed class ManualCompactionOutcome {
  const ManualCompactionOutcome();
}

/// 压缩成功：摘要已落库（CompactionEvent）。
class ManualCompactionDone extends ManualCompactionOutcome {
  const ManualCompactionDone({required this.coveredCount});

  final int coveredCount;
}

/// 内容太少，无可压缩前缀（keep 规则下没有可覆盖区间）。
class ManualCompactionNothingToCover extends ManualCompactionOutcome {
  const ManualCompactionNothingToCover();
}

/// 强制压缩一次：折叠 + microcompact 后选 keep 前缀（与自动压缩同款
/// 规则），调 LLM 摘要并落 CompactionEvent。摘要为空时抛错（与自动
/// 压缩同语义，调用方自行提示）。
Future<ManualCompactionOutcome> runManualCompaction({
  required AgentTask task,
  required List<AgentEvent> events,
  required AgentLlmClient llm,
  required AgentEventStore store,
  required int keepChars,
  int microCompactTriggerChars = kMicroCompactTriggerChars,
}) async {
  final entries = microCompactEntries(
    foldCompactedEvents(events),
    triggerChars: microCompactTriggerChars,
  );
  final covered = selectCompactionPrefix(entries, keepChars: keepChars);
  if (covered.isEmpty) return const ManualCompactionNothingToCover();
  final summary = await llm.summarizeForCompaction(task, covered);
  if (summary.trim().isEmpty) {
    throw StateError('压缩摘要为空（可能是模型未配置或模型返回空结果）');
  }
  await store.appendCompaction(
    task.id,
    coveredCount: covered.length,
    summary: summary.trim(),
  );
  return ManualCompactionDone(coveredCount: covered.length);
}
