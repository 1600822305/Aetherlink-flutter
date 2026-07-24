import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_compaction_trigger.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_microcompact.dart';

/// 预算护栏（循环设计稿 §3.3 L5）：无限轮循环的成本/失控保险。
/// 超限不是 fail，引擎转 paused + 说明，用户可续跑。
/// 轮数/token 预算 0 = 不限（对齐 Claude Code：主循环默认无上限，
/// 上下文靠压缩管；子代理等场景可显式传有限预算）。
class AgentBudget {
  AgentBudget({
    this.maxRounds = 0,
    this.maxConsecutiveFailures = 5,
    this.toolTimeout = const Duration(minutes: 5),
    this.maxTokens = 0,
    this.compactionTriggerChars = 120000,
    this.compactionKeepChars = 40000,
    this.microCompactTriggerChars = kMicroCompactTriggerChars,
    this.contextLimitTokens = 0,
    this.autoCompactEnabled = true,
    this.microCompactEnabled = true,
    this.compactionTriggerRatio = kCompactionTriggerRatio,
  });

  /// 本次运行的轮数上限；0 = 不限。
  final int maxRounds;
  final int maxConsecutiveFailures;
  final Duration toolTimeout;

  /// 本次运行（启动/续跑一次）的 token 预算；0 = 不限。超限 paused，
  /// 用户点「继续」新建预算实例即续批一份额度（与轮数预算同款语义）。
  final int maxTokens;

  /// 上下文重放内容超过该字符量触发 compaction（字符作 token 的
  /// 粗代理，中文 ≈1 字/token；设计初稿 §5.3 的“窗口 ~70%”的保守取值）。
  final int compactionTriggerChars;

  /// 压缩后保留给尾部近期事件的字符预算。
  final int compactionKeepChars;

  /// microcompact（不调 LLM 的旧工具输出占位清除）触发阈值：低于
  /// [compactionTriggerChars]，先 micro 后 LLM 的两级降压。重放侧经
  /// AgentLlmContext 拿到同一生效值，两侧视图必须一致。
  final int microCompactTriggerChars;

  /// 模型上下文窗口（token）：与 API usage 回报的真实上下文占用配合
  /// 做按 token 的压缩触发判定；0 = 未知，回退字符估算。
  final int contextLimitTokens;

  /// 自动压缩总开关：关掉后阈值不再自动触发（预警照发、手动压缩
  /// 不受影响）。
  final bool autoCompactEnabled;

  /// microcompact 开关：关掉后引擎与重放侧都不做旧工具输出清除。
  final bool microCompactEnabled;

  /// 有效窗口的自动压缩触发比例（token 路径）。
  final double compactionTriggerRatio;

  int _rounds = 0;
  int _consecutiveFailures = 0;
  int _tokens = 0;
  int _lastContextTokens = 0;

  void recordRound() => _rounds++;

  /// 按增量记账：本轮新产出（completion）全额 + 上下文相对上轮的
  /// 增量。若每轮把完整 prompt 重复计入，预算会随轮数平方级消耗
  /// （第 n 轮把前 n-1 轮的上下文再记一遍），子代理的有限 token
  /// 预算几轮就被耗尽。供应商不回上下文用量时按总量计。
  void recordTurnUsage({required int totalTokens, required int contextTokens}) {
    if (totalTokens <= 0) return;
    final completion = contextTokens > 0
        ? (totalTokens - contextTokens).clamp(0, totalTokens)
        : totalTokens;
    final growth = contextTokens > _lastContextTokens
        ? contextTokens - _lastContextTokens
        : 0;
    _tokens += completion + growth;
    if (contextTokens > 0) _lastContextTokens = contextTokens;
  }

  void recordToolResult({required bool ok}) {
    if (ok) {
      _consecutiveFailures = 0;
    } else {
      _consecutiveFailures++;
    }
  }

  /// 非 null = 已超限（返回给用户看的说明）。
  String? get exceededReason {
    if (maxRounds > 0 && _rounds >= maxRounds) {
      return '已达轮数上限（$maxRounds 轮），任务暂停，可继续';
    }
    if (_consecutiveFailures >= maxConsecutiveFailures) {
      return '连续 $maxConsecutiveFailures 次工具失败，任务暂停，请检查后继续';
    }
    if (maxTokens > 0 && _tokens >= maxTokens) {
      return '本次运行 token 用量已达预算上限（$maxTokens），任务暂停，可继续';
    }
    return null;
  }
}
