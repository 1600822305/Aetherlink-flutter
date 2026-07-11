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
import 'package:aetherlink_flutter/features/terminal/presentation/mobile/terminal_env_page.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_restore.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_session_protocol.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/terminal_extra_keys.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

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

/// AI 长驻会话的联动视图：接入会话池里的会话，回放历史缓冲 +
/// 订阅实时输出；键入直接写进会话 stdin（用户可接管）。关闭视图只
/// 断开订阅，不关会话本身（会话生命周期归会话池 / AI 管）。
class _AiSessionView {
  _AiSessionView(this.session, {required String Function(String) transform}) {
    // 缓冲里就是 PTY 原始字节（含 \r\n 与 ANSI 序列），直接回放。
    terminal.write(session.snapshot());
    _sub = session.chunks.listen((chunk) {
      terminal.write(chunk);
    });
    terminal.onOutput = (data) {
      if (session.alive) session.writeInput(transform(data));
    };
  }

  final PooledWorkspaceSession session;
  final Terminal terminal = Terminal(maxLines: 10000);
  StreamSubscription<String>? _sub;

  Future<void> detach() async {
    await _sub?.cancel();
    _sub = null;
  }
}

/// 独立终端路由（/workspace/terminal）：复用 [WorkspaceTerminalPage]，
/// 返回直接 pop 回上一页（如聊天）。工作区页的进入流程被跳过了，
/// 所以先跑一遍上次工作区的自动恢复，再渲染终端页（否则 currentWorkspace
/// 为空，只会看到「请先打开一个工作区」）。
class TerminalRoutePage extends ConsumerStatefulWidget {
  const TerminalRoutePage({super.key});

  @override
  ConsumerState<TerminalRoutePage> createState() => _TerminalRoutePageState();
}

class _TerminalRoutePageState extends ConsumerState<TerminalRoutePage> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    restoreLastWorkspaceSession(ref).whenComplete(() {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14161B),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : WorkspaceTerminalPage(
              topInset: 0,
              onBack: () => Navigator.of(context).pop(),
            ),
    );
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

  /// 已接入的 AI 会话视图（按 sessionId）；[_activeAi] 非空时展示 AI 会话。
  final Map<String, _AiSessionView> _aiViews = {};
  String? _activeAi;
  WorkspaceSessionPoolManager? _poolManager;

  // Ctrl / Alt 粘滞键状态，接在每个会话的输入写入路径上（额外按键条）。
  final TerminalExtraKeysController _extraKeys = TerminalExtraKeysController();

  _TerminalTab get _tab => _tabs[_active];

  @override
  void initState() {
    super.initState();
    _tabs.add(_TerminalTab(name: '${_nextTabNumber++}'));
    final manager = ref.read(workspaceSessionPoolManagerProvider);
    manager.addListener(_onPoolChanged);
    _poolManager = manager;
    // 内置终端是本地进程，进页面直接启动；SSH/Termux 保持显式点按，
    // 避免一进工作区就悄悄开远程通道。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final workspace = ref.read(currentWorkspaceProvider);
      if (workspace?.backendType == WorkspaceBackendType.prootLocal) {
        _connect(_tabs.first);
      }
      _consumeFocusRequest();
    });
  }

  /// 消费聊天「在终端中查看」的请求：找到对应 AI 会话并打开其联动 tab。
  void _consumeFocusRequest() {
    final id = ref.read(terminalFocusSessionProvider);
    if (id == null) return;
    ref.read(terminalFocusSessionProvider.notifier).clear();
    final session = _poolManager?.find(id);
    if (session != null && session.alive) {
      _openAiSession(session);
    } else {
      AppToast.info(context, '该 AI 会话已结束或已回收');
    }
  }

  @override
  void dispose() {
    _poolManager?.removeListener(_onPoolChanged);
    for (final view in _aiViews.values) {
      view.detach();
    }
    for (final tab in _tabs) {
      tab.dispose();
    }
    _extraKeys.dispose();
    super.dispose();
  }

  /// AI 会话池变化（新建 / 关闭 / 回收）：刷新 chips，剔除已死会话的视图。
  void _onPoolChanged() {
    if (!mounted) return;
    // 会话池的 _prune 可能在本页 build 期间（allSessions）触发通知，
    // 延到帧末再 setState，避免 build 中重入。
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAiViews());
  }

  void _refreshAiViews() {
    if (!mounted) return;
    setState(() {
      _aiViews.removeWhere((id, view) {
        if (view.session.alive) return false;
        view.detach();
        return true;
      });
      if (_activeAi != null && !_aiViews.containsKey(_activeAi)) {
        _activeAi = null;
      }
    });
  }

  /// 当前工作区可联动的 AI 会话：本工作区的 + 内置终端默认池的
  /// （未锚定工作区，workspaceId == null，仅内置终端工作区展示）。
  List<PooledWorkspaceSession> _aiSessions(Workspace? workspace) {
    final manager = _poolManager;
    if (manager == null || workspace == null) return const [];
    final isProot = workspace.backendType == WorkspaceBackendType.prootLocal;
    return [
      for (final s in manager.allSessions())
        if (s.workspaceId == workspace.id ||
            (s.workspaceId == null && isProot))
          s,
    ];
  }

  void _openAiSession(PooledWorkspaceSession session) {
    setState(() {
      _aiViews.putIfAbsent(
        session.id,
        () => _AiSessionView(session, transform: _extraKeys.transform),
      );
      _activeAi = session.id;
    });
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
      // 输入先过额外按键条的 Ctrl / Alt 粘滞转换再写进 PTY。
      tab.terminal.onOutput =
          (data) => session.write(utf8.encode(_extraKeys.transform(data)));
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
      if (workspace.backendType == WorkspaceBackendType.prootLocal) {
        // 内置终端：设置带当前路径的提示符 + 清屏后打印工作区横幅
        // （clear 顺便抹掉前面注入命令的回显）。
        session.write(utf8.encode(
          buildProotGreeting(name: workspace.name, root: workspace.root),
        ));
      } else {
        // 远程后端不动对方 shell 配置，只在本地终端视图里写横幅。
        tab.terminal.write(
          '\x1b[1;36mAetherlink 终端\x1b[0m · ${workspace.name}\r\n'
          '目录: ${workspace.root}\r\n\r\n',
        );
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
      _activeAi = null;
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
    // 终端页已在前台时再次点「在终端中查看」：就地切到对应 AI 会话。
    ref.listen<String?>(terminalFocusSessionProvider, (prev, next) {
      if (next != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _consumeFocusRequest());
      }
    });
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
                    tooltip: '环境管理（镜像源 / 预设包）',
                    icon: const Icon(LucideIcons.package,
                        size: 18, color: Colors.white70),
                    onPressed: () => showTerminalEnvPage(
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
                    child: Builder(builder: (context) {
                      final aiSessions = _aiSessions(workspace);
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _tabs.length + aiSessions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, index) => index < _tabs.length
                            ? _tabChip(index)
                            : _aiChip(aiSessions[index - _tabs.length]),
                      );
                    }),
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

  /// AI 会话的 tab chip：机器人图标 + 会话名，点按接入实时围观。
  Widget _aiChip(PooledWorkspaceSession session) {
    final selected = _activeAi == session.id;
    return GestureDetector(
      onTap: () => _openAiSession(session),
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

  Widget _tabChip(int index) {
    final tab = _tabs[index];
    final selected = index == _active && _activeAi == null;
    return GestureDetector(
      onTap: () => setState(() {
        _active = index;
        _activeAi = null;
      }),
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
    // AI 会话围观优先：选中 AI chip 时展示其联动视图。
    final aiView = _activeAi == null ? null : _aiViews[_activeAi];
    if (aiView != null) {
      return Column(
        children: [
          Expanded(
            child: TerminalView(
              aiView.terminal,
              padding: const EdgeInsets.all(8),
            ),
          ),
          TerminalExtraKeysBar(
            controller: _extraKeys,
            terminal: aiView.terminal,
          ),
        ],
      );
    }
    final tab = _tab;
    if (tab.connected && tab.session != null) {
      // 不自动聚焦：进终端页不弹输入法；点按终端时 TerminalView 会自行
      // requestFocus 呼出键盘。IndexedStack 保活所有 tab 的渲染状态。
      return Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _active,
              children: [
                for (final t in _tabs)
                  TerminalView(
                    t.terminal,
                    padding: const EdgeInsets.all(8),
                  ),
              ],
            ),
          ),
          TerminalExtraKeysBar(
            controller: _extraKeys,
            terminal: tab.terminal,
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
