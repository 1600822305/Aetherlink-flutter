import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/behavior_settings_access.dart';
import 'package:aetherlink_flutter/app/di/input_box_access.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/widgets/input_box_composer.dart';

const String _noModelHint = '请先配置模型';

/// The bottom composer for the chat page: a 1:1 port of the original
/// `IntegratedChatInput`. The visuals live in the shared [InputBoxComposer] so
/// the appearance 输入框管理设置 page previews the exact same widget; this wrapper
/// supplies the chat-specific wiring (the text controller, the send action, and
/// the live input-box configuration from the settings store).
///
/// The send button is wired: it lights up once a current chat model with an API
/// key is configured and the field is non-empty, and a tap hands the text to
/// [ChatController.send]. With no model configured it stays disabled and a tap
/// surfaces the "configure a model first" hint.
///
/// The remaining feature buttons are full-fidelity visuals with their behaviors
/// not yet implemented; their actions are exposed as the [onToolsMenu] /
/// [onClearTopic] / [onToggleWebSearch] / [onAddContent] / [onToggleVoice]
/// callbacks (null ⇒ the button renders but does nothing), so a later slice can
/// wire them without touching this widget. [webSearchActive] / [voiceActive]
/// drive the active-state styling those buttons take once wired.
class ChatInputBar extends ConsumerStatefulWidget {
  const ChatInputBar({
    super.key,
    this.onToolsMenu,
    this.onClearTopic,
    this.onToggleWebSearch,
    this.onAddContent,
    this.onToggleVoice,
    this.webSearchActive = false,
    this.voiceActive = false,
  });

  /// Opens the "扩展" (tools/extensions) menu.
  final VoidCallback? onToolsMenu;

  /// Clears the current topic's content.
  final VoidCallback? onClearTopic;

  /// Toggles web-search mode.
  final VoidCallback? onToggleWebSearch;

  /// Opens the "添加内容" (upload) menu.
  final VoidCallback? onAddContent;

  /// Toggles voice-input mode.
  final VoidCallback? onToggleVoice;

  /// Whether web-search mode is active (drives the search button's blue tint).
  final bool webSearchActive;

  /// Whether voice-input mode is active (drives the voice button's red glyph).
  final bool voiceActive;

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  late final FocusNode _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
  bool _hasText = false;

  /// Cached in [build] so the synchronous [_handleKeyEvent] can decide whether a
  /// hardware Enter should fire a send without re-deriving model/stream state.
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  /// Hardware-keyboard Enter handling (port of `useChatInputLogic.handleKeyDown`):
  /// Shift+Enter always inserts a newline; a plain Enter sends when
  /// `sendWithEnter` is on (and, on mobile, 回车换行 isn't forced). When sending
  /// is enabled we always consume the key so no stray newline is inserted, even
  /// if the field can't send yet (empty / no model / streaming) — matching the
  /// original's unconditional `preventDefault`. The mobile soft keyboard is
  /// handled separately via [InputBoxComposer]'s text input action.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final behavior = ref.read(appBehaviorSettingsProvider);
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (isMobile && behavior.mobileInputMethodEnterAsNewline) {
      return KeyEventResult.ignored;
    }
    if (!behavior.sendWithEnter) return KeyEventResult.ignored;
    if (_canSend) _send();
    return KeyEventResult.handled;
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    setState(() => _hasText = false);
    ref.read(chatControllerProvider.notifier).send(text);
  }

  void _showNoModelHint() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(_noModelHint)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appInputBoxSettingsProvider);
    final behavior = ref.watch(appBehaviorSettingsProvider);

    final CurrentModel? current = ref.watch(appCurrentModelProvider).value;
    final hasApiKey =
        (current?.model.apiKey?.isNotEmpty ?? false) ||
        (current?.provider.apiKey?.isNotEmpty ?? false);
    final modelReady = current != null && hasApiKey;
    final isStreaming =
        ref.watch(chatControllerProvider).value?.isStreaming ?? false;
    final canSend = modelReady && _hasText && !isStreaming;
    _canSend = canSend;

    return InputBoxComposer(
      settings: settings,
      controller: _controller,
      focusNode: _focusNode,
      sendWithEnter: behavior.sendWithEnter,
      enterAsNewline: behavior.mobileInputMethodEnterAsNewline,
      canSend: canSend,
      isStreaming: isStreaming,
      // No model ⇒ a tap surfaces the hint; otherwise the field/streaming state
      // decides whether the send action fires.
      onSend: canSend ? _send : (modelReady ? null : _showNoModelHint),
      onToolsMenu: widget.onToolsMenu,
      onClearTopic: widget.onClearTopic,
      onToggleWebSearch: widget.onToggleWebSearch,
      onAddContent: widget.onAddContent,
      onToggleVoice: widget.onToggleVoice,
      webSearchActive: widget.webSearchActive,
      voiceActive: widget.voiceActive,
    );
  }
}
