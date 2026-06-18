import 'package:flutter/widgets.dart';

import 'package:aetherlink_flutter/shared/domain/input_box_settings.dart';

/// The behavior port for the input-box toolbar buttons: a single seam the
/// [InputBoxComposer] talks to instead of carrying one callback per button.
///
/// The original crams every button's `onClick`, active flag and enabled flag
/// into one 366-line `useButtonToolbar` hook (`ButtonToolbar.tsx`) and then
/// re-declares the same actions a second and third time inside the 扩展 and
/// 添加内容 menus (`ToolsMenu.tsx` / `UploadMenu.tsx`). Routing every button
/// through this port lets one implementation own each action's behavior and
/// state once, so the standalone toolbar buttons and (later) the two aggregator
/// menus all dispatch through the same place.
///
/// The composer asks the port three things per button [id]:
///   * [isEnabled] — whether tapping does anything (a not-yet-wired button is
///     shown full-fidelity but is inert, matching the original's "即将支持");
///   * [isActive] — whether to paint the active-state styling (网络搜索 blue,
///     语音 red);
///   * [invoke] — run the action (only called when [isEnabled]).
///
/// The send button is intrinsic to the composer (its glyph/color swap with the
/// live send/stream state) and is not routed through this port.
abstract class InputBoxActions {
  /// Runs the action bound to [id]. Only called when [isEnabled] is true.
  /// [context] is the tapped button's element, for opening menus / sheets.
  void invoke(InputBoxButtonId id, BuildContext context);

  /// Whether [id] currently shows its active-state styling (e.g. 网络搜索 lit
  /// blue, 语音 lit red).
  bool isActive(InputBoxButtonId id);

  /// Whether tapping [id] does anything yet. A `false` button renders at full
  /// fidelity but is non-interactive.
  bool isEnabled(InputBoxButtonId id);
}

/// The inert port used by hosts with no wired behavior — the appearance
/// 输入框管理设置 preview, and the chat composer until the behavior slices land:
/// every button renders full-fidelity but is non-interactive and inactive.
class NoInputBoxActions implements InputBoxActions {
  const NoInputBoxActions();

  @override
  void invoke(InputBoxButtonId id, BuildContext context) {}

  @override
  bool isActive(InputBoxButtonId id) => false;

  @override
  bool isEnabled(InputBoxButtonId id) => false;
}
