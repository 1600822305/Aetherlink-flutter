import 'dart:convert';

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
import 'package:aetherlink_flutter/features/chat/application/mcp_tools_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/multi_model_mentions_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/long_text_paste.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/composer_attachment.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_input_actions.dart';
import 'package:aetherlink_flutter/features/chat/application/parameter_settings_controller.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';
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

  /// Inserts text at the composer caret from outside the widget tree — wired
  /// by the mounted composer state, used by the message selection 复制面板's
  /// 引用到输入框 action. Null when no chat composer is on screen.
  static void Function(String content)? insertTextHook;

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  late final FocusNode _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
  bool _hasText = false;

  /// The field text as of the last change, so [_onTextChanged] can diff a step
  /// to spot a pasted run; and a guard so the cleanup write we make when
  /// converting one doesn't re-enter the detector.
  String _lastText = '';
  bool _interceptingPaste = false;

  /// Cached in [build] so the synchronous [_handleKeyEvent] can decide whether a
  /// hardware Enter should fire a send without re-deriving model/stream state.
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _lastText = _controller.text;
    _controller.addListener(_onTextChanged);
    ChatInputBar.insertTextHook = _insertPhrase;
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
    _maybeInterceptPastedRun();
  }

  /// Catch-all for paste paths that bypass both `PasteTextIntent` and the
  /// context menu (notably the mobile IME clipboard chip, which commits text
  /// straight through the input connection): when 长文本粘贴为文件 is on and a single
  /// edit drops in a run longer than the threshold, pull it back out of the
  /// field and stage it as a file instead.
  ///
  /// On desktop we verify the inserted run matches the system clipboard so a
  /// long programmatic insert is left alone. On mobile the IME clipboard
  /// history commits text directly through the input connection without
  /// updating the system clipboard, so the verification is skipped — the
  /// threshold alone is sufficient (predictive text never inserts that much).
  Future<void> _maybeInterceptPastedRun() async {
    if (_interceptingPaste) return;
    final oldText = _lastText;
    final newText = _controller.text;
    _lastText = newText;

    final settings = ref.read(sidebarSettingsControllerProvider);
    if (!settings.pasteLongTextAsFile) return;
    if (newText.length - oldText.length <= settings.pasteLongTextThreshold) {
      return;
    }
    final insertion = detectInsertion(oldText, newText);
    if (insertion == null ||
        insertion.inserted.length <= settings.pasteLongTextThreshold) {
      return;
    }
    // On desktop, verify the run matches the system clipboard so a long
    // programmatic insert is left alone. On mobile, skip — the IME clipboard
    // history doesn't sync with the system clipboard.
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isMobile) {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      if (clip?.text != insertion.inserted) return;
    }
    final attachment = convertPastedTextToAttachment(
      text: insertion.inserted,
      enabled: settings.pasteLongTextAsFile,
      threshold: settings.pasteLongTextThreshold,
    );
    if (attachment == null || !mounted) return;

    _interceptingPaste = true;
    ref.read(composerAttachmentsProvider.notifier).add(attachment);
    _controller.value = TextEditingValue(
      text: insertion.restored,
      selection: TextSelection.collapsed(offset: insertion.caret),
    );
    _lastText = insertion.restored;
    _interceptingPaste = false;
  }

  @override
  void dispose() {
    if (ChatInputBar.insertTextHook == _insertPhrase) {
      ChatInputBar.insertTextHook = null;
    }
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    final attachments = ref.read(composerAttachmentsProvider);
    if (text.trim().isEmpty && attachments.isEmpty) return;
    // Dismiss keyboard before sending (original: smartHandleSubmit →
    // hideKeyboard() → activeElement.blur()).
    _focusNode.unfocus();
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
    AppToast.warning(context, _noModelHint);
  }

  /// Sends a tapped 建议 (follow-up suggestion) as a new user message. A no-op
  /// while streaming; sending clears the suggestions via the controller's state
  /// rebuild.
  void _sendSuggestion(String text) {
    if (text.trim().isEmpty) return;
    final isStreaming =
        ref.read(chatControllerProvider).value?.isStreaming ?? false;
    if (isStreaming) return;
    ref.read(chatControllerProvider.notifier).send(text);
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
    // Watched so toggling the MCP 工具 总开关 repaints the standalone MCP button
    // (green when enabled); [ChatInputActions] reads the value lazily.
    ref.watch(mcpToolsControllerProvider);
    // Watched so changing the reasoning-effort level repaints the standalone
    // 思考程度 button (purple when active); the action reads the value lazily.
    ref.watch(parameterSettingsControllerProvider);

    final CurrentModel? current = ref.watch(appCurrentModelProvider).value;
    final hasApiKey =
        (current?.model.apiKey?.isNotEmpty ?? false) ||
        (current?.provider.apiKey?.isNotEmpty ?? false);
    final modelReady = current != null && hasApiKey;
    final isStreaming =
        ref.watch(chatControllerProvider).value?.isStreaming ?? false;
    final attachments = ref.watch(composerAttachmentsProvider);
    // 建议模型 follow-up suggestions for the latest reply; tap sends, long-press
    // fills the field. Hidden while streaming (also cleared in state then).
    final suggestions = isStreaming
        ? const <String>[]
        : ref.watch(
            chatControllerProvider.select(
              (a) => a.value?.suggestions ?? const <String>[],
            ),
          );
    // A lone pasted-as-file attachment (no typed text) can still be sent.
    final canSend =
        modelReady && (_hasText || attachments.isNotEmpty) && !isStreaming;
    _canSend = canSend;

    final composer = InputBoxComposer(
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
      onStop: isStreaming
          ? () => ref.read(chatControllerProvider.notifier).stopStreaming()
          : null,
    );

    // Staged 多模型发送 mentions show as chips above the composer; the next send
    // fans out to them. Editable (✕ per chip) and cleared after sending.
    final mentions = ref.watch(multiModelMentionsProvider);

    if (suggestions.isEmpty && mentions.isEmpty) return composer;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (suggestions.isNotEmpty)
          _SuggestionBubbles(
            suggestions: suggestions,
            onTap: _sendSuggestion,
            onLongPress: _insertPhrase,
          ),
        if (mentions.isNotEmpty)
          _MentionChips(
            mentions: mentions,
            onRemove: (providerId, modelId) => ref
                .read(multiModelMentionsProvider.notifier)
                .remove(providerId, modelId),
            onClear: () =>
                ref.read(multiModelMentionsProvider.notifier).clear(),
          ),
        composer,
      ],
    );
  }
}

/// The staged 多模型发送 mentions shown above the composer: one chip per chosen
/// model (✕ to drop it), plus a 清空 action. The next send fans the turn out to
/// these models and clears the row.
class _MentionChips extends StatelessWidget {
  const _MentionChips({
    required this.mentions,
    required this.onRemove,
    required this.onClear,
  });

  final List<CurrentModel> mentions;
  final void Function(String providerId, String modelId) onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        children: [
          Icon(
            Icons.compare_arrows,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in mentions)
                  InputChip(
                    label: Text(
                      m.model.name,
                      style: theme.textTheme.bodySmall,
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onDeleted: () => onRemove(m.provider.id, m.model.id),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

/// The 建议模型 follow-up suggestion bubbles shown above the composer. Tap a
/// bubble to send it as a new message; long-press to fill it into the field for
/// editing first (the "两者都要" behavior). Hidden when there are no suggestions.
class _SuggestionBubbles extends StatelessWidget {
  const _SuggestionBubbles({
    required this.suggestions,
    required this.onTap,
    required this.onLongPress,
  });

  final List<String> suggestions;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onLongPress;

  @override
  Widget build(BuildContext context) {
    final visible = <String>[
      for (final s in suggestions)
        if (s.trim().isNotEmpty) s.trim(),
    ];
    if (visible.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : cs.primaryContainer.withValues(alpha: 0.42);
    final textColor = cs.onSurface.withValues(alpha: isDark ? 0.92 : 0.88);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final suggestion in visible)
              Semantics(
                button: true,
                label: suggestion,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onTap(suggestion),
                  onLongPress: () => onLongPress(suggestion),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      suggestion,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
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
                _leading(theme, attachment),
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

  /// The chip's leading affordance: a small thumbnail for an image attachment,
  /// else a type icon (binary file vs text/document).
  Widget _leading(ThemeData theme, ComposerAttachment attachment) {
    if (attachment.kind == ComposerAttachmentKind.image) {
      final data = attachment.base64Data;
      if (data != null && data.isNotEmpty) {
        try {
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(
              base64Decode(data),
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          );
        } on FormatException {
          // fall through to the icon
        }
      }
    }
    return Icon(
      attachment.kind == ComposerAttachmentKind.file
          ? LucideIcons.file
          : LucideIcons.fileText,
      size: 16,
      color: theme.colorScheme.primary,
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
