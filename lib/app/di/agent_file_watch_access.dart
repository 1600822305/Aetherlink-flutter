import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/agent_workspace_access.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_file_watch.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// fileChanged hooks 的工作区文件 watcher（组装层，对标 Claude Code
/// 的 FileChanged watcher）。
///
/// 生命周期与一次任务运行绑定（任务运行器 start / stop）：启动时
/// 探询是否配有 fileChanged hooks（无则不订阅），订阅任务绑定工作区
/// 后端的 watch 流，事件经领域层去抖（[AgentFileChangeDebouncer]）
/// 合并后逐条 fire-and-forget 跑 hooks。目录变更与去抖窗口内
/// 新建后即删除的条目不触发。观测型：hook 结果不回流引擎。
class AgentWorkspaceFileWatcher {
  AgentWorkspaceFileWatcher(
    this._refOf, {
    required Future<bool> Function() hasHooks,
    required Future<void> Function(String path, String changeKind) runHooks,
    String? boundWorkspaceId,
    Duration quietWindow = const Duration(milliseconds: 500),
  }) : _hasHooks = hasHooks,
       _runHooks = runHooks,
       _boundWorkspaceId = boundWorkspaceId,
       _debouncer = AgentFileChangeDebouncer(quietWindow: quietWindow);

  final Ref Function() _refOf;
  final Future<bool> Function() _hasHooks;
  final Future<void> Function(String path, String changeKind) _runHooks;
  final String? _boundWorkspaceId;
  final AgentFileChangeDebouncer _debouncer;

  StreamSubscription<WorkspaceChangeEvent>? _sub;
  Timer? _flushTimer;
  bool _started = false;

  /// 启动监听：无 fileChanged hooks 配置（或 disableAllHooks 打开）、
  /// 工作区不可解析、后端不支持 watch 时静默不启动。
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      if (!await _hasHooks()) return;
      final resolved = await resolveAgentWorkspace(_refOf(), _boundWorkspaceId);
      if (resolved == null) return;
      final (_, backend) = resolved;
      if (!backend.capabilities.canWatch) return;
      _sub = backend.watch().listen(_onEvent, onError: (_) {});
    } catch (_) {}
  }

  Future<void> stop() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _sub?.cancel();
    _sub = null;
  }

  void _onEvent(WorkspaceChangeEvent event) {
    _debouncer.add(event.path, event.kind.name, DateTime.now());
    _flushTimer ??= Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _flush(),
    );
  }

  void _flush() {
    final due = _debouncer.flushDue(DateTime.now());
    for (final change in due) {
      unawaited(_runHooks(change.path, change.kind));
    }
    if (_debouncer.isEmpty) {
      _flushTimer?.cancel();
      _flushTimer = null;
    }
  }
}
