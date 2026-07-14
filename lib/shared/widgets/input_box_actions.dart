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
/// The composer (and the two aggregator menus) ask the port three things per
/// [InputBoxAction]:
///   * [isEnabled] — whether tapping does anything (a host with no wiring keeps
///     every action inert, matching the original's "即将支持");
///   * [isActive] — whether to paint the active-state styling (网络搜索 blue,
///     图像/视频 mode lit);
///   * [invoke] — run the action (only called when [isEnabled]).
///
/// Actions are keyed by [InputBoxAction] rather than [InputBoxButtonId] so the
/// standalone toolbar buttons and the menu-only items (新建话题 / 添加笔记) share one
/// dispatch path. The send button is intrinsic to the composer (its glyph/color
/// swap with the live send/stream state) and is not routed through this port.
abstract class InputBoxActions {
  /// Runs [action]. Only called when [isEnabled] is true. [context] is the
  /// tapped element, used to open menus / sheets and surface snackbars.
  void invoke(InputBoxAction action, BuildContext context);

  /// Whether [action] currently shows its active-state styling (e.g. 网络搜索 lit
  /// blue, 图像生成 lit).
  bool isActive(InputBoxAction action);

  /// Whether tapping [action] does anything yet. A `false` action renders at
  /// full fidelity but is non-interactive.
  bool isEnabled(InputBoxAction action);

  /// Optional per-action glyph override for buttons whose icon reflects
  /// run-time state (e.g. 思考程度 shows the current effort level's icon).
  /// `null` keeps the static catalog glyph.
  IconData? iconOverride(InputBoxAction action);
}

/// The inert port used by hosts with no wired behavior — the appearance
/// 输入框管理设置 preview, and the chat composer until the behavior slices land:
/// every button renders full-fidelity but is non-interactive and inactive.
class NoInputBoxActions implements InputBoxActions {
  const NoInputBoxActions();

  @override
  void invoke(InputBoxAction action, BuildContext context) {}

  @override
  bool isActive(InputBoxAction action) => false;

  @override
  bool isEnabled(InputBoxAction action) => false;

  @override
  IconData? iconOverride(InputBoxAction action) => null;
}
