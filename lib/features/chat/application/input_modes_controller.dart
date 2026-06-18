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
