import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/search/chat_search.dart';

/// A single search result row (port of the web `SearchResultItem`): icon +
/// topic name + type chip, a two-line highlighted snippet, and the timestamp.
class SearchResultItem extends StatelessWidget {
  const SearchResultItem({
    super.key,
    required this.hit,
    required this.active,
    required this.onSelect,
  });

  final ChatSearchHit hit;
  final bool active;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTopic = hit.kind == ChatSearchHitKind.topic;

    return Material(
      color: active
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? theme.colorScheme.primary : theme.dividerColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isTopic ? LucideIcons.hash : LucideIcons.messageSquare,
                    size: 15,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      hit.topicName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SearchTypeChip(label: isTopic ? '话题' : _roleLabel(hit.role)),
                ],
              ),
              const SizedBox(height: 6),
              SearchHighlightedText(
                text: hit.snippet,
                ranges: hit.matchRanges,
                baseStyle: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    LucideIcons.clock,
                    size: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(hit.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _roleLabel(MessageRole? role) {
    switch (role) {
      case MessageRole.assistant:
        return '助手';
      case MessageRole.system:
      // 虚拟根（结构性哨兵）不会出现在搜索结果里；归入「系统」仅为穷尽性。
      case MessageRole.root:
        return '系统';
      case MessageRole.user:
      case null:
        return '用户';
    }
  }

  static String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

/// A small outlined chip labelling the hit kind / message role.
class SearchTypeChip extends StatelessWidget {
  const SearchTypeChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Renders [text] with [ranges] highlighted (port of the web `HighlightedText`)
/// — split into spans rather than injecting HTML, so it stays safe.
class SearchHighlightedText extends StatelessWidget {
  const SearchHighlightedText({
    super.key,
    required this.text,
    required this.ranges,
    required this.baseStyle,
  });

  final String text;
  final List<MatchRange> ranges;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightStyle = baseStyle.copyWith(
      backgroundColor: theme.colorScheme.tertiaryContainer,
      color: theme.colorScheme.onTertiaryContainer,
      fontWeight: FontWeight.w600,
    );

    final length = text.length;
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      final start = range.start.clamp(0, length);
      final end = range.end.clamp(start, length);
      if (start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, start)));
      }
      if (end > start) {
        spans.add(
          TextSpan(text: text.substring(start, end), style: highlightStyle),
        );
      }
      cursor = end;
    }
    if (cursor < length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
