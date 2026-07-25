import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/multi_model_message_style.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_message_bubble.dart';

class MultiModelMemberCell extends StatelessWidget {
  const MultiModelMemberCell({
    super.key,
    required this.messageId,
    required this.style,
    required this.selected,
    this.onTap,
  });

  final String messageId;
  final MultiModelMessageStyle style;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubble = ChatMessageBubble(
      key: ValueKey(messageId),
      messageId: messageId,
    );

    BoxDecoration decoration() => BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: selected
            ? theme.colorScheme.primary
            : theme.dividerColor.withValues(alpha: 0.6),
        width: selected ? 1.5 : 0.5,
      ),
    );

    switch (style) {
      case MultiModelMessageStyle.fold:
        return bubble;

      case MultiModelMessageStyle.vertical:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: decoration(),
          child: bubble,
        );

      case MultiModelMessageStyle.horizontal:
        return Container(
          decoration: decoration(),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(4),
            child: bubble,
          ),
        );

      case MultiModelMessageStyle.grid:
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 300,
            decoration: decoration(),
            clipBehavior: Clip.antiAlias,
            // Scrollable preview (mirrors the web grid card's overflowY:auto):
            // the bubble can exceed 300px without overflowing; tap opens it full.
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(4),
              child: bubble,
            ),
          ),
        );
    }
  }
}

/// A model entry in the 折叠 model list: a compact 图标 avatar (name in tooltip)
/// or, when [expanded], a chip showing the 完整名称. Selected = the 采用 sibling; a
/// streaming/pending sibling dims. Tap = 采用.
