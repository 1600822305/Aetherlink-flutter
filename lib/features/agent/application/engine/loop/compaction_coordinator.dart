import 'package:aetherlink_flutter/features/agent/application/engine/agent_budget.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_compaction.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_compaction_file_restore.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_compaction_guard.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_compaction_trigger.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_manual_compaction.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_microcompact.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 上下文压缩协调器：触发判定（阈值/预警/手动/反应式）、熔断、
/// keep 前缀选择、LLM 摘要与压缩事件落库。从引擎主循环拆出，
/// 持有一次运行内的压缩状态（预警/失败提示只发一次、熔断计数）。
class CompactionCoordinator {
  CompactionCoordinator({
    required this.llm,
    required this.store,
    required this.budget,
    this.onNotification,
    this.onPreCompact,
    this.onPostCompact,
    this.onCompactionFailed,
    this.manualCompactSignal,
  });

  final AgentLlmClient llm;
  final AgentEventStore store;
  final AgentBudget budget;

  final void Function(String message, String type)? onNotification;
  final void Function()? onPreCompact;
  final void Function(String summary)? onPostCompact;
  final void Function()? onCompactionFailed;
  final ManualCompactRequest? Function()? manualCompactSignal;

  bool _failureNotified = false;
  bool _warningNotified = false;

  /// 压缩熔断器（升级计划 ④）：连续失败达上限后本次运行内不再尝试，
  /// 成功一次即重置；随协调器实例生灭，续跑重新计数。
  final CompactionCircuitBreaker _breaker = CompactionCircuitBreaker();

  /// 自动/强制压缩入口；[force] 为反应式压缩（供应商拒绝超长 prompt）。
  /// 失败向上抛，由 [handleFailure] 统一善后。
  Future<void> maybeCompact(
    AgentTask task,
    List<AgentEvent> events, {
    bool force = false,
  }) async {
    // 与重放侧同款视图：先折叠、再 microcompact，确保 LLM 压缩的
    // 触发判断基于模型实际看到的内容量（两级降压：先 micro 后 LLM）。
    final folded = foldCompactedEvents(events);
    final entries = applyToolResultBudget(budget.microCompactEnabled
        ? microCompactEntries(
            folded,
            triggerChars: budget.microCompactTriggerChars,
          )
        : folded);
    // 手动压缩（升级计划 ⑤）：用户主动触发时跳过阈值/预警/熔断，
    // 直接走 keep 前缀选择。
    final manualRequest = manualCompactSignal?.call();
    // force：反应式压缩（升级计划 ⑧）与手动压缩同样跳过阈值/预警/熔断。
    final forced = force || manualRequest != null;
    // 触发判定（升级计划 ③）：优先用 API usage 的真实上下文 token 对比
    // 模型窗口（减摘要预留、乘触发比例），拿不到 usage 时回退字符估算。
    final overThreshold = shouldTriggerCompaction(
      contextTokens: task.contextTokens,
      contextLimitTokens: budget.contextLimitTokens,
      estimatedChars: totalContextChars(entries),
      fallbackTriggerChars: budget.compactionTriggerChars,
      triggerRatio: budget.compactionTriggerRatio,
    );
    // 自动压缩总开关：关掉后阈值不再自动触发（预警照发），
    // 手动压缩（forced）不受影响。
    final shouldCompact =
        forced || (budget.autoCompactEnabled && overThreshold);
    if (!shouldCompact) {
      // 预警（升级计划 ④）：进入触发阈值的 90% 区间时提前提示一次
      // （可见状态行 + notification hook，type=compactWarning）；
      // 自动压缩关闭且已超阈值时同样只提示一次，提醒可手动压缩。
      if (!_warningNotified &&
          (overThreshold ||
              isNearCompactionThreshold(
                contextTokens: task.contextTokens,
                contextLimitTokens: budget.contextLimitTokens,
                estimatedChars: totalContextChars(entries),
                fallbackTriggerChars: budget.compactionTriggerChars,
                triggerRatio: budget.compactionTriggerRatio,
              ))) {
        _warningNotified = true;
        final message = overThreshold
            ? '上下文已超过压缩阈值（自动压缩已关闭），可手动压缩'
            : '上下文即将达到压缩阈值，稍后将自动压缩';
        try {
          await store.appendStatusChange(task.id, message);
        } catch (_) {}
        onNotification?.call(message, 'compactWarning');
      }
      return;
    }
    if (!forced && _breaker.isOpen) return;
    final covered = selectCompactionPrefix(
      entries,
      keepChars: budget.compactionKeepChars,
    );
    if (covered.isEmpty) {
      if (forced) {
        try {
          await store.appendStatusChange(task.id, '内容太少，无需压缩');
        } catch (_) {}
        // 强制请求已消费但没有落压缩事件：清理「压缩中」实况行。
        onCompactionFailed?.call();
      }
      return;
    }
    onPreCompact?.call();
    final summary = await llm.summarizeForCompaction(
      task,
      covered,
      customInstructions: manualRequest?.customInstructions,
    );
    if (summary.trim().isEmpty) {
      throw StateError('压缩摘要为空（可能是模型未配置或模型返回空结果）');
    }
    // 压缩后文件恢复（升级计划 ⑥）：被覆盖区间里最近读过的文件
    // 快照随摘要一起注入视图，模型不必重读。
    final restored = selectRestoredFiles(
      covered: covered,
      kept: entries.sublist(covered.length),
    );
    await store.appendCompaction(
      task.id,
      coveredCount: covered.length,
      summary: summary.trim(),
      restoredFiles: restored,
    );
    _breaker.recordSuccess();
    // 压缩成功后允许再次预警（对齐 CC suppressCompactWarning 语义：
    // 压缩把上下文降下来了，之后再逼近阈值应再次提醒）。
    _warningNotified = false;
    onPostCompact?.call(summary.trim());
  }

  /// 自动压缩失败的善后：清理实况行、熔断计数、一次性可见提示。
  /// （反应式压缩的失败不走这里——不压缩重试也必然超限，直接失败任务。）
  Future<void> handleFailure(AgentTask task, Object error) async {
    // 压缩中实况行随失败清理（onPostCompact 不会再触发）。
    onCompactionFailed?.call();
    // 压缩失败不阻断任务（下轮再试），但给一次可见提示，
    // 避免上下文持续膨胀到预算暂停时用户不知原因。
    final justOpened = _breaker.recordFailure();
    if (justOpened) {
      // 熔断（升级计划 ④）：连续失败达上限，本次运行内停止再尝试，
      // 避免每轮白调一次 LLM；给一次可见提示。
      try {
        await store.appendStatusChange(
            task.id,
            '上下文压缩连续失败 '
            '${_breaker.maxConsecutiveFailures} 次，本次运行内'
            '不再尝试（续跑恢复）：$error');
      } catch (_) {}
    } else if (!_failureNotified) {
      _failureNotified = true;
      try {
        await store.appendStatusChange(
            task.id, '上下文压缩失败（不影响任务，下轮重试）：$error');
      } catch (_) {}
    }
  }
}
