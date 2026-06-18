import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/quick_phrases_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/input_modes_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/quick_phrase_sheet.dart';
import 'package:aetherlink_flutter/shared/domain/input_box_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/input_box_actions.dart';
import 'package:aetherlink_flutter/shared/widgets/input_box_menu_sheet.dart';

/// The chat composer's [InputBoxActions]: the single place that owns every
/// input-box action's behavior and state, replacing the original's three
/// independent copies (`ButtonToolbar` / `ToolsMenu` / `UploadMenu`).
///
/// Wired here (architecture + UI + persistence, no request layer): the two
/// aggregator buttons open the 扩展 / 添加内容 menus; the three mutually-exclusive
/// session modes (网络搜索 / 图像生成 / 视频生成) toggle via [InputModeController]; and the
/// three local actions — 新建话题 (create + switch topic), 清空内容 (two-step confirm
/// then clear the topic's messages) and 快捷短语 (insert a stored phrase at the
/// caret) — run against the existing sidebar/chat controllers. Every other
/// action surfaces 即将支持 until its slice lands, matching the message-toolbar
/// convention rather than faking a button.
///
/// Holds the host [WidgetRef] to `read` the controllers while the composer is
/// mounted, and an [insertText] callback supplied by the owner (which owns the
/// field's `TextEditingController`) for the 快捷短语 insert.
class ChatInputActions implements InputBoxActions {
  const ChatInputActions(this._ref, {required this.insertText});

  final WidgetRef _ref;

  /// Inserts text at the composer's caret — the 快捷短语 insert (port of
  /// `handleInsertPhrase`). Supplied by [ChatInputBar], which owns the field.
  final void Function(String content) insertText;

  InputMode? get _mode => _ref.read(inputModeControllerProvider);

  @override
  bool isActive(InputBoxAction action) => switch (action) {
    InputBoxAction.webSearch => _mode == InputMode.webSearch,
    InputBoxAction.generateImage => _mode == InputMode.image,
    InputBoxAction.generateVideo => _mode == InputMode.video,
    InputBoxAction.clearTopic => _ref.read(inputClearConfirmProvider),
    _ => false,
  };

  /// Every action the chat host knows about is interactive: it either runs (open
  /// a menu / toggle a mode / run a local action) or explains itself with 即将支持.
  /// The inert [NoInputBoxActions] (the appearance preview) is the one that
  /// disables.
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
      case InputBoxAction.newTopic:
        _newTopic();
      case InputBoxAction.clearTopic:
        // The standalone toolbar button's two-step confirm: the first tap arms
        // 确认清空 (the latch repaints the button), a second within 3s clears. The
        // 扩展 menu row runs its own independent confirm and calls the clear
        // directly, so it never reaches this latch.
        if (_ref.read(inputClearConfirmProvider.notifier).tap()) {
          _clearCurrentTopic();
        }
      case InputBoxAction.quickPhrase:
        _openQuickPhrase(context);
      case InputBoxAction.mcpTools:
      case InputBoxAction.knowledge:
      case InputBoxAction.photoSelect:
      case InputBoxAction.camera:
      case InputBoxAction.fileUpload:
      case InputBoxAction.note:
      case InputBoxAction.aiDebate:
      case InputBoxAction.multiModel:
      case InputBoxAction.voice:
        _comingSoon(context);
    }
  }

  void _toggle(InputMode mode) =>
      _ref.read(inputModeControllerProvider.notifier).toggle(mode);

  /// Creates a fresh topic for the current assistant and switches to it (port of
  /// `handleCreateTopic`); a no-op when no assistant exists. The opening menu has
  /// already closed by the time this runs.
  void _newTopic() {
    final assistant = _ref.read(currentAssistantProvider);
    if (assistant == null) return;
    _ref.read(topicsProvider.notifier).create(assistant.id);
  }

  /// Deletes every message of the current topic (port of `onClearTopic` →
  /// `clearMessages`); a no-op when no topic resolves.
  Future<void> _clearCurrentTopic() async {
    final topic = await _ref.read(currentTopicProvider.future);
    if (topic == null) return;
    await _ref.read(topicsProvider.notifier).clearMessages(topic.id);
  }

  void _openQuickPhrase(BuildContext context) =>
      showQuickPhraseSheet(context, onInsert: insertText);

  /// Opens [menu] as a bottom sheet. The 清空内容 row runs its own 二次确认 inside the
  /// sheet and pops [InputBoxAction.clearTopic] once confirmed (handled here as a
  /// direct clear); every other row pops its action to be re-dispatched through
  /// [invoke] (a row is never an aggregator, so this never recurses).
  Future<void> _openMenu(InputBoxMenu menu, BuildContext context) async {
    // 在输入框显示快捷短语按钮 gates only the 添加内容 menu's quick-phrase row (the
    // port of `UploadMenu`'s `showQuickPhrase`); the standalone toolbar button
    // and the 扩展 menu are unaffected.
    final hidden = <InputBoxAction>{
      if (!_ref.read(showQuickPhraseButtonProvider)) InputBoxAction.quickPhrase,
    };
    final selected = await showModalBottomSheet<InputBoxAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) =>
          InputBoxMenuSheet(menu: menu, actions: this, hidden: hidden),
    );
    if (selected == null || !context.mounted) return;
    if (selected == InputBoxAction.clearTopic) {
      _clearCurrentTopic();
    } else {
      invoke(selected, context);
    }
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('即将支持')));
  }
}
