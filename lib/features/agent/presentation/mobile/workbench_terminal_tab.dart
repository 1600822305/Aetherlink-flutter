import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:xterm/xterm.dart';

import 'package:aetherlink_flutter/app/di/agent_terminal_access.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 工作台「终端」tab（UI 稿 §4.3）：实时围观任务绑定工作区里的 AI 终端
/// 会话——回放会话回看缓冲 + 订阅实时输出，键入直接写进会话 stdin
/// （用户可接管）。多会话时顶部 chips 切换；关闭视图只断订阅不关会话
/// （会话生命周期归会话池 / AI 管）。
class WorkbenchTerminalTab extends ConsumerStatefulWidget {
  const WorkbenchTerminalTab({required this.task, super.key});

  final AgentTask task;

  @override
  ConsumerState<WorkbenchTerminalTab> createState() =>
      _WorkbenchTerminalTabState();
}

/// 单个 AI 会话的联动视图：xterm 缓冲 + 输出订阅（与会话同生命周期无关，
/// detach 只断订阅）。
class _SessionView {
  _SessionView(this.session) {
    // 缓冲里就是 PTY 原始字节（含 \r\n 与 ANSI 序列），直接回放。
    terminal.write(session.snapshot());
    _sub = session.chunks.listen(terminal.write);
    terminal.onOutput = (data) {
      if (session.alive) session.writeInput(data);
    };
  }

  final PooledWorkspaceSession session;
  final Terminal terminal = Terminal(maxLines: 10000);
  final TerminalController controller = TerminalController();
  StreamSubscription<String>? _sub;

  Future<void> detach() async {
    await _sub?.cancel();
    _sub = null;
  }
}

class _WorkbenchTerminalTabState extends ConsumerState<WorkbenchTerminalTab> {
  final Map<String, _SessionView> _views = {};
  String? _activeId;
  WorkspaceSessionPoolManager? _manager;

  @override
  void initState() {
    super.initState();
    final manager = ref.read(agentSessionPoolManagerProvider);
    manager.addListener(_onPoolChanged);
    _manager = manager;
  }

  @override
  void dispose() {
    _manager?.removeListener(_onPoolChanged);
    for (final view in _views.values) {
      view.detach();
    }
    super.dispose();
  }

  /// 会话池变化（新建 / 关闭 / 回收）：刷新 chips，剔除已死会话的视图。
  /// 池的 _prune 可能在 build 期间触发通知，延到帧末再 setState。
  void _onPoolChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _views.removeWhere((id, view) {
          if (view.session.alive) return false;
          view.detach();
          return true;
        });
        if (_activeId != null && !_views.containsKey(_activeId)) {
          _activeId = null;
        }
      });
    });
  }

  _SessionView _viewFor(PooledWorkspaceSession session) =>
      _views.putIfAbsent(session.id, () => _SessionView(session));

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(agentSessionPoolManagerProvider);
    final sessions = agentAliveSessions(manager, widget.task.workspaceId);
    if (sessions.isEmpty) {
      return _empty(context);
    }
    final active = sessions
            .where((s) => s.id == _activeId)
            .firstOrNull ??
        sessions.first;
    final view = _viewFor(active);
    return Container(
      color: const Color(0xFF14161B),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (sessions.length > 1)
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) =>
                      _chip(sessions[index], selected: sessions[index].id == active.id),
                ),
              ),
            Expanded(
              child: TerminalView(
                view.terminal,
                controller: view.controller,
                textStyle: const TerminalStyle(fontSize: 13),
                padding: const EdgeInsets.all(8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// AI 会话 chip：机器人图标（忙碌琥珀色 / 空闲绿色）+ 会话名。
  Widget _chip(PooledWorkspaceSession session, {required bool selected}) {
    return GestureDetector(
      onTap: () => setState(() => _activeId = session.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.white38 : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.bot,
              size: 13,
              color: session.busy ? Colors.amberAccent : Colors.greenAccent,
            ),
            const SizedBox(width: 6),
            Text(
              'AI · ${session.name}',
              style: TextStyle(
                fontSize: 13,
                color: selected ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.35);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.terminal, size: 40, color: muted),
          const SizedBox(height: 12),
          Text(
            '暂无终端会话\n智能体在终端里跑命令时这里可实时围观',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
