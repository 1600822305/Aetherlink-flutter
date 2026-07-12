import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_status.dart';

/// 思考过程行（Devin 同款）：默认收起为「▸ 思考了 Xs」，
/// 流式中显示「思考中…」并自动展开；点开看完整思考文字。
/// 脱离时间线左轨（不进后续上下文，仅供观察）。
class ReasoningTile extends StatefulWidget {
  const ReasoningTile({required this.event, super.key});

  final ReasoningEvent event;

  @override
  State<ReasoningTile> createState() => _ReasoningTileState();
}

class _ReasoningTileState extends State<ReasoningTile> {
  bool? _expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final streaming = widget.event.streaming;
    // 流式中默认展开看实时思考；结束后默认收起。用户手动切换后以手动为准。
    final expanded = _expanded ?? streaming;
    final muted = cs.onSurface.withValues(alpha: 0.55);

    final elapsed = widget.event.elapsed;
    final title = streaming
        ? '思考中…'
        : elapsed != null
            ? '思考了 ${formatElapsed(elapsed)}'
            : '思考过程';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                  size: 14,
                  color: muted,
                ),
                const SizedBox(width: 6),
                Icon(LucideIcons.brain, size: 13, color: muted),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ),
        if (expanded && widget.event.text.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(left: 20, bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: cs.onSurface.withValues(alpha: 0.15),
                  width: 2,
                ),
              ),
            ),
            child: Text(
              streaming ? '${widget.event.text}▍' : widget.event.text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}
