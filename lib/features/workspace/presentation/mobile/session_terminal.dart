// 会话池终端的共享 UI 层：工作区终端页与智能体工作台「终端」tab 共用
// 同一套「PooledWorkspaceSession ↔ xterm」联动逻辑与小组件，两处只做
// 布局壳的差异适配，功能（围观/接管/状态条/会话 chip/关闭）保持一致。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:xterm/xterm.dart';

import 'package:aetherlink_flutter/app/di/message_selection_access.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';
import 'package:aetherlink_flutter/shared/domain/selection_menu_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 复制当前选区（长按拖拽选中后点复制键）。
Future<void> copyTerminalSelection(
  BuildContext context,
  Terminal terminal,
  TerminalController controller,
) async {
  final range = controller.selection;
  if (range == null) {
    if (!TerminalSelectionMenu.enterSelectMode(controller)) {
      AppToast.info(context, '先长按选中要复制的内容');
    }
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

/// 终端「选择文本」模式：交互与聊天消息一致。
///
/// xterm 是画布渲染，没有系统文本选区（手柄 / 放大镜 / 复制面板）。这里在
/// 长按选中（或点快捷栏「复制」）时，把终端缓冲区转成等宽纯文本覆盖在终端
/// 上，外面包聊天同款 [MessageSelectionArea]：系统选区手柄可拖、复制面板
/// （复制 / 全选 / 引用 / 分享，跟随 外观设置 → 复制面板 配置）完全复用。
/// 点「完成」或返回键退出，回到正常终端。
class TerminalSelectionMenu extends StatefulWidget {
  const TerminalSelectionMenu({
    super.key,
    required this.terminal,
    required this.controller,
    required this.builder,
    this.fontSize = 13,
  });

  final Terminal terminal;
  final TerminalController controller;
  final Widget Function(GlobalKey<TerminalViewState> viewKey) builder;
  final double fontSize;

  /// controller → 已挂载的选择层，供快捷栏「复制」键在无选区时进入选择模式。
  static final Map<TerminalController, _TerminalSelectionMenuState> _byController =
      {};

  /// 进入选择模式；没有挂载对应选择层时返回 false。
  static bool enterSelectMode(TerminalController controller) {
    final state = _byController[controller];
    if (state == null || !state.mounted) return false;
    state._enter();
    return true;
  }

  @override
  State<TerminalSelectionMenu> createState() => _TerminalSelectionMenuState();
}

class _TerminalSelectionMenuState extends State<TerminalSelectionMenu> {
  /// 选择模式最多展示的尾部行数（全量上万行的单个 Text 选区太重）。
  static const _maxLines = 3000;

  final _viewKey = GlobalKey<TerminalViewState>();
  final _scroll = ScrollController();
  String? _text; // 非 null 即处于选择模式

  @override
  void initState() {
    super.initState();
    _attach(widget.controller);
  }

  @override
  void didUpdateWidget(covariant TerminalSelectionMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detach(oldWidget.controller);
      _attach(widget.controller);
      _text = null;
    }
  }

  @override
  void dispose() {
    _detach(widget.controller);
    _scroll.dispose();
    super.dispose();
  }

  void _attach(TerminalController c) {
    c.addListener(_onSelectionChanged);
    TerminalSelectionMenu._byController[c] = this;
  }

  void _detach(TerminalController c) {
    c.removeListener(_onSelectionChanged);
    if (TerminalSelectionMenu._byController[c] == this) {
      TerminalSelectionMenu._byController.remove(c);
    }
  }

  // xterm 长按产生选区 → 转入选择模式（xterm 自己的选区随即清掉）。
  void _onSelectionChanged() {
    if (_text == null && widget.controller.selection != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _text == null) _enter();
      });
    }
  }

  void _enter() {
    widget.controller.clearSelection();
    var lines = widget.terminal.buffer.getText().split('\n');
    // 去掉行尾补齐空格与末尾空行。
    lines = [for (final l in lines) l.trimRight()];
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    if (lines.length > _maxLines) {
      lines = lines.sublist(lines.length - _maxLines);
    }
    HapticFeedback.selectionClick();
    setState(() => _text = lines.join('\n'));
    // 默认停在底部（与终端当前视口一致的最新输出）。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _exit() => setState(() => _text = null);

  @override
  Widget build(BuildContext context) {
    final text = _text;
    final terminalView = widget.builder(_viewKey);
    if (text == null) return terminalView;
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Stack(
        children: [
          // 保留终端在下层（不销毁、不断开），只是被覆盖。
          Positioned.fill(child: ExcludeFocus(child: terminalView)),
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFF000000),
              child: Column(
                children: [
                  Container(
                    height: 36,
                    color: theme.colorScheme.surfaceContainerHigh,
                    padding: const EdgeInsets.only(left: 12),
                    child: Row(
                      children: [
                        Icon(LucideIcons.textSelect,
                            size: 16, color: theme.colorScheme.onSurface),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '选择文本 · 长按拖动选区',
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                        TextButton(onPressed: _exit, child: const Text('完成')),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: _scroll,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(8),
                        child: MessageSelectionArea(
                          allowedItemIds: const {
                            kSelectionMenuCopy,
                            kSelectionMenuSelectAll,
                          },
                          child: Text(
                            text,
                            softWrap: true,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: widget.fontSize,
                              height: 1.25,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
