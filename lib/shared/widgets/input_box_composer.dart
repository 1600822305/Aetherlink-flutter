import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/domain/input_box_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/input_box_actions.dart';
import 'package:aetherlink_flutter/shared/widgets/input_box_button_catalog.dart';

/// Static UI strings, ported verbatim from the original (i18n is a later
/// effort, per the M4.1 approach).
const String _inputHint = '和ai助手说点什么... (Ctrl+Enter 展开)';
const String _sendTooltip = '发送消息';
const String _stopTooltip = '停止生成';

/// The original's literal send-button identity colors (`ButtonToolbar.tsx`):
/// intrinsic to the button rather than theme-able roles, so — like the lucide
/// glyph shapes — they are fixed values for 1:1 parity.
const Color _sendGreenLight = Color(0xFF09BB07);
const Color _sendGreenDark = Color(0xFF4CAF50);
const Color _disabledLight = Color(0xFFCCCCCC);
const Color _disabledDark = Color(0xFF555555);
const Color _stopRed = Color(0xFFFF4D4F);

/// The active-button background tint (`rgba(59,130,246,0.1)`); the per-button
/// active accent colors live in [inputBoxToolbarActiveColor].
const Color _activeTint = Color(0x1A3B82F6);

/// The bottom composer: a 1:1 port of the original `IntegratedChatInput` — a
/// rounded, paper-surfaced card holding the text field on top and a
/// space-between toolbar below.
///
/// It is a pure view: the visual preset and which buttons sit left / right come
/// from [settings], so both the chat page and the appearance 输入框管理设置 preview
/// render from the same configuration. The text field is driven by the supplied
/// [controller]; the send button's run-time state comes from [canSend] /
/// [isStreaming] / [onSend]. Every other button is routed through the single
/// [actions] port (`invoke` / `isActive` / `isEnabled`); the default
/// [NoInputBoxActions] leaves them full-fidelity but inert, so a behavior slice
/// can supply a host implementation without touching this view.
class InputBoxComposer extends StatelessWidget {
  const InputBoxComposer({
    super.key,
    required this.settings,
    required this.controller,
    this.focusNode,
    this.readOnly = false,
    this.canSend = false,
    this.isStreaming = false,
    this.onSend,
    this.actions = const NoInputBoxActions(),
    this.sendWithEnter = false,
    this.enterAsNewline = false,
    this.attachmentsBar,
    this.onPasteText,
  });

  final InputBoxSettings settings;
  final TextEditingController controller;
  final FocusNode? focusNode;

  /// Whether a plain Enter sends (port of `settings.sendWithEnter`). On a mobile
  /// soft keyboard this is honored via the keyboard action (Enter ⇒ 发送);
  /// hardware Enter is intercepted by the owner's [focusNode]. The preview
  /// (appearance page) leaves it `false` so the field just inserts newlines.
  final bool sendWithEnter;

  /// Whether a mobile soft-keyboard Enter inserts a newline instead of sending
  /// (port of `settings.mobileInputMethodEnterAsNewline`); takes precedence over
  /// [sendWithEnter] on the soft keyboard.
  final bool enterAsNewline;

  /// A non-interactive preview (the appearance page) sets this so the card is
  /// shown for layout/style only.
  final bool readOnly;

  final bool canSend;
  final bool isStreaming;
  final VoidCallback? onSend;

  /// The behavior port for every non-send toolbar button. Defaults to the inert
  /// [NoInputBoxActions] (the appearance preview and the not-yet-wired chat
  /// composer).
  final InputBoxActions actions;

  /// An optional row rendered above the text field (the pending-attachment
  /// chips). `null` (the appearance preview / not-yet-wired composer) renders
  /// nothing.
  final Widget? attachmentsBar;

  /// Optional paste interceptor. When supplied, every paste into the field —
  /// hardware Ctrl/Cmd+V and the selection toolbar / right-click 粘贴 — is routed
  /// here with the clipboard's plain text. Returning `true` means it was
  /// consumed (e.g. long text converted to a file) and must not be inserted;
  /// `false` falls through to a normal insert at the caret. `null` (the preview)
  /// leaves the platform's default paste untouched.
  final Future<bool> Function(String text)? onPasteText;

  /// On a mobile soft keyboard, surface a 发送 action key when Enter should send
  /// (`sendWithEnter` on and not forced to newline); otherwise the return key
  /// inserts a newline. Desktop always uses newline — hardware Enter is handled
  /// by the owner's [focusNode] key interceptor before a newline is inserted.
  TextInputAction get _softKeyboardAction {
    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (isMobile && sendWithEnter && !enterAsNewline) {
      return TextInputAction.send;
    }
    return TextInputAction.newline;
  }

  /// Wraps [field] so a hardware Ctrl/Cmd+V is routed through [onPasteText]
  /// (the [PasteTextIntent] is registered with [Action.overridable], so an
  /// ancestor [Actions] overrides it). Untouched when no interceptor is set.
  Widget _wrapPaste(Widget field) {
    if (onPasteText == null) return field;
    return Actions(
      actions: <Type, Action<Intent>>{
        PasteTextIntent: CallbackAction<PasteTextIntent>(
          onInvoke: (_) {
            _handlePaste();
            return null;
          },
        ),
      },
      child: field,
    );
  }

  /// The field's context menu. With an interceptor set, the toolbar / right-click
  /// 粘贴 button (which otherwise pastes directly, bypassing [PasteTextIntent]) is
  /// rerouted through [onPasteText]; this also means the Flutter toolbar is used
  /// instead of the platform's system menu so the button stays interceptable.
  /// Without an interceptor, the default adaptive toolbar is rendered.
  Widget _buildContextMenu(BuildContext context, EditableTextState state) {
    if (onPasteText == null) {
      return AdaptiveTextSelectionToolbar.editableText(
        editableTextState: state,
      );
    }
    final items = <ContextMenuButtonItem>[
      for (final item in state.contextMenuButtonItems)
        if (item.type == ContextMenuButtonType.paste)
          item.copyWith(
            onPressed: () {
              state.hideToolbar();
              _handlePaste();
            },
          )
        else
          item,
    ];
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: items,
    );
  }

  /// Reads the clipboard's plain text and offers it to [onPasteText]; when not
  /// consumed, performs an ordinary paste by replacing the selection at the
  /// caret (the override otherwise suppresses the default insert).
  Future<void> _handlePaste() async {
    final onPaste = onPasteText;
    if (onPaste == null) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    final consumed = await onPaste(text);
    if (consumed) return;
    final value = controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    controller.value = TextEditingValue(
      text: value.text.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final spec = _InputBoxStyleSpec.of(settings.style, isDark: isDark);

    final card = DecoratedBox(
      decoration: BoxDecoration(
        // var(--theme-bg-paper) → the paper/surface role. `modern` makes it
        // slightly translucent so the blur behind it reads as glass.
        color: theme.colorScheme.surface.withValues(alpha: spec.surfaceAlpha),
        borderRadius: BorderRadius.circular(spec.radius),
        border: Border.all(color: spec.borderColor),
        boxShadow: spec.shadow,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The pending-attachment chips, above the field (port of the
              // input box's converted-file chips).
              if (attachmentsBar != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 2, bottom: 4),
                  child: attachmentsBar,
                ),
              // Upper layer: the text composer.
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 2),
                child: _wrapPaste(
                  TextField(
                    controller: controller,
                    focusNode: focusNode,
                    readOnly: readOnly,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: _softKeyboardAction,
                    onSubmitted: readOnly ? null : (_) => onSend?.call(),
                    style: const TextStyle(fontSize: 16, height: 1.4),
                    contextMenuBuilder: _buildContextMenu,
                    decoration: const InputDecoration(
                      hintText: _inputHint,
                      hintStyle: TextStyle(fontSize: 16, height: 1.4),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              // Lower layer: the configurable button toolbar.
              _Toolbar(
                settings: settings,
                isDark: isDark,
                canSend: canSend,
                isStreaming: isStreaming,
                onSend: onSend,
                actions: actions,
              ),
            ],
          ),
        ),
      ),
    );

    // The original input container is transparent (`backgroundColor:
    // 'transparent'`, `ChatPageUI.tsx`): only the inner card paints the paper
    // surface, so the chat wallpaper shows through around it and the `modern`
    // backdrop blur reads as glass over the messages. A transparency-typed
    // [Material] keeps ink and text-style inheritance for the field and toolbar
    // without painting an opaque block behind the card.
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        // The original centers the card with an 8px horizontal gutter on mobile.
        padding: const EdgeInsets.all(8),
        // `modern` adds a backdrop blur (the original's `backdropFilter:
        // blur(10px)`); clip to the rounded card so the blur stays inside it.
        child: spec.blurSigma == 0
            ? card
            : ClipRRect(
                borderRadius: BorderRadius.circular(spec.radius),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: spec.blurSigma,
                    sigmaY: spec.blurSigma,
                  ),
                  child: card,
                ),
              ),
      ),
    );
  }
}

/// The configurable toolbar: the left and right button clusters, laid out
/// space-between in a 36px-tall row, rendered from [InputBoxSettings].
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.settings,
    required this.isDark,
    required this.canSend,
    required this.isStreaming,
    required this.onSend,
    required this.actions,
  });

  final InputBoxSettings settings;
  final bool isDark;
  final bool canSend;
  final bool isStreaming;
  final VoidCallback? onSend;
  final InputBoxActions actions;

  /// The tap handler for [id]: maps it to its [InputBoxAction] and dispatches
  /// through [actions] when that action is wired, else `null` so the button
  /// renders full-fidelity but stays inert (and `send`, which has no action).
  VoidCallback? _onPressed(InputBoxButtonId id, BuildContext context) {
    final action = inputBoxButtonAction(id);
    if (action == null) return null;
    return actions.isEnabled(action)
        ? () => actions.invoke(action, context)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // iconColor = isDarkMode ? '#ffffff' : '#000000' → the on-surface role.
    final iconColor = theme.colorScheme.onSurface;

    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final id in settings.leftButtons)
                _button(id, iconColor, context),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final id in settings.rightButtons)
                _button(id, iconColor, context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _button(InputBoxButtonId id, Color iconColor, BuildContext context) {
    if (id == InputBoxButtonId.send) {
      final sendColor = canSend
          ? (isDark ? _sendGreenDark : _sendGreenLight)
          : (isDark ? _disabledDark : _disabledLight);
      return _ToolbarButton(
        icon: Icon(
          isStreaming ? LucideIcons.square : LucideIcons.send,
          size: 18,
          color: isStreaming ? _stopRed : sendColor,
        ),
        tooltip: isStreaming ? _stopTooltip : _sendTooltip,
        // Stopping a stream is a later slice; during streaming the button
        // shows the stop glyph but does not act.
        onPressed: isStreaming ? null : onSend,
      );
    }

    // Every other button is keyed by its action so the port drives its
    // active state: 网络搜索/语音 light up, 图像/视频 (when placed standalone) flip to
    // their accent and "退出…模式" tooltip while their session mode is on, and
    // 清空内容 swaps to a red 确认清空 / AlertTriangle while armed for its second tap.
    final action = inputBoxButtonAction(id)!;
    final active = actions.isActive(action);
    final restColor = inputBoxToolbarRestColor(id, iconColor);
    return _ToolbarButton(
      icon: inputBoxToolbarIcon(
        id,
        color: active ? inputBoxToolbarActiveColor(id, restColor) : restColor,
        active: active,
      ),
      tooltip: inputBoxToolbarTooltip(id, active: active),
      active: active,
      onPressed: _onPressed(id, context),
    );
  }
}

/// A single toolbar icon button mirroring the original's `IconButton`
/// (`size="medium"`, `padding: 6px`, active background `rgba(59,130,246,0.1)`).
class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.all(6),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      style: active ? IconButton.styleFrom(backgroundColor: _activeTint) : null,
    );
  }
}

/// The resolved card chrome for an [InputBoxStyle] (`useInputStyles.ts`):
/// border / radius / shadow, plus the surface translucency + blur that
/// `modern` adds (the original's `backdropFilter: blur(10px)`).
class _InputBoxStyleSpec {
  const _InputBoxStyleSpec({
    required this.radius,
    required this.borderColor,
    required this.shadow,
    required this.surfaceAlpha,
    required this.blurSigma,
  });

  final double radius;
  final Color borderColor;
  final List<BoxShadow> shadow;
  final double surfaceAlpha;
  final double blurSigma;

  /// `1px solid rgba(230,230,230,.8)` light / `rgba(60,60,60,.8)` dark.
  static Color _baseBorder(bool isDark) =>
      isDark ? const Color(0xCC3C3C3C) : const Color(0xCCE6E6E6);

  static _InputBoxStyleSpec of(InputBoxStyle style, {required bool isDark}) {
    switch (style) {
      case InputBoxStyle.modern:
        return _InputBoxStyleSpec(
          radius: 12,
          borderColor: _baseBorder(isDark),
          // 0 4px 16px rgba(0,0,0,0.15) light / 0.4 dark.
          shadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          surfaceAlpha: 0.8,
          blurSigma: 10,
        );
      case InputBoxStyle.minimal:
        return _InputBoxStyleSpec(
          radius: 6,
          // 1px solid rgba(0,0,0,.1) light / rgba(255,255,255,.1) dark.
          borderColor: isDark
              ? const Color(0x1AFFFFFF)
              : const Color(0x1A000000),
          shadow: const [],
          surfaceAlpha: 1,
          blurSigma: 0,
        );
      case InputBoxStyle.defaultStyle:
        return _InputBoxStyleSpec(
          radius: 8,
          borderColor: _baseBorder(isDark),
          // 0 2px 8px rgba(0,0,0,0.1) light / 0.3 dark.
          shadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          surfaceAlpha: 1,
          blurSigma: 0,
        );
    }
  }
}
