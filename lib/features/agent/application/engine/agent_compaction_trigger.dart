/// 压缩触发判定（压缩升级计划 ③，对标 Claude Code autoCompact）：
/// 优先用 API usage 回报的真实上下文 token 对比模型窗口，拿不到
/// usage（部分供应商不回）时回退字符估算。纯函数，独立于引擎便于单测。
library;

import 'dart:math';

/// 为压缩摘要输出预留的 token（对标 CC MAX_OUTPUT_TOKENS_FOR_SUMMARY，
/// 取其 p99.99 摘要输出量）；小窗口模型按窗口 1/4 封顶，避免预留吃掉
/// 大半窗口。
const int kCompactionSummaryReserveTokens = 20000;

/// 有效窗口的触发比例（CC 同量级：接近打满才压，太早压浪费摘要成本）。
const double kCompactionTriggerRatio = 0.92;

/// 有效上下文窗口 = 模型窗口 − 摘要输出预留。
int effectiveContextWindowTokens(int contextLimitTokens) =>
    contextLimitTokens -
    min(kCompactionSummaryReserveTokens, contextLimitTokens ~/ 4);

/// 按 token 的压缩触发阈值；[triggerRatio] 可调（设置页档位），
/// 默认 [kCompactionTriggerRatio] 保持向后一致。
int compactionTriggerTokens(
  int contextLimitTokens, {
  double triggerRatio = kCompactionTriggerRatio,
}) =>
    (effectiveContextWindowTokens(contextLimitTokens) * triggerRatio).floor();

/// 是否触发压缩：[contextTokens]（API usage 的真实上下文占用，0 = 未知）
/// 与 [contextLimitTokens]（模型窗口，0 = 未知）都已知时走 token 判定；
/// 否则回退 [estimatedChars] > [fallbackTriggerChars] 的字符估算。
bool shouldTriggerCompaction({
  required int contextTokens,
  required int contextLimitTokens,
  required int estimatedChars,
  required int fallbackTriggerChars,
  double triggerRatio = kCompactionTriggerRatio,
}) {
  if (contextTokens > 0 && contextLimitTokens > 0) {
    return contextTokens >
        compactionTriggerTokens(contextLimitTokens,
            triggerRatio: triggerRatio);
  }
  return estimatedChars > fallbackTriggerChars;
}
