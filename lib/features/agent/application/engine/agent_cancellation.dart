/// 协作式取消信号（循环设计稿 §3.3 L4）：在工具边界/安全点生效，
/// 不硬杀执行中的步骤，保证事件流不留半截。
class AgentCancellationToken {
  bool _pauseRequested = false;
  bool _cancelRequested = false;
  bool _toolInterruptRequested = false;
  int _interruptGeneration = 0;
  final List<void Function()> _listeners = [];

  /// 暂停：循环在下一个安全点转 paused，可续跑。
  void requestPause() {
    _pauseRequested = true;
    _notify();
  }

  /// 强制终止：循环在下一个安全点转 cancelled，不可恢复。
  void requestCancel() {
    _cancelRequested = true;
    _notify();
  }

  /// 打断当前工具（「立即打断并发送」/工具超时）：只中止正在执行
  /// 的工具/LLM 流，循环本身继续（下一轮先消费排队消息）。
  /// 返回本次请求的代号，供 [consumeToolInterruptOf] 定向回收。
  int requestToolInterrupt() {
    _toolInterruptRequested = true;
    final generation = ++_interruptGeneration;
    _notify();
    return generation;
  }

  /// 信号变化监听（事件驱动，替代定时轮询）：任一 request* 触发。
  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) =>
      _listeners.remove(listener);

  void _notify() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  bool get pauseRequested => _pauseRequested;
  bool get cancelRequested => _cancelRequested;
  bool get stopRequested => _pauseRequested || _cancelRequested;

  /// 只读探针（不复位）：LLM 流侧用它决定是否中断流，复位由
  /// 引擎在安全点统一做。
  bool get toolInterruptRequested => _toolInterruptRequested;

  /// 工具侧轮询用；命中一次即复位（只打断当前这一个工具）。
  bool consumeToolInterrupt() {
    if (!_toolInterruptRequested) return false;
    _toolInterruptRequested = false;
    return true;
  }

  /// 定向回收：仅当标记仍属于 [generation] 那次请求时才复位。
  /// 超时自发自收用它：若窗口内用户又发起了新的打断（代号已
  /// 前进），不会把用户的打断一并吞掉。
  bool consumeToolInterruptOf(int generation) {
    if (!_toolInterruptRequested || _interruptGeneration != generation) {
      return false;
    }
    _toolInterruptRequested = false;
    return true;
  }
}
