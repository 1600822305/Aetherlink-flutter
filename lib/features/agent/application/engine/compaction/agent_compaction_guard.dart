/// 压缩预警与熔断（压缩升级计划 ④，对标 Claude Code
/// compactWarningHook / circuit breaker）：
/// - 预警：上下文接近触发阈值（≥90%）时提前提示一次，用户可自行收敛；
/// - 熔断：连续多次压缩失败后本任务内停止再尝试，避免每轮白调一次
///   LLM；成功一次即重置。
/// 纯逻辑模块，独立于引擎便于单测。
library;

import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_compaction_trigger.dart';

/// 预警比例：达到触发阈值的 90%（即距触发 ≤10%）时预警。
const double kCompactionWarningRatio = 0.9;

/// 连续失败多少次后熔断（本任务内不再尝试压缩）。
const int kCompactionMaxConsecutiveFailures = 3;

/// 是否已进入预警区间：达到触发阈值的 [kCompactionWarningRatio] 且尚未
/// 触发压缩。与触发判定同款双路：usage + 窗口都已知走 token，否则回退
/// 字符估算。
bool isNearCompactionThreshold({
  required int contextTokens,
  required int contextLimitTokens,
  required int estimatedChars,
  required int fallbackTriggerChars,
  double triggerRatio = kCompactionTriggerRatio,
}) {
  if (contextTokens > 0 && contextLimitTokens > 0) {
    final trigger = compactionTriggerTokens(contextLimitTokens,
        triggerRatio: triggerRatio);
    return contextTokens >= (trigger * kCompactionWarningRatio).floor() &&
        contextTokens <= trigger;
  }
  return estimatedChars >=
          (fallbackTriggerChars * kCompactionWarningRatio).floor() &&
      estimatedChars <= fallbackTriggerChars;
}

/// 压缩熔断器：连续失败计数，达到上限后 open（停止再尝试）；
/// 成功一次即重置。任务运行实例级状态（随引擎实例生灭，续跑重置）。
class CompactionCircuitBreaker {
  CompactionCircuitBreaker({
    this.maxConsecutiveFailures = kCompactionMaxConsecutiveFailures,
  });

  final int maxConsecutiveFailures;
  int _consecutiveFailures = 0;

  bool get isOpen => _consecutiveFailures >= maxConsecutiveFailures;

  /// 记录一次失败；返回 true 表示本次失败刚好触发熔断（用于只提示一次）。
  bool recordFailure() {
    if (isOpen) return false;
    _consecutiveFailures++;
    return isOpen;
  }

  void recordSuccess() => _consecutiveFailures = 0;
}
