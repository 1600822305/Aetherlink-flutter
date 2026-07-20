import 'package:aetherlink_flutter/features/agent/application/engine/agent_compaction_trigger.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_microcompact.dart';

/// 预算护栏（循环设计稿 §3.3 L5）：无限轮循环的成本/失控保险。
/// 超限不是 fail，引擎转 paused + 说明，用户可续跑。
class AgentBudget {
  AgentBudget({
    this.maxRounds = 50,
    this.maxConsecutiveFailures = 5,
    this.toolTimeout = const Duration(minutes: 5),
    this.maxTokens = 500000,
    this.compactionTriggerChars = 120000,
    this.compactionKeepChars = 40000,
    this.microCompactTriggerChars = kMicroCompactTriggerChars,
    this.contextLimitTokens = 0,
    this.autoCompactEnabled = true,
    this.microCompactEnabled = true,
    this.compactionTriggerRatio = kCompactionTriggerRatio,
  });

  final int maxRounds;
  final int maxConsecutiveFailures;
  final Duration toolTimeout;

  /// 本次运行（启动/续跑一次）的 token 预算；超限 paused，用户点
  /// 「继续」新建预算实例即续批一份额度（与轮数预算同款语义）。
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

  void recordRound() => _rounds++;

  void recordTokens(int tokens) => _tokens += tokens;

  void recordToolResult({required bool ok}) {
    if (ok) {
      _consecutiveFailures = 0;
    } else {
      _consecutiveFailures++;
    }
  }

  /// 非 null = 已超限（返回给用户看的说明）。
  String? get exceededReason {
    if (_rounds >= maxRounds) {
      return '已达轮数上限（$maxRounds 轮），任务暂停，可继续';
    }
    if (_consecutiveFailures >= maxConsecutiveFailures) {
      return '连续 $maxConsecutiveFailures 次工具失败，任务暂停，请检查后继续';
    }
    if (_tokens >= maxTokens) {
      return '本次运行 token 用量已达预算上限（$maxTokens），任务暂停，可继续';
    }
    return null;
  }
}
