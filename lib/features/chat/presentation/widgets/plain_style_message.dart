import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/message_bubble_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/message_block_renderer.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_toolbar.dart';

/// A single chat message rendered in **plain / minimal** style.
///
/// Port of the original `MinimalStyleMessage.tsx`: a flat, divider-separated
/// layout with an inline 24 px avatar, a name + time header row, full-width
/// content, and an always-visible toolbar underneath. No bubble background, no
/// per-role alignment — every message is left-aligned and stretches to the
/// available width.
///
/// The widget reads [MessageBubbleSettings] for avatar / name visibility and
/// toolbar preferences, keeping the same settings surface as [ChatMessageBubble].
class PlainStyleMessage extends ConsumerWidget {
  const PlainStyleMessage({required this.view, super.key});

  final ChatMessageView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(messageBubbleSettingsProvider);
    final isUser = view.role == MessageRole.user;

    final hasError = view.status == MessageStatus.error;
    final isStreaming = view.status == MessageStatus.streaming ||
        view.status == MessageStatus.processing;

    if (view.blocks.isEmpty && !isStreaming && !hasError) {
      return const SizedBox.shrink();
    }

    final showAvatar =
        isUser ? settings.showUserAvatar : settings.showModelAvatar;
    final showName = isUser ? settings.showUserName : settings.showModelName;

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
            textColor: theme.colorScheme.onSurface,
          );

    final isSummaryMessage =
        view.blocks.any((b) => b is ContextSummaryBlock);
    final showToolbar =
        !isStreaming && view.blocks.isNotEmpty && !isSummaryMessage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar (24 px, inline with the first line).
          if (showAvatar) ...[
            _PlainAvatar(isUser: isUser, name: _modelLabel()),
            const SizedBox(width: 8),
          ],
          // Content column.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + time row.
                if (showName)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Text(
                          isUser ? '用户' : _modelLabel(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.8,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(view.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 11.2,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Message blocks.
                content,
                // Bottom toolbar.
                if (showToolbar)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Opacity(
                      opacity: 0.7,
                      child: MessageToolbar(
                        view: view,
                        showTtsButton: settings.showTTSButton,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
    final month = local.month;
    final day = local.day;
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$month/$day $h:$m';
  }
}

/// A compact 24 px avatar for the plain style, matching the original's
/// gradient-backed circle with a single emoji or initial.
class _PlainAvatar extends StatelessWidget {
  const _PlainAvatar({required this.isUser, required this.name});

  final bool isUser;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isUser ? theme.colorScheme.primary : theme.colorScheme.secondary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isUser ? 'U' : (name.isNotEmpty ? name[0].toUpperCase() : 'AI'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
