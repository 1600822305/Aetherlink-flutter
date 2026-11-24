// 会话池终端的共享 UI 层：工作区终端页与智能体工作台「终端」tab 共用
// 同一套「PooledWorkspaceSession ↔ xterm」联动逻辑与小组件，两处只做
// 布局壳的差异适配，功能（围观/接管/状态条/会话 chip/关闭）保持一致。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:xterm/xterm.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 复制当前选区（长按拖拽选中后点复制键）。
Future<void> copyTerminalSelection(
  BuildContext context,
  Terminal terminal,
  TerminalController controller,
) async {
  final range = controller.selection;
  if (range == null) {
    AppToast.info(context, '先长按选中要复制的内容');
    return;
  }
  final text = terminal.buffer.getText(range);
  controller.clearSelection();
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) AppToast.info(context, '已复制');
}

/// 粘贴剪贴板（走 bracketed paste，多行命令不会被逐行执行）。
Future<void> pasteClipboardToTerminal(
  BuildContext context,
  Terminal terminal,
) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text;
  if (text == null || text.isEmpty) {
    if (context.mounted) AppToast.info(context, '剪贴板为空');
    return;
  }
  terminal.paste(text);
}

/// 终端选区浮动菜单：长按选中（或拖拽扩展选区）松手后，在手指附近弹出
/// 「复制 / 粘贴 / 全选」。点按终端其他位置、选区被清空时自动收起。
class TerminalSelectionMenu extends StatefulWidget {
  const TerminalSelectionMenu({
    super.key,
    required this.terminal,
    required this.controller,
    required this.child,
  });

  final Terminal terminal;
  final TerminalController controller;
  final Widget child;

  @override
  State<TerminalSelectionMenu> createState() => _TerminalSelectionMenuState();
}

class _TerminalSelectionMenuState extends State<TerminalSelectionMenu> {
  Offset? _menuAt;
  Offset? _lastPointer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSelectionChanged);
  }

  @override
  void didUpdateWidget(covariant TerminalSelectionMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSelectionChanged);
      widget.controller.addListener(_onSelectionChanged);
      _menuAt = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    if (widget.controller.selection == null && _menuAt != null) {
      setState(() => _menuAt = null);
    }
  }

  void _onPointerDown(PointerDownEvent e) {
    _lastPointer = e.localPosition;
    if (_menuAt != null) setState(() => _menuAt = null);
  }

  void _onPointerUp(PointerUpEvent e) {
    _lastPointer = e.localPosition;
    // 等 xterm 手势处理完本次抬起再判断是否留下了选区。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.controller.selection != null) {
        HapticFeedback.selectionClick();
        setState(() => _menuAt = _lastPointer);
      }
    });
  }

  Future<void> _copy() async {
    setState(() => _menuAt = null);
    await copyTerminalSelection(context, widget.terminal, widget.controller);
  }

  Future<void> _paste() async {
    setState(() => _menuAt = null);
    widget.controller.clearSelection();
    await pasteClipboardToTerminal(context, widget.terminal);
  }

  void _selectAll() {
    final buffer = widget.terminal.buffer;
    widget.controller.setSelection(
      buffer.createAnchor(0, 0),
      buffer.createAnchor(widget.terminal.viewWidth, buffer.height - 1),
    );
    setState(() {}); // 菜单保持显示，位置不变。
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final at = _menuAt;
        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _onPointerDown,
                onPointerUp: _onPointerUp,
                child: widget.child,
              ),
            ),
            if (at != null) _buildMenu(at, constraints.biggest),
          ],
        );
      },
    );
  }

  Widget _buildMenu(Offset at, Size size) {
    const menuWidth = 216.0;
    const menuHeight = 40.0;
    const gap = 48.0; // 避开手指遮挡
    final left = (at.dx - menuWidth / 2).clamp(4.0, size.width - menuWidth - 4);
    var top = at.dy - menuHeight - gap;
    if (top < 4) top = at.dy + gap; // 上方放不下则放到下方
    top = top.clamp(4.0, size.height - menuHeight - 4);
    return Positioned(
      left: left.toDouble(),
      top: top.toDouble(),
      width: menuWidth,
      height: menuHeight,
      child: Material(
        color: const Color(0xFF2C2C2E),
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            _MenuItem(label: '复制', onTap: _copy),
            _MenuItem(label: '粘贴', onTap: _paste),
            _MenuItem(label: '全选', onTap: _selectAll),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

/// 会话池会话的联动视图状态：接入会话回放历史缓冲 + 订阅实时输出，
/// 键入直接写进会话 stdin（用户可接管）。detach 只断订阅，不关会话
/// 本身（会话生命周期归会话池 / AI 管）。
class SessionTerminalAttachment {
  SessionTerminalAttachment(
    this.session, {
    String Function(String)? transform,
  }) {
    final history = session.snapshot();
    _sub = session.chunks.listen(_onChunk);
    terminal.onOutput = (data) {
      if (session.alive) {
        session.writeUserInput(transform == null ? data : transform(data));
      }
    };
    terminal.onResize = (width, height, _, __) =>
        session.resize(width, height);
    // 历史可达数百 KB，构造常发生在 build 里：推迟到事件循环下一轮再
    // 回放，期间到达的实时输出先暂存，保证与历史的先后顺序。
    ready = Future<void>(() {
      final pending = _pending;
      _pending = null;
      if (pending == null) return;
      // 缓冲里就是 PTY 原始字节（含 \r\n 与 ANSI 序列），直接回放。
      terminal.write(history);
      pending.forEach(terminal.write);
    });
  }

  final PooledWorkspaceSession session;
  final Terminal terminal = Terminal(maxLines: 10000);
  final TerminalController controller = TerminalController();
  final FocusNode focusNode = FocusNode();
  StreamSubscription<String>? _sub;
  List<String>? _pending = [];

  /// 历史回放完成（detach 早于回放时直接完成、不再回放）。
  late final Future<void> ready;

  void _onChunk(String data) {
    final pending = _pending;
    if (pending != null) {
      pending.add(data);
    } else {
      terminal.write(data);
    }
  }

  Future<void> detach() async {
    _pending = null;
    terminal.onOutput = null;
    terminal.onResize = null;
    final sub = _sub;
    _sub = null;
    // 当前帧的 TerminalView 可能仍持有 focusNode / controller，帧末再释放。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      focusNode.dispose();
      controller.dispose();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
    await sub?.cancel();
  }
}

/// AI 会话围观视图顶部的状态条：实时显示会话是否被 AI 命令占用，
/// 让用户知道此刻键入会不会打进 AI 正在跑的命令；忙时提供一键中断。
class AiSessionStatusBar extends StatelessWidget {
  const AiSessionStatusBar({required this.session, super.key});

  final PooledWorkspaceSession session;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: session.busyListenable,
      builder: (context, busy, _) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        color: busy ? const Color(0xFF3A2E12) : const Color(0xFF16281B),
        child: Row(
          children: [
            Icon(
              busy ? LucideIcons.loader : LucideIcons.check,
              size: 13,
              color: busy ? Colors.amberAccent : Colors.greenAccent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                busy ? 'AI 命令执行中 · 此刻键入会打进该命令的 stdin' : '会话空闲 · 可直接键入接管',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: busy ? Colors.amberAccent : Colors.white60,
                ),
              ),
            ),
            if (busy)
              GestureDetector(
                onTap: () {
                  try {
                    session.interrupt();
                  } on WorkspaceSessionException catch (e) {
                    AppToast.info(context, e.message);
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '中断',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 会话池会话的 tab chip：机器人图标（忙碌琥珀色 / 空闲绿色）+ 会话名；
/// 长按可手动关闭会话（确认后释放池位）。
class SessionChip extends StatelessWidget {
  const SessionChip({
    required this.session,
    required this.selected,
    required this.onTap,
    this.onClose,
    super.key,
  });

  final PooledWorkspaceSession session;
  final bool selected;
  final VoidCallback onTap;

  /// 非空时长按弹确认，确认后回调（调用方负责真正 close）。
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onClose == null ? null : () => _confirmClose(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? Colors.white38 : Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: session.busyListenable,
              builder: (context, busy, _) => Icon(
                LucideIcons.bot,
                size: 13,
                color: busy ? Colors.amberAccent : Colors.greenAccent,
              ),
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

  Future<void> _confirmClose(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关闭会话'),
        content: Text(
          session.busy
              ? '会话「${session.name}」正有命令在跑，关闭会终止它并释放池位。确定关闭？'
              : '关闭会话「${session.name}」并释放池位？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    if (confirmed == true) onClose!();
  }
}
