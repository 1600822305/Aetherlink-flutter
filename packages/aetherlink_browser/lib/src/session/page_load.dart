import 'dart:async';

/// 探测页面是否就绪（注入点：真实实现查 `document.readyState`，
/// 测试用假实现）。
typedef ReadyProbe = Future<bool> Function();

/// 加载等待策略（设计稿 §7.2/§19.2，纯 Dart 可单测）：
/// onLoadStop 信号 + readyState 轮询双保险，整体带导航级超时
/// （默认 30s，< 引擎 5 分钟工具超时）。
class PageLoadPoller {
  const PageLoadPoller({
    this.timeout = const Duration(seconds: 30),
    this.pollInterval = const Duration(milliseconds: 300),
  });

  final Duration timeout;
  final Duration pollInterval;

  /// 等待 [loadStop]（onLoadStop 事件）或 [probe] 返回 true。
  /// 超时返回 false（调用方 stopLoading 并按部分可读处理），不抛异常。
  Future<bool> wait({
    required Future<void> loadStop,
    required ReadyProbe probe,
  }) async {
    final deadline = DateTime.now().add(timeout);
    var stopped = false;
    unawaited(loadStop.then<void>((_) {
      stopped = true;
    }).catchError((_) {}));
    while (DateTime.now().isBefore(deadline)) {
      if (stopped) return true;
      try {
        if (await probe()) return true;
      } catch (_) {
        // 导航中途 evaluate 可能瞬时失败，继续轮询。
      }
      await Future<void>.delayed(pollInterval);
    }
    return stopped;
  }
}
