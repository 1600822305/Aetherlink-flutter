import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/chat/presentation/widgets/system_prompt_bubble.dart';

/// Static UI strings. The original ran these through i18n; they are ported
/// verbatim as constants per the M4.1 approach — wiring up i18n is a separate
/// effort and out of scope.
const String _emptyConversationLabel = '对话开始了，请输入您的问题';

/// Empty-state placeholder shown when the current topic has no messages (the
/// fresh-install case). Text color is a theme token.
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key, this.showSystemPromptBubble = false});

  /// When set, the system-prompt bubble sits at the very top (above the empty
  /// placeholder), mirroring the web original where the bubble renders before
  /// the "新的对话开始了" notice.
  final bool showSystemPromptBubble;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        _emptyConversationLabel,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.textTheme.bodySmall?.color,
        ),
      ),
    );
    if (!showSystemPromptBubble) return Center(child: placeholder);
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: SystemPromptBubble(),
        ),
        Expanded(child: Center(child: placeholder)),
      ],
    );
  }
}

/// Shown when the read provider fails (e.g. the database cannot be opened).
/// Displays the underlying exception so the cause is diagnosable in release
/// builds where the console stack trace is unavailable.
class ChatErrorNotice extends StatelessWidget {
  const ChatErrorNotice({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '加载消息失败',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              '$error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
