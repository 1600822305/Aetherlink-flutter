import 'dart:async';

import '../models/browser_exception.dart';
import 'browser_session.dart';

/// 会话工厂（可注入 mock，测试无需 WebView）。
typedef SessionFactory = BrowserSession Function();

/// 会话管理（设计稿 §16.3 已定方案）：首版单 WebView 共享 +
/// 互斥队列串行 + 空闲超时释放。保留可选 sessionId 参数作多实例
/// 升级口——首版忽略并恒用同一实例。
class BrowserSessionManager {
  BrowserSessionManager({
    required SessionFactory factory,
    this.idleTimeout = const Duration(minutes: 5),
    this.maxConsecutiveFailures = 2,
  }) : _factory = factory;

  final SessionFactory _factory;

  /// 空闲超过该时长自动释放 WebView（下次调用重建）。
  final Duration idleTimeout;

  /// 同会话连续卡死/超时次数达到该值后 dispose 重建（设计稿 §19.2：
  /// 防 WebView 本身进入坏状态）。
  final int maxConsecutiveFailures;

  BrowserSession? _session;
  Future<void> _queue = Future<void>.value();
  Timer? _idleTimer;
  int _consecutiveFailures = 0;
  bool _closed = false;

  /// 互斥串行执行 [action]：并发调用按提交顺序排队（子代理并行时
  /// 也不会互相打断导航）。[sessionId] 首版忽略（升级口）。
  Future<T> run<T>(
    Future<T> Function(BrowserSession session) action, {
    String? sessionId,
  }) {
    if (_closed) {
      throw const BrowserException(
        BrowserErrorKind.sessionGone,
        '浏览器管理器已关闭',
      );
    }
    final result = _queue.then((_) => _runLocked(action));
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<T> _runLocked<T>(
    Future<T> Function(BrowserSession session) action,
  ) async {
    _idleTimer?.cancel();
    final session = _session ??= _factory();
    try {
      final value = await action(session);
      _consecutiveFailures = 0;
      return value;
    } on BrowserException catch (e) {
      if (e.kind == BrowserErrorKind.navigationTimeout ||
          e.kind == BrowserErrorKind.scriptTimeout) {
        _consecutiveFailures++;
        if (_consecutiveFailures >= maxConsecutiveFailures) {
          _consecutiveFailures = 0;
          await _disposeSession();
        }
      }
      rethrow;
    } finally {
      if (!_closed && _session != null) {
        _idleTimer = Timer(idleTimeout, _disposeSession);
      }
    }
  }

  Future<void> _disposeSession() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    final session = _session;
    _session = null;
    await session?.close();
  }

  /// 是否存在存活的 WebView（测试/诊断用）。
  bool get hasLiveSession => _session != null && !_session!.disposed;

  /// App 退出/引擎停止时调用：释放 WebView 并拒绝后续调用。
  Future<void> closeAll() async {
    _closed = true;
    await _disposeSession();
  }
}
