import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/theme/app_theme_extension.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';

/// A single chat message rendered as a bubble (M4.2.1).
///
/// It reads the message's blocks through the real
/// [messageBlocksProvider] (→ `getMessageBlocksByMessageId`) and renders the
/// `main_text` blocks as plain text — the first time stored M0/M1 data is
/// painted into a visible conversation. Markdown and the other 14 block
/// variants are later slices, so non-`main_text` blocks are ignored here.
///
/// Layout mirrors the original Aetherlink bubble style: a user message hugs the
/// right, an assistant/system message hugs the left. Colors are theme tokens —
/// the bubble fill comes from [AppThemeExtension] (`bubbleUser` / `bubbleAi`),
/// the corner radius from its `borderRadius`, and the text from
/// `colorScheme.onSurface` (the original used `--theme-text-primary` for both
/// sides). No hardcoded colors.
class ChatMessageBubble extends ConsumerWidget {
  const ChatMessageBubble({required this.message, super.key});

  final Message message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocksAsync = ref.watch(messageBlocksProvider(message.id));

    return blocksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => _Bubble(message: message, text: '加载消息内容失败'),
      data: (blocks) {
        final text = blocks
            .whereType<MainTextBlock>()
            .map((block) => block.content)
            .join('\n\n');
        // Only main_text is rendered this slice; a message with no main_text
        // content (e.g. only other block types) shows nothing rather than a
        // fabricated empty bubble.
        if (text.isEmpty) {
          return const SizedBox.shrink();
        }
        return _Bubble(message: message, text: text);
      },
    );
  }
}

/// The bubble shell: alignment by role + tokenized fill, radius and text color.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.text});

  final Message message;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    final isUser = message.role == MessageRole.user;

    final bubbleColor = isUser ? ext?.bubbleUser : ext?.bubbleAi;
    final radius = ext?.borderRadius ?? 8.0;
    final maxWidth = MediaQuery.sizeOf(context).width * (isUser ? 0.8 : 0.92);

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
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
