import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';

/// Renders a `WORLD_BOOK_INJECTION` block: a collapsed 「本轮注入 N 条世界书」
/// chip (with the estimated token cost) that expands to the entry names.
/// Styled like [MemoryInjectionBlockView] so the two info blocks read as a set.
class WorldBookInjectionBlockView extends StatefulWidget {
  const WorldBookInjectionBlockView({required this.block, super.key});

  final WorldBookInjectionBlock block;

  @override
  State<WorldBookInjectionBlockView> createState() =>
      _WorldBookInjectionBlockViewState();
}

class _WorldBookInjectionBlockViewState
    extends State<WorldBookInjectionBlockView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final entries = widget.block.entries;
    final hasDetail = entries.isNotEmpty;
    final tokens = widget.block.estimatedTokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.tertiary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: hasDetail
                ? () => setState(() => _expanded = !_expanded)
                : null,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(LucideIcons.bookMarked, size: 15, color: cs.tertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '本轮注入 ${widget.block.count} 条世界书'
                    '${tokens > 0 ? ' · 约 $tokens tokens' : ''}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                if (hasDetail)
                  Icon(
                    _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 15,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ),
          if (_expanded && hasDetail) ...[
            Divider(height: 14, color: cs.tertiary.withValues(alpha: 0.15)),
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      LucideIcons.dot,
                      size: 14,
                      color: cs.tertiary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      entries[i],
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
