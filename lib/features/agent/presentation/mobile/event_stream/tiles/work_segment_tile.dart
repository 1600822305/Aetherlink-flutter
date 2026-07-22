import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/agent_event_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/timeline_blocks.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_status.dart';

/// 已完成工作段的折叠摘要块：「▸ 检索查看 · 36s · 14 个操作」，
/// 点开可回看每一行（含夹在其间的思考，UI 稿 §4.1 工作段折叠）。
class WorkSegmentTile extends StatefulWidget {
  const WorkSegmentTile({required this.block, required this.taskId, super.key});

  final SegmentBlock block;
  final String taskId;

  @override
  State<WorkSegmentTile> createState() => _WorkSegmentTileState();
}

class _WorkSegmentTileState extends State<WorkSegmentTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tools = widget.block.toolCalls.toList();
    final failedCount = tools
        .where((e) => e.state == AgentToolCallState.failure)
        .length;
    // 只有整段全部失败才整体标红；部分失败时段头保持中性，
    // 另附琥珀色失败计数，避免看起来像全部操作都挂了。
    final allFailed = tools.isNotEmpty && failedCount == tools.length;
    var totalMs = 0;
    for (final e in tools) {
      totalMs += e.elapsed?.inMilliseconds ?? 500;
    }
    final elapsed = formatElapsed(Duration(milliseconds: totalMs));
    final stats = segmentLineStats(widget.block);
    final statsLabel = stats.added + stats.removed > 0
        ? ' · +${stats.added} −${stats.removed}'
        : '';
    final summaryColor = allFailed
        ? cs.error
        : cs.onSurface.withValues(alpha: 0.6);
    final warnColor = Colors.orange.shade800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EventRail(
          node: Icon(
            allFailed
                ? LucideIcons.circleX
                : failedCount > 0
                    ? LucideIcons.triangleAlert
                    : LucideIcons.layers,
            size: 14,
            color: allFailed
                ? summaryColor
                : failedCount > 0
                    ? warnColor
                    : summaryColor,
          ),
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? LucideIcons.chevronDown
                        : LucideIcons.chevronRight,
                    size: 14,
                    color: summaryColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text:
                            '${segmentSummary(widget.block)} · $elapsed · '
                            '${tools.length} 个操作$statsLabel',
                        children: [
                          if (allFailed)
                            const TextSpan(text: ' · ✗')
                          else if (failedCount > 0)
                            TextSpan(
                              text: ' · $failedCount 失败',
                              style: TextStyle(color: warnColor),
                            ),
                        ],
                      ),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: summaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 与 ReasoningTile 同理：长段落瞬间收起会让滚动偏移来不及钳位、
        // 闪出空白，用 AnimatedSize 渐变收起让 clamp 逐帧跟随。
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in widget.block.events)
                      AgentEventTile(event: e, taskId: widget.taskId),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
