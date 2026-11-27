// 终端后台保持运行（设置 → 后台执行 → 终端后台保持运行，默认关）。
//
// 打开后：终端「有会话在用」时，向 MobileBackgroundCoordinator 登记一个后台
// 任务，由 App 统一的前台服务 + WakeLock 保活，锁屏后命令继续跑；同时关掉
// 终端插件自带的（无 WakeLock 的）保活服务，只留一条通知。
// 「在用」= 用户在终端页开着已连接的会话，或任一 AI 会话正在执行命令。
// 不在用时撤销登记、恢复插件自带服务（与关闭开关时的行为一致）。

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:aetherlink_flutter/features/terminal/data/proot_process_runner.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';
import 'package:aetherlink_flutter/shared/services/mobile_background.dart';

class TerminalKeepAlive {
  TerminalKeepAlive._();

  static final TerminalKeepAlive instance = TerminalKeepAlive._();

  static const String _taskId = 'terminal:keepalive';

  final Set<Object> _userSessions = {};
  WorkspaceSessionPoolManager? _pool;
  bool _registered = false;
  bool _initialized = false;

  /// 用户在通知里点了「停止」：本轮不再保活，直到不在用后重新计算。
  bool _suppressed = false;

  MobileBackgroundCoordinator get _coordinator =>
      MobileBackgroundCoordinator.instance;

  /// App 启动时调用一次：挂上会话池，开始跟随设置 / busy 变化。
  void attach(WorkspaceSessionPoolManager pool) {
    _pool = pool;
    if (_initialized) return;
    _initialized = true;
    _coordinator.addListener(_recompute);
    WorkspaceSessionPoolManager.busyChanges.addListener(_recompute);
    pool.addListener(_recompute);
    _recompute();
  }

  /// 终端页某个会话已连接 / 已结束（[token] 为该会话的唯一对象）。
  void userSessionOpened(Object token) {
    if (_userSessions.add(token)) _recompute();
  }

  void userSessionClosed(Object token) {
    if (_userSessions.remove(token)) _recompute();
  }

  bool get _inUse {
    if (_userSessions.isNotEmpty) return true;
    final pool = _pool;
    if (pool == null) return false;
    return pool.allSessions().any((s) => s.alive && s.busy);
  }

  @visibleForTesting
  bool get registered => _registered;

  void _recompute() {
    final enabled =
        _coordinator.supported && _coordinator.settings.terminalKeepAlive;
    final inUse = _inUse;
    if (!inUse) _suppressed = false;
    final want = enabled && inUse && !_suppressed;
    if (want == _registered) return;
    _registered = want;
    if (want) {
      unawaited(setTerminalPluginKeepAliveService(false));
      unawaited(
        _coordinator.start(
          id: _taskId,
          conversationId: '',
          title: '终端运行中',
          cancel: () async {
            _suppressed = true;
            _recompute();
          },
        ),
      );
      _coordinator.update(_taskId, phase: BackgroundTaskPhase.tool);
    } else {
      unawaited(_coordinator.finish(_taskId, BackgroundTaskOutcome.cancelled));
      unawaited(setTerminalPluginKeepAliveService(true));
    }
  }
}
