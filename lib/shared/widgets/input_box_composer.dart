import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/domain/input_box_settings.dart';
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

/// Active-state colors (web-search blue / voice red) and the active-button tint.
const Color _webSearchActiveBlue = Color(0xFF3B82F6);
const Color _activeRed = Color(0xFFF44336);
const Color _activeTint = Color(0x1A3B82F6); // rgba(59,130,246,0.1)

/// The bottom composer: a 1:1 port of the original `IntegratedChatInput` — a
/// rounded, paper-surfaced card holding the text field on top and a
/// space-between toolbar below.
///
/// It is a pure view: the visual preset and which buttons sit left / right come
/// from [settings], so both the chat page and the appearance 输入框管理设置 preview
/// render from the same configuration. The text field is driven by the supplied
/// [controller]; the send button's run-time state comes from [canSend] /
/// [isStreaming] / [onSend]. The remaining default buttons expose their actions
/// as the [onToolsMenu] / [onClearTopic] / [onToggleWebSearch] / [onAddContent]
/// / [onToggleVoice] callbacks (null ⇒ renders but does nothing); any other
/// configured button renders full-fidelity with no handler yet.
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
    this.onToolsMenu,
    this.onClearTopic,
    this.onToggleWebSearch,
    this.onAddContent,
    this.onToggleVoice,
    this.webSearchActive = false,
    this.voiceActive = false,
  });

  final InputBoxSettings settings;
  final TextEditingController controller;
  final FocusNode? focusNode;

  /// A non-interactive preview (the appearance page) sets this so the card is
  /// shown for layout/style only.
  final bool readOnly;

  final bool canSend;
  final bool isStreaming;
  final VoidCallback? onSend;
  final VoidCallback? onToolsMenu;
  final VoidCallback? onClearTopic;
  final VoidCallback? onToggleWebSearch;
  final VoidCallback? onAddContent;
  final VoidCallback? onToggleVoice;
  final bool webSearchActive;
  final bool voiceActive;

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
              // Upper layer: the text composer.
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 2),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: readOnly,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                  decoration: const InputDecoration(
                    hintText: _inputHint,
                    hintStyle: TextStyle(fontSize: 16, height: 1.4),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
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
                onToolsMenu: onToolsMenu,
                onClearTopic: onClearTopic,
                onToggleWebSearch: onToggleWebSearch,
                onAddContent: onAddContent,
                onToggleVoice: onToggleVoice,
                webSearchActive: webSearchActive,
                voiceActive: voiceActive,
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
    required this.onToolsMenu,
    required this.onClearTopic,
    required this.onToggleWebSearch,
    required this.onAddContent,
    required this.onToggleVoice,
    required this.webSearchActive,
    required this.voiceActive,
  });

  final InputBoxSettings settings;
  final bool isDark;
  final bool canSend;
  final bool isStreaming;
  final VoidCallback? onSend;
  final VoidCallback? onToolsMenu;
  final VoidCallback? onClearTopic;
  final VoidCallback? onToggleWebSearch;
  final VoidCallback? onAddContent;
  final VoidCallback? onToggleVoice;
  final bool webSearchActive;
  final bool voiceActive;

  /// The callback wired for [id] today; `null` ⇒ the button renders but does
  /// nothing (its behavior is a later slice).
  VoidCallback? _handlerFor(InputBoxButtonId id) => switch (id) {
    InputBoxButtonId.tools => onToolsMenu,
    InputBoxButtonId.clear => onClearTopic,
    InputBoxButtonId.search => onToggleWebSearch,
    InputBoxButtonId.upload => onAddContent,
    InputBoxButtonId.voice => onToggleVoice,
    _ => null,
  };

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
              for (final id in settings.leftButtons) _button(id, iconColor),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final id in settings.rightButtons) _button(id, iconColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _button(InputBoxButtonId id, Color iconColor) {
    switch (id) {
      case InputBoxButtonId.send:
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
      case InputBoxButtonId.voice:
        return _ToolbarButton(
          icon: inputBoxToolbarIcon(
            id,
            color: voiceActive ? _activeRed : iconColor,
          ),
          tooltip: inputBoxToolbarTooltip(id),
          active: voiceActive,
          onPressed: _handlerFor(id),
        );
      case InputBoxButtonId.search:
        return _ToolbarButton(
          icon: inputBoxToolbarIcon(
            id,
            color: webSearchActive ? _webSearchActiveBlue : iconColor,
          ),
          tooltip: inputBoxToolbarTooltip(id),
          active: webSearchActive,
          onPressed: _handlerFor(id),
        );
      default:
        return _ToolbarButton(
          icon: inputBoxToolbarIcon(
            id,
            color: inputBoxToolbarRestColor(id, iconColor),
          ),
          tooltip: inputBoxToolbarTooltip(id),
          onPressed: _handlerFor(id),
        );
    }
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
