import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/behavior_settings_access.dart';
import 'package:aetherlink_flutter/app/di/input_box_access.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/composer_attachments_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/input_modes_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/long_text_paste.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/composer_attachment.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_input_actions.dart';
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
/// The remaining feature buttons route through a [ChatInputActions]: the 扩展 /
/// 添加内容 buttons open their aggregator menus and 网络搜索 / 图像生成 / 视频生成 toggle
/// their mutually-exclusive session mode; everything else still surfaces
/// 即将支持 until its behavior slice lands.
class ChatInputBar extends ConsumerStatefulWidget {
  const ChatInputBar({super.key});

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
    final attachments = ref.read(composerAttachmentsProvider);
    if (text.trim().isEmpty && attachments.isEmpty) return;
    _controller.clear();
    ref.read(composerAttachmentsProvider.notifier).clear();
    setState(() => _hasText = false);
    ref
        .read(chatControllerProvider.notifier)
        .send(text, attachments: attachments);
  }

  /// Paste interceptor (port of `LongTextPasteService.handleTextPaste`): when
  /// 长文本粘贴为文件 is on and the pasted text is longer than the threshold, it is
  /// converted to a pending `.txt` attachment and consumed (returns `true`);
  /// otherwise it falls through to a normal paste.
  Future<bool> _handlePaste(String text) async {
    final settings = ref.read(sidebarSettingsControllerProvider);
    final attachment = convertPastedTextToAttachment(
      text: text,
      enabled: settings.pasteLongTextAsFile,
      threshold: settings.pasteLongTextThreshold,
    );
    if (attachment == null) return false;
    ref.read(composerAttachmentsProvider.notifier).add(attachment);
    return true;
  }

  void _showNoModelHint() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(_noModelHint)));
  }

  /// Inserts a 快捷短语's content at the caret and leaves the caret just after it
  /// (port of `handleInsertPhrase`). Falls back to appending when the field has
  /// never held a selection.
  void _insertPhrase(String content) {
    final value = _controller.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final next = text.replaceRange(start, end, content);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + content.length),
    );
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appInputBoxSettingsProvider);
    final behavior = ref.watch(appBehaviorSettingsProvider);
    // Watched so toggling a session mode rebuilds the toolbar (re-tinting any
    // standalone 网络搜索/图像/视频 button); [ChatInputActions] reads the value lazily.
    ref.watch(inputModeControllerProvider);
    // Watched so arming/disarming 清空内容's confirm repaints the standalone button
    // (确认清空 / red AlertTriangle); the action reads the latch lazily.
    ref.watch(inputClearConfirmProvider);

    final CurrentModel? current = ref.watch(appCurrentModelProvider).value;
    final hasApiKey =
        (current?.model.apiKey?.isNotEmpty ?? false) ||
        (current?.provider.apiKey?.isNotEmpty ?? false);
    final modelReady = current != null && hasApiKey;
    final isStreaming =
        ref.watch(chatControllerProvider).value?.isStreaming ?? false;
    final attachments = ref.watch(composerAttachmentsProvider);
    // A lone pasted-as-file attachment (no typed text) can still be sent.
    final canSend =
        modelReady && (_hasText || attachments.isNotEmpty) && !isStreaming;
    _canSend = canSend;

    return InputBoxComposer(
      settings: settings,
      controller: _controller,
      focusNode: _focusNode,
      sendWithEnter: behavior.sendWithEnter,
      enterAsNewline: behavior.mobileInputMethodEnterAsNewline,
      canSend: canSend,
      isStreaming: isStreaming,
      actions: ChatInputActions(ref, insertText: _insertPhrase),
      onPasteText: _handlePaste,
      attachmentsBar: attachments.isEmpty
          ? null
          : _ComposerAttachmentChips(
              attachments: attachments,
              onRemove: (id) =>
                  ref.read(composerAttachmentsProvider.notifier).removeById(id),
            ),
      // No model ⇒ a tap surfaces the hint; otherwise the field/streaming state
      // decides whether the send action fires.
      onSend: canSend ? _send : (modelReady ? null : _showNoModelHint),
    );
  }
}

/// The pending-attachment chips shown above the field: one compact chip per
/// staged file (icon + name + size) with a ✕ to drop it. Mirrors the original's
/// converted-file chips in the input box.
class _ComposerAttachmentChips extends StatelessWidget {
  const _ComposerAttachmentChips({
    required this.attachments,
    required this.onRemove,
  });

  final List<ComposerAttachment> attachments;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final attachment in attachments)
          Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.fileText,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    attachment.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatBytes(attachment.size),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 2),
                InkResponse(
                  radius: 14,
                  onTap: () => onRemove(attachment.id),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      LucideIcons.x,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Human-readable byte size (port of the FILE block's `formatFileSize`).
  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final value = unit == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
    return '$value ${units[unit]}';
  }
}
