import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/chat/application/input_modes_controller.dart';
import 'package:aetherlink_flutter/shared/domain/input_box_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/input_box_actions.dart';
import 'package:aetherlink_flutter/shared/widgets/input_box_menu_sheet.dart';

/// The chat composer's [InputBoxActions]: the single place that owns every
/// input-box action's behavior and state, replacing the original's three
/// independent copies (`ButtonToolbar` / `ToolsMenu` / `UploadMenu`).
///
/// What is wired in this slice (architecture + UI + session state, no request
/// layer): the two aggregator buttons open the 扩展 / 添加内容 menus (the same
/// [InputBoxMenuSheet] for both), and the three mutually-exclusive session modes
/// (网络搜索 / 图像生成 / 视频生成) toggle via [InputModeController]. Every other action —
/// whether reached from a standalone toolbar button or a menu row — surfaces
/// 即将支持, matching the message-toolbar convention rather than faking a button.
///
/// Holds the host [WidgetRef] only to `read` the session-mode notifier while the
/// composer is mounted; the owning widget watches [inputModeControllerProvider]
/// so toggles rebuild the toolbar (and re-tint any standalone mode button).
class ChatInputActions implements InputBoxActions {
  const ChatInputActions(this._ref);

  final WidgetRef _ref;

  InputMode? get _mode => _ref.read(inputModeControllerProvider);

  @override
  bool isActive(InputBoxAction action) => switch (action) {
    InputBoxAction.webSearch => _mode == InputMode.webSearch,
    InputBoxAction.generateImage => _mode == InputMode.image,
    InputBoxAction.generateVideo => _mode == InputMode.video,
    _ => false,
  };

  /// Every action the chat host knows about is interactive: it either runs (open
  /// a menu / toggle a mode) or explains itself with 即将支持. The inert
  /// [NoInputBoxActions] (the appearance preview) is the one that disables.
  @override
  bool isEnabled(InputBoxAction action) => true;

  @override
  void invoke(InputBoxAction action, BuildContext context) {
    switch (action) {
      case InputBoxAction.toolsMenu:
        _openMenu(InputBoxMenu.tools, context);
      case InputBoxAction.uploadMenu:
        _openMenu(InputBoxMenu.upload, context);
      case InputBoxAction.webSearch:
        _toggle(InputMode.webSearch);
      case InputBoxAction.generateImage:
        _toggle(InputMode.image);
      case InputBoxAction.generateVideo:
        _toggle(InputMode.video);
      case InputBoxAction.mcpTools:
      case InputBoxAction.newTopic:
      case InputBoxAction.clearTopic:
      case InputBoxAction.knowledge:
      case InputBoxAction.photoSelect:
      case InputBoxAction.camera:
      case InputBoxAction.fileUpload:
      case InputBoxAction.note:
      case InputBoxAction.aiDebate:
      case InputBoxAction.quickPhrase:
      case InputBoxAction.multiModel:
      case InputBoxAction.voice:
        _comingSoon(context);
    }
  }

  void _toggle(InputMode mode) =>
      _ref.read(inputModeControllerProvider.notifier).toggle(mode);

  /// Opens [menu] as a bottom sheet; the chosen row is re-dispatched through
  /// [invoke] (a row is never an aggregator, so this never recurses).
  Future<void> _openMenu(InputBoxMenu menu, BuildContext context) async {
    final selected = await showModalBottomSheet<InputBoxAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => InputBoxMenuSheet(menu: menu, actions: this),
    );
    if (selected != null && context.mounted) invoke(selected, context);
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('即将支持')));
  }
}
