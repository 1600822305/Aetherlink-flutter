import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';

/// 流式工具执行（对标 CC StreamingToolExecutor）：一轮 LLM 流内，
/// 参数已流完、只读（并发安全）且审批直通（allow）的工具调用立即
/// 开始执行，不等整轮流式输出结束；执行循环到达该调用时改为等待
/// 已在跑的 future，不重复执行。
///
/// 兄弟中止（sibling abort，对标 CC）：本轮被打断/收尾/切模式时，
/// 对仍在跑的提前执行调用发出定向工具中断并等待收敛——避免旧前提
/// 下的工具继续跑，也保证引擎退出本轮前所有 future 都已被等待。
/// 生命周期与一轮 turn 相同（每轮新建）。
class StreamingToolRunner {
  StreamingToolRunner({required this.cancel, required this.maxConcurrent});

  final AgentCancellationToken cancel;
  final int maxConcurrent;

  final Map<String, Future<void>> _inFlight = {};
  bool _stopped = false;

  /// 是否还能提前启动新调用（已中止或达并发上限则否）。
  bool get canStart => !_stopped && _inFlight.length < maxConcurrent;

  /// 登记一个已开始执行的调用；[run] 不应向外抛（工具失败以失败
  /// 结果落库，与执行循环同款约定）。
  void start(String callId, Future<void> Function() run) {
    _inFlight[callId] = run();
  }

  /// 执行循环领取在跑的 future；不存在（未提前执行）返回 null。
  Future<void>? take(String callId) => _inFlight.remove(callId);

  /// 兄弟中止：定向中断仍在跑的全部调用并等待收敛。中断代号定向
  /// 回收，窗口内用户新发起的打断不会被一并吞掉。
  Future<void> abortAndDrain() async {
    _stopped = true;
    if (_inFlight.isEmpty) return;
    final generation = cancel.requestToolInterrupt();
    final pending = _inFlight.values.toList();
    _inFlight.clear();
    await Future.wait(pending);
    cancel.consumeToolInterruptOf(generation);
  }

  /// 流中断善后：提前执行了但未随 turn 返回的调用按兄弟中止处理；
  /// 返回中止数，供引擎识别「模型发过工具调用但没流完」的非收尾轮。
  Future<int> drainUnreturned(Set<String> returnedIds) async {
    final orphaned = <Future<void>>[];
    _inFlight.removeWhere((id, future) {
      if (returnedIds.contains(id)) return false;
      orphaned.add(future);
      return true;
    });
    if (orphaned.isEmpty) return 0;
    final generation = cancel.requestToolInterrupt();
    await Future.wait(orphaned);
    cancel.consumeToolInterruptOf(generation);
    return orphaned.length;
  }
}
