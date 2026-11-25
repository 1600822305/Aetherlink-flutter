// 会话池终端的共享 UI 层：工作区终端页与智能体工作台「终端」tab 共用
// 同一套「PooledWorkspaceSession ↔ xterm」联动逻辑与小组件，两处只做
// 布局壳的差异适配，功能（围观/接管/状态条/会话 chip/关闭）保持一致。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:xterm3/xterm.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';
import 'package:aetherlink_flutter/shared/widgets/page_swipe_lock.dart';

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

/// 终端拖选期间临时锁住所在翻页容器的横滑（[PageSwipeLock]）。
///
/// 只跟手指走、不存状态：有手指按着且（按下时已有选区 / 按着期间选区
/// 变化）就持有锁，最后一根手指抬起或取消即释放；销毁时必释放。
/// 选区之后留着不影响翻页。按下时已有选区也锁，是为了拖选区手柄时
/// 不被翻页抢走（手柄画在 Overlay 里，所以用全局指针路由监听手指）。
class TerminalSelectionPageLock extends StatefulWidget {
  const TerminalSelectionPageLock({
    super.key,
    required this.controller,
    required this.child,
  });

  final TerminalController? controller;
  final Widget child;

  @override
  State<TerminalSelectionPageLock> createState() =>
      _TerminalSelectionPageLockState();
}

class _TerminalSelectionPageLockState
    extends State<TerminalSelectionPageLock> {
  final Set<int> _pointers = {};
  PageSwipeLock? _lock;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onSelection);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lock = PageSwipeLock.maybeOf(context);
    if (identical(lock, _lock)) return;
    if (_holding) _lock?.release(this);
    _lock = lock;
    if (_holding) _lock?.acquire(this);
  }

  @override
  void didUpdateWidget(covariant TerminalSelectionPageLock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onSelection);
      widget.controller?.addListener(_onSelection);
      _setHolding(false);
    }
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    widget.controller?.removeListener(_onSelection);
    _lock?.release(this);
    super.dispose();
  }

  bool get _hasSelection => widget.controller?.selection != null;

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) {
      _pointers.add(event.pointer);
      if (_hasSelection) _setHolding(true);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
      if (_pointers.isEmpty) _setHolding(false);
    }
  }

  void _onSelection() {
    if (_pointers.isEmpty) return;
    _setHolding(_hasSelection);
  }

  void _setHolding(bool value) {
    if (value == _holding) return;
    _holding = value;
    value ? _lock?.acquire(this) : _lock?.release(this);
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
    terminal.onResize = (width, height, _, __) => session.resize(width, height);
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
