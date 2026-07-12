/// 预算护栏（循环设计稿 §3.3 L5）：无限轮循环的成本/失控保险。
/// 超限不是 fail，引擎转 paused + 说明，用户可续跑。
class AgentBudget {
  AgentBudget({
    this.maxRounds = 50,
    this.maxConsecutiveFailures = 5,
    this.toolTimeout = const Duration(minutes: 5),
    this.compactionTriggerChars = 120000,
    this.compactionKeepChars = 40000,
  });

  final int maxRounds;
  final int maxConsecutiveFailures;
  final Duration toolTimeout;

  /// 上下文重放内容超过该字符量触发 compaction（字符作 token 的
  /// 粗代理，中文 ≈1 字/token；设计初稿 §5.3 的“窗口 ~70%”的保守取值）。
  final int compactionTriggerChars;

  /// 压缩后保留给尾部近期事件的字符预算。
  final int compactionKeepChars;

  int _rounds = 0;
  int _consecutiveFailures = 0;

  void recordRound() => _rounds++;

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
    return null;
  }
}
