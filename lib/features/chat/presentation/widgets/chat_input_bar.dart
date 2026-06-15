import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/app/theme/app_theme_extension.dart';

/// Static UI strings, ported verbatim from the original (i18n is a later
/// effort, per the M4.1 approach).
const String _inputHint = '和ai助手说点什么...';
const String _webSearchTooltip = '网络搜索';
const String _mcpToolsTooltip = 'MCP 工具';
const String _knowledgeTooltip = '知识库';
const String _imageTooltip = '图片';
const String _voiceTooltip = '语音';
const String _multiModelTooltip = '多模型';
const String _sendTooltip = '发送';

/// The bottom composer, restored to the original "integrated input" look
/// (`IntegratedChatInput`): a rounded, themed surface holding the text field on
/// top and the button toolbar below.
///
/// The field accepts text (local UI state). Sending and every feature button
/// are unwired, disabled placeholders this round (M4.2.0b is appearance-only) —
/// no fake buttons. Colors come from theme tokens.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({super.key});

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = theme.extension<AppThemeExtension>()?.borderRadius ?? 8.0;

    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Upper layer: the text composer (input enabled, local UI only).
                TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: _inputHint,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                ),
                // Lower layer: the button toolbar.
                const _InputButtonToolbar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The button toolbar below the composer (`ButtonToolbar`): a left cluster of
/// feature buttons and a right-aligned send button, mirroring the original's
/// space-between layout.
///
/// Every button is disabled (`onPressed: null`) — M4.2.0b wires no behaviour;
/// disabled is the honest "not connected yet" signal. Icons are Flutter
/// built-ins approximating the original lucide set.
class _InputButtonToolbar extends StatelessWidget {
  const _InputButtonToolbar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Tighten the toolbar to the original's compact icon row (the previous pass
    // used full-size default `IconButton`s, which read as chunky/generic).
    // Disabled buttons still grey out — the honest "not connected" signal.
    return IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(6),
          iconSize: 22,
        ),
      ),
      child: const Row(
        children: [
          // Feature buttons scroll horizontally so the row never overflows on
          // narrow screens.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.public),
                    tooltip: _webSearchTooltip,
                    onPressed: null,
                  ),
                  IconButton(
                    icon: Icon(Icons.build),
                    tooltip: _mcpToolsTooltip,
                    onPressed: null,
                  ),
                  IconButton(
                    icon: Icon(Icons.menu_book),
                    tooltip: _knowledgeTooltip,
                    onPressed: null,
                  ),
                  IconButton(
                    icon: Icon(Icons.image),
                    tooltip: _imageTooltip,
                    onPressed: null,
                  ),
                  IconButton(
                    icon: Icon(Icons.mic),
                    tooltip: _voiceTooltip,
                    onPressed: null,
                  ),
                  IconButton(
                    icon: Icon(Icons.swap_horiz),
                    tooltip: _multiModelTooltip,
                    onPressed: null,
                  ),
                ],
              ),
            ),
          ),
          // Send — message sending is a later slice; disabled.
          IconButton(
            icon: Icon(Icons.send),
            tooltip: _sendTooltip,
            onPressed: null,
          ),
        ],
      ),
    );
  }
}
