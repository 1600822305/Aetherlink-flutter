// The workspace shell's third page: an interactive PTY terminal (设计文档 §8.2
// / SSH-3b). Only remote backends (SSH / Termux) can open a shell; SAF shows a
// hint instead. The shell is started lazily on an explicit「启动终端」tap so we
// never open a surprise SSH channel just by entering a workspace.
//
// dartssh2 is never imported here — the page talks to the backend-neutral
// [WorkspaceShellSession] (bytes in / bytes out), and xterm renders it.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:xterm/xterm.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

class WorkspaceTerminalPage extends ConsumerStatefulWidget {
  const WorkspaceTerminalPage({
    required this.topInset,
    required this.onBack,
    super.key,
  });

  final double topInset;
  final VoidCallback onBack;

  @override
  ConsumerState<WorkspaceTerminalPage> createState() =>
      _WorkspaceTerminalPageState();
}

class _WorkspaceTerminalPageState
    extends ConsumerState<WorkspaceTerminalPage> {
  final Terminal _terminal = Terminal(maxLines: 10000);

  WorkspaceShellSession? _session;
  StreamSubscription<String>? _outSub;
  bool _connecting = false;
  bool _connected = false;
  String? _error;

  @override
  void dispose() {
    _outSub?.cancel();
    _session?.close();
    super.dispose();
  }

  Future<void> _connect() async {
    final backend = ref.read(workspacePreviewBackendProvider);
    final workspace = ref.read(currentWorkspaceProvider);
    if (backend == null || workspace == null) return;

    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final session = await backend.startShell(
        columns: _terminal.viewWidth,
        rows: _terminal.viewHeight,
        workingDirectory: workspace.root,
      );
      // Wire xterm <-> session: keystrokes out, remote bytes in, size changes.
      _terminal.onOutput = (data) => session.write(utf8.encode(data));
      _terminal.onResize = (w, h, _, __) => session.resize(w, h);
      _outSub = session.output
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(_terminal.write);
      session.done.whenComplete(() {
        if (!mounted) return;
        _terminal.write('\r\n\x1b[33m[会话已结束]\x1b[0m\r\n');
        setState(() => _connected = false);
      });
      if (!mounted) {
        await session.close();
        return;
      }
      setState(() {
        _session = session;
        _connected = true;
        _connecting = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _connecting = false;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    await _outSub?.cancel();
    _outSub = null;
    await _session?.close();
    if (mounted) {
      setState(() {
        _session = null;
        _connected = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workspace = ref.watch(currentWorkspaceProvider);
    final backend = ref.watch(workspacePreviewBackendProvider);
    final canExec = backend?.capabilities.canExec ?? false;
    final topPad = MediaQuery.paddingOf(context).top + widget.topInset;

    return Container(
      color: const Color(0xFF14161B),
      child: Column(
        children: [
          // Header row: back + title + (when connected) a disconnect action.
          Padding(
            padding: EdgeInsets.only(top: topPad + 4, left: 4, right: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: '返回',
                  icon: const Icon(LucideIcons.arrowLeft,
                      size: 20, color: Colors.white),
                  onPressed: widget.onBack,
                ),
                Expanded(
                  child: Text(
                    workspace == null ? '终端' : '终端 · ${workspace.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_connected)
                  IconButton(
                    tooltip: '断开',
                    icon: const Icon(LucideIcons.power,
                        size: 18, color: Colors.white70),
                    onPressed: _disconnect,
                  ),
              ],
            ),
          ),
          Expanded(
            child: _body(theme, canExec: canExec, hasWorkspace: workspace != null),
          ),
        ],
      ),
    );
  }

  Widget _body(ThemeData theme,
      {required bool canExec, required bool hasWorkspace}) {
    if (!hasWorkspace) {
      return const _Hint(
        icon: LucideIcons.terminal,
        text: '请先打开一个工作区',
      );
    }
    if (!canExec) {
      return const _Hint(
        icon: LucideIcons.terminalSquare,
        text: '终端仅在 SSH / Termux 工作区可用',
      );
    }
    if (_connected && _session != null) {
      return TerminalView(
        _terminal,
        autofocus: true,
        padding: const EdgeInsets.all(8),
      );
    }
    if (_connecting) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    // Idle / errored: explicit connect affordance (lazy shell start).
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '连接失败 · $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            onPressed: _connect,
            icon: const Icon(LucideIcons.terminal, size: 18),
            label: Text(_error == null ? '启动终端' : '重试'),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Colors.white38),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }
}
