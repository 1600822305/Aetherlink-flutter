import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/theme/app_theme_extension.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';

/// Static UI strings, ported verbatim from the original (i18n is a later
/// effort, per the M4.1 approach).
const String _inputHint = '和ai助手说点什么... (Ctrl+Enter 展开)';
const String _toolsTooltip = '扩展';
const String _clearTooltip = '清空内容';
const String _webSearchTooltip = '网络搜索';
const String _addContentTooltip = '添加内容';
const String _voiceTooltip = '切换到语音输入模式';
const String _sendTooltip = '发送消息';
const String _stopTooltip = '停止生成';
const String _noModelHint = '请先配置模型';

/// The original's two non-lucide toolbar glyphs, ported as SVG assets (the
/// `tools`/`search` buttons use bespoke `CustomIcon`s, not lucide — see
/// `src/components/icons/iconData.ts`).
const String _settingsPanelIcon = 'assets/icons/aether_settings_panel.svg';
const String _searchIcon = 'assets/icons/aether_search.svg';

/// The original's literal button-identity colors (`ButtonToolbar.tsx`). These
/// are intrinsic to the send button rather than theme-able roles, so — like the
/// lucide glyph shapes — they are kept as fixed values for 1:1 parity.
const Color _sendGreenLight = Color(0xFF09BB07);
const Color _sendGreenDark = Color(0xFF4CAF50);
const Color _disabledLight = Color(0xFFCCCCCC);
const Color _disabledDark = Color(0xFF555555);
const Color _stopRed = Color(0xFFFF4D4F);

/// Active-state colors (web-search blue / clear-confirm + voice red) and the
/// active-button tint, kept for when the corresponding actions are wired.
const Color _webSearchActiveBlue = Color(0xFF3B82F6);
const Color _activeRed = Color(0xFFF44336);
const Color _activeTint = Color(0x1A3B82F6); // rgba(59,130,246,0.1)

/// The bottom composer, a 1:1 port of the original `IntegratedChatInput`: a
/// rounded, paper-surfaced card holding the text field on top and a
/// space-between button toolbar below (left `tools / clear / search`, right
/// `upload / voice / send`).
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
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
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
    final theme = Theme.of(context);
    final radius = theme.extension<AppThemeExtension>()?.borderRadius ?? 8.0;
    final isDark = theme.brightness == Brightness.dark;

    final CurrentModel? current = ref.watch(appCurrentModelProvider).value;
    final hasApiKey =
        (current?.model.apiKey?.isNotEmpty ?? false) ||
        (current?.provider.apiKey?.isNotEmpty ?? false);
    final modelReady = current != null && hasApiKey;
    final isStreaming =
        ref.watch(chatControllerProvider).value?.isStreaming ?? false;
    final canSend = modelReady && _hasText && !isStreaming;

    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        // The original centers the card with an 8px horizontal gutter on mobile.
        padding: const EdgeInsets.all(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // var(--theme-bg-paper) → the paper/surface role.
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: theme.dividerColor),
            boxShadow: [
              // 0 2px 8px rgba(0,0,0,0.1) light / 0.3 dark.
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
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
                      controller: _controller,
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
                  // Lower layer: the button toolbar.
                  _InputButtonToolbar(
                    isDark: isDark,
                    canSend: canSend,
                    isStreaming: isStreaming,
                    onSend: canSend
                        ? _send
                        : (modelReady ? null : _showNoModelHint),
                    onToolsMenu: widget.onToolsMenu,
                    onClearTopic: widget.onClearTopic,
                    onToggleWebSearch: widget.onToggleWebSearch,
                    onAddContent: widget.onAddContent,
                    onToggleVoice: widget.onToggleVoice,
                    webSearchActive: widget.webSearchActive,
                    voiceActive: widget.voiceActive,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The button toolbar below the composer (`ButtonToolbar.tsx`): a left cluster
/// (`tools / clear / search`) and a right cluster (`upload / voice / send`) laid
/// out space-between in a 36px-tall row.
class _InputButtonToolbar extends StatelessWidget {
  const _InputButtonToolbar({
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // iconColor = isDarkMode ? '#ffffff' : '#000000' → the on-surface role.
    final iconColor = theme.colorScheme.onSurface;
    final sendColor = canSend
        ? (isDark ? _sendGreenDark : _sendGreenLight)
        : (isDark ? _disabledDark : _disabledLight);

    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left cluster: tools / clear / search.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarButton(
                icon: _svg(_settingsPanelIcon, iconColor),
                tooltip: _toolsTooltip,
                onPressed: onToolsMenu,
              ),
              _ToolbarButton(
                icon: Icon(LucideIcons.trash2, size: 20, color: iconColor),
                tooltip: _clearTooltip,
                onPressed: onClearTopic,
              ),
              _ToolbarButton(
                icon: _svg(
                  _searchIcon,
                  webSearchActive ? _webSearchActiveBlue : iconColor,
                ),
                tooltip: _webSearchTooltip,
                active: webSearchActive,
                onPressed: onToggleWebSearch,
              ),
            ],
          ),
          // Right cluster: upload / voice / send.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarButton(
                icon: Icon(LucideIcons.plus, size: 20, color: iconColor),
                tooltip: _addContentTooltip,
                onPressed: onAddContent,
              ),
              _ToolbarButton(
                icon: Icon(
                  voiceActive ? LucideIcons.keyboard : LucideIcons.mic,
                  size: 20,
                  color: voiceActive ? _activeRed : iconColor,
                ),
                tooltip: _voiceTooltip,
                active: voiceActive,
                onPressed: onToggleVoice,
              ),
              _ToolbarButton(
                icon: Icon(
                  isStreaming ? LucideIcons.square : LucideIcons.send,
                  size: 18,
                  color: isStreaming ? _stopRed : sendColor,
                ),
                tooltip: isStreaming ? _stopTooltip : _sendTooltip,
                // Stopping a stream is a later slice; during streaming the
                // button shows the stop glyph but does not act.
                onPressed: isStreaming ? null : onSend,
              ),
            ],
          ),
        ],
      ),
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

/// Renders a bespoke (non-lucide) SVG glyph tinted to [color], matching the
/// original `CustomIcon` fill behavior.
Widget _svg(String asset, Color color, {double size = 20}) => SvgPicture.asset(
  asset,
  width: size,
  height: size,
  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
);
