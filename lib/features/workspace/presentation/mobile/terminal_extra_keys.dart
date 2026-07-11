// Termux 式终端额外按键条：软键盘打不出的键（Esc / Tab / Ctrl / Alt /
// 方向键 / Home / End / PgUp / PgDn 等）以一行可横滑的按键补上。
//
// 按键走 xterm 的 [Terminal.keyInput]，由 inputHandler 按终端模式（如 vim 的
// application cursor mode）生成正确的转义序列，再经 onOutput 流向会话。
// Ctrl / Alt 是粘滞键：点亮后对「下一次输入」生效——条上的键直接带修饰符，
// 软键盘敲的字符经 [TerminalExtraKeysController.transform]（接在会话写入
// 路径上）转成对应控制序列，用完即熄。方向键支持长按连发。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// Ctrl / Alt 粘滞键状态 + 软键盘输入的修饰转换。页面持有一个实例，接进
/// 每个会话的 onOutput → write 路径。
class TerminalExtraKeysController extends ChangeNotifier {
  bool ctrl = false;
  bool alt = false;

  void toggleCtrl() {
    ctrl = !ctrl;
    notifyListeners();
  }

  void toggleAlt() {
    alt = !alt;
    notifyListeners();
  }

  /// 用掉一次粘滞态（条上按键 / 软键盘字符发出后调用）。
  void consume() {
    if (!ctrl && !alt) return;
    ctrl = false;
    alt = false;
    notifyListeners();
  }

  /// 软键盘输入的修饰转换：Ctrl 点亮时把单个字符映射成对应控制字符
  /// （a-z → 0x01-0x1A，@[\]^_ 同理），Alt 点亮时加 ESC 前缀。只对
  /// 单字符输入生效（粘贴等多字符输入原样放行），转换后清掉粘滞态。
  String transform(String data) {
    if (!ctrl && !alt) return data;
    if (data.length != 1) return data;
    var out = data;
    if (ctrl) {
      final lower = data.toLowerCase().codeUnitAt(0);
      if (lower >= 0x61 && lower <= 0x7A) {
        // a-z → C0 控制字符
        out = String.fromCharCode(lower - 0x60);
      } else {
        final code = data.codeUnitAt(0);
        if (code >= 0x40 && code <= 0x5F) {
          // @ A-Z [ \ ] ^ _ → C0
          out = String.fromCharCode(code - 0x40);
        }
      }
    }
    if (alt) out = '\x1b$out';
    consume();
    return out;
  }
}

/// 额外按键条本体。持有当前活动的 [Terminal]（普通 tab 或 AI 会话视图的
/// 都行——它们的 onOutput 已各自接到对应会话）。
class TerminalExtraKeysBar extends StatelessWidget {
  const TerminalExtraKeysBar({
    super.key,
    required this.controller,
    required this.terminal,
  });

  final TerminalExtraKeysController controller;
  final Terminal terminal;

  void _sendKey(TerminalKey key) {
    terminal.keyInput(key, ctrl: controller.ctrl, alt: controller.alt);
    controller.consume();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1B1E24),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 38,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              children: [
                _Key(label: 'Esc', onTap: () => _sendKey(TerminalKey.escape)),
                _Key(label: 'Tab', onTap: () => _sendKey(TerminalKey.tab)),
                _Key(
                  label: 'Ctrl',
                  active: controller.ctrl,
                  onTap: controller.toggleCtrl,
                ),
                _Key(
                  label: 'Alt',
                  active: controller.alt,
                  onTap: controller.toggleAlt,
                ),
                _Key(
                  icon: Icons.keyboard_arrow_up,
                  repeatable: true,
                  onTap: () => _sendKey(TerminalKey.arrowUp),
                ),
                _Key(
                  icon: Icons.keyboard_arrow_down,
                  repeatable: true,
                  onTap: () => _sendKey(TerminalKey.arrowDown),
                ),
                _Key(
                  icon: Icons.keyboard_arrow_left,
                  repeatable: true,
                  onTap: () => _sendKey(TerminalKey.arrowLeft),
                ),
                _Key(
                  icon: Icons.keyboard_arrow_right,
                  repeatable: true,
                  onTap: () => _sendKey(TerminalKey.arrowRight),
                ),
                _Key(label: 'Home', onTap: () => _sendKey(TerminalKey.home)),
                _Key(label: 'End', onTap: () => _sendKey(TerminalKey.end)),
                _Key(label: 'PgUp', onTap: () => _sendKey(TerminalKey.pageUp)),
                _Key(label: 'PgDn', onTap: () => _sendKey(TerminalKey.pageDown)),
                _Key(label: '|', onTap: () => terminal.textInput('|')),
                _Key(label: '-', onTap: () => terminal.textInput('-')),
                _Key(label: '/', onTap: () => terminal.textInput('/')),
                _Key(label: '~', onTap: () => terminal.textInput('~')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 单个按键。[repeatable] 的键（方向键）按住 420ms 后以 90ms 间隔连发。
class _Key extends StatefulWidget {
  const _Key({
    this.label,
    this.icon,
    required this.onTap,
    this.active = false,
    this.repeatable = false,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool active;
  final bool repeatable;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  Timer? _repeat;

  void _startRepeat() {
    widget.onTap();
    _repeat = Timer.periodic(
      const Duration(milliseconds: 90),
      (_) => widget.onTap(),
    );
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.icon != null
        ? Icon(
            widget.icon,
            size: 18,
            color: widget.active ? Colors.white : Colors.white70,
          )
        : Text(
            widget.label!,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: widget.active ? Colors.white : Colors.white70,
              fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
            ),
          );
    final body = Container(
      alignment: Alignment.center,
      constraints: const BoxConstraints(minWidth: 40),
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: widget.active ? Colors.white24 : Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
    if (!widget.repeatable) {
      return GestureDetector(onTap: widget.onTap, child: body);
    }
    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: (_) => _startRepeat(),
      onLongPressEnd: (_) => _stopRepeat(),
      onLongPressCancel: _stopRepeat,
      child: body,
    );
  }
}
