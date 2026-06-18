import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'input_modes_controller.g.dart';

/// The three mutually-exclusive input-box session modes (port of
/// `useExclusiveMode`'s `ExclusiveMode`): 网络搜索 / 图像生成 / 视频生成.
enum InputMode { webSearch, image, video }

/// The active input-box session mode, or `null` for none.
///
/// Mutually exclusive and held purely in memory — toggling one on turns any
/// other off, and a full restart resets to `null`. This deliberately mirrors
/// the web, where these live in a component `useState<ExclusiveMode>(null)`
/// (not persisted), and follows the same session-only policy as the sidebar
/// tab. The MCP 工具 switch is the original's persisted toggle and is **not**
/// one of these modes.
@Riverpod(keepAlive: true)
class InputModeController extends _$InputModeController {
  @override
  InputMode? build() => null;

  /// Toggles [mode]: turns it on (turning any other mode off) or, if it is
  /// already active, back to none — the port of `toggleMode`.
  void toggle(InputMode mode) => state = state == mode ? null : mode;

  void clear() => state = null;
}

/// The standalone 清空内容 button's two-step confirm latch — the port of the web
/// `clearConfirmMode` `useState` shared by `ButtonToolbar` / `ToolsMenu`.
///
/// `true` while the button is armed: the first tap arms it (the glyph swaps to a
/// red `AlertTriangle` and the label to 确认清空) and a second tap within 3 seconds
/// performs the clear; otherwise it disarms itself. Held in memory only — a
/// restart leaves it disarmed. The 扩展 menu runs its own independent confirm
/// (sheet-local) so opening the menu never arms the toolbar button.
@Riverpod(keepAlive: true)
class InputClearConfirm extends _$InputClearConfirm {
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    return false;
  }

  /// Registers a tap. Returns `true` when this tap should perform the clear (it
  /// was already armed); `false` when it merely armed the confirm.
  bool tap() {
    if (state) {
      _disarm();
      return true;
    }
    state = true;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), _disarm);
    return false;
  }

  void _disarm() {
    _timer?.cancel();
    _timer = null;
    if (state) state = false;
  }
}
