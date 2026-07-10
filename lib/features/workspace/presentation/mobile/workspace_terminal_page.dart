// The workspace shell's third page: an interactive PTY terminal (设计文档 §8.2
// / SSH-3b). Only remote backends (SSH / Termux) can open a shell; SAF shows a
// hint instead. The shell is started lazily on an explicit「启动终端」tap so we
// never open a surprise SSH channel just by entering a workspace.
//
// 多 tab（双作用域设计稿 §3.3）：每个 tab 一个独立 PTY 会话，生命周期由
// 页面管理（与 AI 会话池分开）；新 tab 初始 cwd = workspace.root。
//
// dartssh2 is never imported here — the page talks to the backend-neutral
// [WorkspaceShellSession] (bytes in / bytes out), and xterm renders it.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:xterm/xterm.dart';

import 'package:aetherlink_flutter/features/terminal/application/terminal_engine_manager.dart';
import 'package:aetherlink_flutter/features/terminal/presentation/mobile/terminal_env_sheet.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_session_protocol.dart';

/// 单个终端 tab：独立的 xterm 缓冲 + PTY 会话与连接状态。
class _TerminalTab {
  _TerminalTab({required this.name});

  String name;
  final Terminal terminal = Terminal(maxLines: 10000);

  WorkspaceShellSession? session;
  StreamSubscription<String>? outSub;
  bool connecting = false;
  bool connected = false;
  String? error;

  Future<void> dispose() async {
    await outSub?.cancel();
    outSub = null;
    await session?.close();
    session = null;
  }
}

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
  final List<_TerminalTab> _tabs = [];
  int _active = 0;
  int _nextTabNumber = 1;

  _TerminalTab get _tab => _tabs[_active];

  @override
  void initState() {
    super.initState();
    _tabs.add(_TerminalTab(name: '${_nextTabNumber++}'));
    // 内置终端是本地进程，进页面直接启动；SSH/Termux 保持显式点按，
    // 避免一进工作区就悄悄开远程通道。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final workspace = ref.read(currentWorkspaceProvider);
      if (workspace?.backendType == WorkspaceBackendType.prootLocal) {
        _connect(_tabs.first);
      }
    });
  }

  @override
  void dispose() {
    for (final tab in _tabs) {
      tab.dispose();
    }
    super.dispose();
  }

  /// 内置终端自动挂载 /sdcard：首次连接时自动申请「所有文件访问」
  /// （低版本走传统存储权限），拒绝后不再反复打扰，终端照常可用。
  Future<void> _ensureStoragePermissionOnce() async {
    if (!Platform.isAndroid) return;
    if (await Permission.manageExternalStorage.isGranted) return;
    if (await Permission.storage.isGranted) return;
    final engine = TerminalEngineManager.instance;
    if (await engine.storagePermissionAsked()) return;
    await engine.markStoragePermissionAsked();
    if (!(await Permission.manageExternalStorage.request()).isGranted) {
      await Permission.storage.request();
    }
  }

  Future<void> _connect(_TerminalTab tab) async {
    final backend = ref.read(workspacePreviewBackendProvider);
    final workspace = ref.read(currentWorkspaceProvider);
    if (backend == null || workspace == null) return;
    if (workspace.backendType == WorkspaceBackendType.prootLocal) {
      await _ensureStoragePermissionOnce();
    }

    setState(() {
      tab.connecting = true;
      tab.error = null;
    });
    try {
      final session = await backend.startShell(
        columns: tab.terminal.viewWidth,
        rows: tab.terminal.viewHeight,
        workingDirectory: workspace.root,
      );
      // Wire xterm <-> session: keystrokes out, remote bytes in, size changes.
      tab.terminal.onOutput = (data) => session.write(utf8.encode(data));
      tab.terminal.onResize = (w, h, _, __) => session.resize(w, h);
      // cast 到 List<int>：Utf8Decoder 的 StreamTransformer 反化是
      // <List<int>, String>，Stream<Uint8List>.transform 在运行时泛型检查下
      // 会直接抛 type error。
      tab.outSub = session.output
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(tab.terminal.write);
      // L2 语言级隔离（设计稿 §4 P5）：开启时注入独立 HOME。
      final isolatedHome = workspace.isolatedHomePath;
      if (isolatedHome != null) {
        session.write(utf8.encode(buildSessionEnvSetup({'HOME': isolatedHome})));
      }
      session.done.whenComplete(() {
        if (!mounted) return;
        tab.terminal.write('\r\n\x1b[33m[会话已结束]\x1b[0m\r\n');
        setState(() => tab.connected = false);
      });
      // 页面已销毁或 tab 在连接期间被关闭 → 立即释放会话，避免 PTY 泄漏。
      if (!mounted || !_tabs.contains(tab)) {
        await session.close();
        return;
      }
      setState(() {
        tab.session = session;
        tab.connected = true;
        tab.connecting = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          tab.error = '$e';
          tab.connecting = false;
        });
      }
    }
  }

  Future<void> _disconnect(_TerminalTab tab) async {
    await tab.dispose();
    if (mounted) {
      setState(() => tab.connected = false);
    }
  }

  void _addTab() {
    final workspace = ref.read(currentWorkspaceProvider);
    final tab = _TerminalTab(name: '${_nextTabNumber++}');
    setState(() {
      _tabs.add(tab);
      _active = _tabs.length - 1;
    });
    // 内置终端新 tab 直接启动；远程后端保持显式点按。
    if (workspace?.backendType == WorkspaceBackendType.prootLocal) {
      _connect(tab);
    }
  }

  Future<void> _closeTab(int index) async {
    final tab = _tabs[index];
    if (_tabs.length == 1) {
      // 最后一个 tab 只断开，不移除（页面始终保留一个 tab）。
      await _disconnect(tab);
      return;
    }
    await tab.dispose();
    setState(() {
      _tabs.removeAt(index);
      if (_active >= _tabs.length) _active = _tabs.length - 1;
    });
  }

  Future<void> _renameTab(_TerminalTab tab) async {
    final controller = TextEditingController(text: tab.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名终端'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: '终端名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && mounted) {
      setState(() => tab.name = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workspace = ref.watch(currentWorkspaceProvider);
    final backend = ref.watch(workspacePreviewBackendProvider);
    final canExec = backend?.capabilities.canExec ?? false;
    final isProot = workspace?.backendType == WorkspaceBackendType.prootLocal;
    final topPad = MediaQuery.paddingOf(context).top + widget.topInset;
    final tab = _tab;

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
                if (tab.connected && isProot)
                  IconButton(
                    tooltip: '环境（apk 源 / 一键装）',
                    icon: const Icon(LucideIcons.package,
                        size: 18, color: Colors.white70),
                    onPressed: () => showTerminalEnvSheet(
                      context,
                      onRunCommand: (command) =>
                          tab.session?.write(utf8.encode('$command\n')),
                    ),
                  ),
                if (tab.connected)
                  IconButton(
                    tooltip: '断开',
                    icon: const Icon(LucideIcons.power,
                        size: 18, color: Colors.white70),
                    onPressed: () => _disconnect(tab),
                  ),
              ],
            ),
          ),
          // Tab strip：每 tab 一个独立 PTY 会话（双作用域设计稿 §3.3）。
          if (canExec && workspace != null)
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _tabs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) => _tabChip(index),
                    ),
                  ),
                  IconButton(
                    tooltip: '新建终端',
                    icon: const Icon(LucideIcons.plus,
                        size: 18, color: Colors.white70),
                    onPressed: _addTab,
                  ),
                ],
              ),
            ),
          Expanded(
            child: _body(theme,
                canExec: canExec, hasWorkspace: workspace != null),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(int index) {
    final tab = _tabs[index];
    final selected = index == _active;
    return GestureDetector(
      onTap: () => setState(() => _active = index),
      onLongPress: () => _renameTab(tab),
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
              LucideIcons.terminal,
              size: 13,
              color: tab.connected ? Colors.greenAccent : Colors.white38,
            ),
            const SizedBox(width: 6),
            Text(
              tab.name,
              style: TextStyle(
                fontSize: 13,
                color: selected ? Colors.white : Colors.white60,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _closeTab(index),
              child: const Icon(LucideIcons.x, size: 13, color: Colors.white38),
            ),
          ],
        ),
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
        text: '终端仅在内置终端 / SSH / Termux 工作区可用',
      );
    }
    final tab = _tab;
    if (tab.connected && tab.session != null) {
      // 不自动聚焦：进终端页不弹输入法；点按终端时 TerminalView 会自行
      // requestFocus 呼出键盘。IndexedStack 保活所有 tab 的渲染状态。
      return IndexedStack(
        index: _active,
        children: [
          for (final t in _tabs)
            TerminalView(
              t.terminal,
              padding: const EdgeInsets.all(8),
            ),
        ],
      );
    }
    if (tab.connecting) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    // Idle / errored: explicit connect affordance (lazy shell start).
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tab.error != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '连接失败 · ${tab.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            onPressed: () => _connect(tab),
            icon: const Icon(LucideIcons.terminal, size: 18),
            label: Text(tab.error == null ? '启动终端' : '重试'),
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
