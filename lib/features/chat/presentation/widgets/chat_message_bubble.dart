import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/message_bubble_access.dart';
import 'package:aetherlink_flutter/app/theme/app_theme_extension.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/message_block_renderer.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/bubble_footer_layout.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_toolbar.dart';
import 'package:aetherlink_flutter/shared/domain/message_bubble_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/color_picker.dart';

/// A single chat message rendered as a bubble.
///
/// Renders the message view ([ChatMessageView]) owned by the [ChatController]:
/// an optional 头像 + 名称 + 时间 header above the ordered blocks, which are
/// dispatched to per-type widgets by [MessageBlockRenderer] (Markdown answer,
/// thinking trace, code, image, error, …) and updated live as a reply streams
/// in.
///
/// The bubble's geometry and chrome follow 外观设置 → 信息气泡管理
/// ([MessageBubbleSettings], read through [messageBubbleSettingsProvider]),
/// mirroring the original `BubbleStyleMessage`: per-role max/min widths, the
/// avatar/name/time header toggles, the 隐藏气泡 (transparent, no radius) modes
/// and the 自定义气泡颜色 overrides. When no custom color is set the fill comes
/// from [AppThemeExtension] (`bubbleUser` / `bubbleAi`) and the text from
/// `colorScheme.onSurface`.
class ChatMessageBubble extends ConsumerWidget {
  const ChatMessageBubble({required this.view, super.key});

  final ChatMessageView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    final settings = ref.watch(messageBubbleSettingsProvider);
    final colors = settings.customBubbleColors;
    final isUser = view.role == MessageRole.user;

    final hideBubble = isUser ? settings.hideUserBubble : settings.hideAIBubble;
    final bubbleColor = isUser
        ? (colorFromHex(colors.userBubbleColor) ??
              ext?.bubbleUser ??
              theme.colorScheme.surface)
        : (colorFromHex(colors.aiBubbleColor) ??
              ext?.bubbleAi ??
              theme.colorScheme.surface);
    final customTextColor = isUser
        ? colorFromHex(colors.userTextColor)
        : colorFromHex(colors.aiTextColor);
    final textColor = customTextColor ?? theme.colorScheme.onSurface;
    final radius = ext?.borderRadius ?? 8.0;

    final maxWidthFactor =
        (isUser
            ? settings.userMessageMaxWidth
            : settings.messageBubbleMaxWidth) /
        100;
    final minWidthFactor = settings.messageBubbleMinWidth / 100;

    final hasError = view.status == MessageStatus.error;
    final isStreaming =
        view.status == MessageStatus.streaming ||
        view.status == MessageStatus.processing;

    // A message with no blocks, that is neither streaming nor errored, renders
    // nothing rather than a fabricated empty bubble. While streaming the
    // renderer shows the 「正在生成回复...」 placeholder.
    if (view.blocks.isEmpty && !isStreaming && !hasError) {
      return const SizedBox.shrink();
    }

    final showAvatar = isUser
        ? settings.showUserAvatar
        : settings.showModelAvatar;
    final showName = isUser ? settings.showUserName : settings.showModelName;
    final header = (showAvatar || showName)
        ? _MessageHeader(
            isUser: isUser,
            showAvatar: showAvatar,
            showName: showName,
            name: isUser ? '用户' : _modelLabel(),
            time: _formatTime(view.createdAt),
          )
        : null;

    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final showToolbar =
        settings.messageActionMode == MessageActionMode.toolbar &&
        !isStreaming &&
        view.blocks.isNotEmpty;

    final content = (view.blocks.isEmpty && hasError && view.errorText != null)
        ? Text(
            view.errorText!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        : MessageBlockRenderer(
            blocks: view.blocks,
            messageStatus: view.status,
            textColor: textColor,
          );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (header != null) ...[header, const SizedBox(height: 4)],
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth * maxWidthFactor;
              final minWidth = (constraints.maxWidth * minWidthFactor).clamp(
                0.0,
                maxWidth,
              );
              return Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    minWidth: minWidth,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: hideBubble ? Colors.transparent : bubbleColor,
                      borderRadius: BorderRadius.circular(
                        hideBubble ? 0 : radius,
                      ),
                    ),
                    child: showToolbar
                        ? BubbleFooterLayout(
                            content: content,
                            // The bubble-internal bottom toolbar, separated
                            // from the content by a 1px divider and stretched to
                            // the full bubble width so the token chip sits flush
                            // against the far edge, mirroring
                            // `BubbleStyleMessage`'s toolbar mode.
                            footer: Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.only(top: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color:
                                        (theme.brightness == Brightness.dark
                                                ? Colors.white
                                                : Colors.black)
                                            .withValues(alpha: 0.1),
                                  ),
                                ),
                              ),
                              child: MessageToolbar(
                                view: view,
                                showTtsButton: settings.showTTSButton,
                                customTextColor: customTextColor,
                              ),
                            ),
                          )
                        : content,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// The assistant name line: `模型名 | 供应商`, mirroring the original
  /// `${model.name} | ${getProviderName(model.provider)}`. Falls back to a
  /// generic label when no model metadata is attached.
  String _modelLabel() {
    final name = view.modelName;
    final provider = view.providerName;
    if (name == null || name.isEmpty) return 'AI助手';
    if (provider == null || provider.isEmpty) return name;
    return '$name | $provider';
  }

  static String _formatTime(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// The avatar + 名称/时间 header above a bubble. Aligned to the right for the
/// user (row-reverse) and the left for the assistant, mirroring the original
/// `BubbleStyleMessage` header.
class _MessageHeader extends StatelessWidget {
  const _MessageHeader({
    required this.isUser,
    required this.showAvatar,
    required this.showName,
    required this.name,
    required this.time,
  });

  final bool isUser;
  final bool showAvatar;
  final bool showName;
  final String name;
  final String time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final avatar = Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isUser ? theme.colorScheme.primary : theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(6), // 25% of 24px
      ),
      child: Text(
        isUser ? 'U' : 'AI',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: isUser ? TextDirection.rtl : TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAvatar) ...[avatar, const SizedBox(width: 8)],
        Column(
          crossAxisAlignment: align,
          children: [
            if (showName)
              Text(
                name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (time.isNotEmpty)
              Text(
                time,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
