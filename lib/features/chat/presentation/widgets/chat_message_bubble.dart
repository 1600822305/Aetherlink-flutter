import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/app/theme/app_theme_extension.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';

/// A single chat message rendered as a bubble.
///
/// Renders the message's flattened view ([ChatMessageView]) owned by the
/// [ChatController]: the `thinking` trace (when present) above the `main_text`
/// answer, both updated live as a reply streams in. A failed turn shows its
/// error text in place of the answer. Markdown and the other block variants are
/// later slices.
///
/// Layout mirrors the original Aetherlink bubble: a user message hugs the
/// right, an assistant/system message the left. Colors are theme tokens — the
/// fill comes from [AppThemeExtension] (`bubbleUser` / `bubbleAi`), the radius
/// from its `borderRadius`, the text from `colorScheme.onSurface`.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({required this.view, super.key});

  final ChatMessageView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    final isUser = view.role == MessageRole.user;

    final bubbleColor = isUser ? ext?.bubbleUser : ext?.bubbleAi;
    final radius = ext?.borderRadius ?? 8.0;
    final maxWidth = MediaQuery.sizeOf(context).width * (isUser ? 0.8 : 0.92);

    final hasError = view.status == MessageStatus.error;
    final isStreaming = view.status == MessageStatus.streaming;
    // A streaming assistant turn with no text yet shows a typing ellipsis so
    // the bubble is visible the moment the reply starts.
    final bodyText = view.text.isNotEmpty
        ? view.text
        : (isStreaming ? '…' : view.text);

    // A message with neither answer, thinking nor error renders nothing rather
    // than a fabricated empty bubble.
    if (bodyText.isEmpty && view.thinking.isEmpty && !hasError) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor ?? theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (view.thinking.isNotEmpty) ...[
                Text(
                  view.thinking,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (bodyText.isNotEmpty)
                Text(
                  bodyText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              if (hasError && view.errorText != null)
                Text(
                  view.errorText!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
