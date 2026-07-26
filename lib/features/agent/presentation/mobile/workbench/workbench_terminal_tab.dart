import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:xterm/xterm.dart';

import 'package:aetherlink_flutter/app/di/agent_terminal_access.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/session_terminal.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/terminal_extra_keys.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 工作台「终端」tab（UI 稿 §4.3）：实时围观任务绑定工作区里的 AI 终端
/// 会话——回放会话回看缓冲 + 订阅实时输出，键入直接写进会话 stdin
/// （用户可接管）。与工作区终端页共用一套会话联动组件（状态条 / 按键条 /
/// 会话 chip），并支持手动新建 / 关闭会话；关闭视图只断订阅不关会话
/// （会话生命周期归会话池 / AI 管）。
class WorkbenchTerminalTab extends ConsumerStatefulWidget {
  const WorkbenchTerminalTab({required this.task, super.key});

  final AgentTask task;

  @override
  ConsumerState<WorkbenchTerminalTab> createState() =>
      _WorkbenchTerminalTabState();
}

class _WorkbenchTerminalTabState extends ConsumerState<WorkbenchTerminalTab> {
  final Map<String, SessionTerminalAttachment> _views = {};
  String? _activeId;
  WorkspaceSessionPoolManager? _manager;
  final TerminalExtraKeysController _extraKeys = TerminalExtraKeysController();
  bool _creating = false;

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
    _extraKeys.dispose();
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

  SessionTerminalAttachment _viewFor(PooledWorkspaceSession session) =>
      _views.putIfAbsent(
        session.id,
        () =>
            SessionTerminalAttachment(session, transform: _extraKeys.transform),
      );

  Future<void> _createSession() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final session = await createAgentTerminalSession(
        ref,
        widget.task.workspaceId,
      );
      if (mounted) setState(() => _activeId = session.id);
    } on WorkspaceSessionException catch (e) {
      if (mounted) AppToast.info(context, e.message);
    } catch (e) {
      if (mounted) AppToast.info(context, '新建会话失败：$e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _closeSession(PooledWorkspaceSession session) async {
    await _manager?.close(session.id);
  }

  void _toggleKeyboard(FocusNode node) {
    if (node.hasFocus) {
      node.unfocus();
    } else {
      node.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(agentSessionPoolManagerProvider);
    final sessions = agentAliveSessions(manager, widget.task.workspaceId);
    if (sessions.isEmpty) {
      return _empty(context);
    }
    final active =
        sessions.where((s) => s.id == _activeId).firstOrNull ?? sessions.first;
    final view = _viewFor(active);
    return Container(
      color: const Color(0xFF14161B),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) => SessionChip(
                        session: sessions[index],
                        selected: sessions[index].id == active.id,
                        onTap: () =>
                            setState(() => _activeId = sessions[index].id),
                        onClose: () => _closeSession(sessions[index]),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '新建会话',
                    icon: const Icon(
                      LucideIcons.plus,
                      size: 18,
                      color: Colors.white70,
                    ),
                    onPressed: _creating ? null : _createSession,
                  ),
                ],
              ),
            ),
            AiSessionStatusBar(session: active),
            Expanded(
              child: TerminalView(
                view.terminal,
                controller: view.controller,
                focusNode: view.focusNode,
                textStyle: const TerminalStyle(fontSize: 13),
                padding: const EdgeInsets.all(8),
              ),
            ),
            TerminalExtraKeysBar(
              controller: _extraKeys,
              terminal: view.terminal,
              onCopy: () => copyTerminalSelection(
                context,
                view.terminal,
                view.controller,
              ),
              onPaste: () => pasteClipboardToTerminal(context, view.terminal),
              onToggleKeyboard: () => _toggleKeyboard(view.focusNode),
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
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _creating ? null : _createSession,
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('新建会话'),
          ),
        ],
      ),
    );
  }
}
