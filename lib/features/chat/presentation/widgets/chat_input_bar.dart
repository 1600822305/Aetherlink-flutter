import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/theme/app_theme_extension.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';

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
const String _noModelHint = '请先配置模型';

/// The bottom composer, restored to the original "integrated input" look
/// (`IntegratedChatInput`): a rounded, themed surface holding the text field on
/// top and the button toolbar below.
///
/// The composer now sends: the send button is enabled once a current chat
/// model with an API key is configured and the field is non-empty, and a tap
/// hands the text to [ChatController.send]. With no model configured the button
/// stays disabled and a tap surfaces the "configure a model first" hint. The
/// other feature buttons remain disabled placeholders (later slices).
class ChatInputBar extends ConsumerStatefulWidget {
  const ChatInputBar({super.key});

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
                // Upper layer: the text composer.
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
                _InputButtonToolbar(
                  canSend: canSend,
                  // When no model is configured, the button is disabled but a
                  // tap still surfaces the hint (so the toolbar handles taps).
                  onSend: canSend
                      ? _send
                      : (modelReady ? null : _showNoModelHint),
                  sendEnabledColor: canSend,
                ),
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
/// space-between layout. Feature buttons stay disabled (later slices); the send
/// button is wired to [onSend].
class _InputButtonToolbar extends StatelessWidget {
  const _InputButtonToolbar({
    required this.canSend,
    required this.onSend,
    required this.sendEnabledColor,
  });

  final bool canSend;
  final VoidCallback? onSend;
  final bool sendEnabledColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IconButtonTheme(
      data: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.all(6),
          iconSize: 22,
        ),
      ),
      child: Row(
        children: [
          // Feature buttons scroll horizontally so the row never overflows on
          // narrow screens.
          const Expanded(
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
          IconButton(
            icon: const Icon(Icons.send),
            tooltip: _sendTooltip,
            color: sendEnabledColor ? theme.colorScheme.primary : null,
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}
