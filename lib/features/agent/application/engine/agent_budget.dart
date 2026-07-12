/// 预算护栏（循环设计稿 §3.3 L5）：无限轮循环的成本/失控保险。
/// 超限不是 fail，引擎转 paused + 说明，用户可续跑。
class AgentBudget {
  AgentBudget({
    this.maxRounds = 50,
    this.maxConsecutiveFailures = 5,
    this.toolTimeout = const Duration(minutes: 5),
  });

  final int maxRounds;
  final int maxConsecutiveFailures;
  final Duration toolTimeout;

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
