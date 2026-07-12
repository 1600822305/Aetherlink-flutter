/// 协作式取消信号（循环设计稿 §3.3 L4）：在工具边界/安全点生效，
/// 不硬杀执行中的步骤，保证事件流不留半截。
class AgentCancellationToken {
  bool _pauseRequested = false;
  bool _cancelRequested = false;
  bool _toolInterruptRequested = false;

  /// 暂停：循环在下一个安全点转 paused，可续跑。
  void requestPause() => _pauseRequested = true;

  /// 强制终止：循环在下一个安全点转 cancelled，不可恢复。
  void requestCancel() => _cancelRequested = true;

  /// 打断当前工具（「立即打断并发送」）：只中止正在执行的工具，
  /// 循环本身继续（下一轮先消费排队消息）。
  void requestToolInterrupt() => _toolInterruptRequested = true;

  bool get pauseRequested => _pauseRequested;
  bool get cancelRequested => _cancelRequested;
  bool get stopRequested => _pauseRequested || _cancelRequested;

  /// 工具侧轮询用；命中一次即复位（只打断当前这一个工具）。
  bool consumeToolInterrupt() {
    if (!_toolInterruptRequested) return false;
    _toolInterruptRequested = false;
    return true;
  }
}
