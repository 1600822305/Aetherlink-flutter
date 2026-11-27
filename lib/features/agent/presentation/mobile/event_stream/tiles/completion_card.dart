import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/markdown_access.dart';
import 'package:aetherlink_flutter/app/di/message_selection_access.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/loop/finish_result_streamer.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_copy_menu.dart';

/// attempt_completion 完成卡片（对标 Roo completion_result）：任务的唯一
/// 完成标记。结果正文在卡片里边生成边显示，头部「任务完成 · N 轮」，
/// 取代原来的正文 + 「任务完成」状态行两段式，避免看起来重复。
/// 被拒（缺 result / stop hook 拦下）时退化成一行弱化提示（仍挂在时间线上）。
/// 正常完成/提交中的卡片是最终交付物，不挂时间线左轨，占满整行宽度。
class CompletionCard extends StatelessWidget {
  const CompletionCard({required this.event, super.key});

  final ToolCallEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.5);
    final running = event.state == AgentToolCallState.running;
    final ok = event.state == AgentToolCallState.success;
    final result = completionResultOf(event);

    if (!running && !ok) {
      return EventRail(
        node: Icon(LucideIcons.circleX, size: 12, color: muted),
        child: LongPressCopy(
          entries: () => [
            CopyEntry(
              '原因',
              event.resultSummary.isNotEmpty ? event.resultSummary : '完成未通过',
            ),
          ],
          child: Text(
            event.resultSummary.isNotEmpty ? event.resultSummary : '完成未通过',
            style: theme.textTheme.labelSmall?.copyWith(color: muted),
          ),
        ),
      );
    }

    final accent = Colors.green.shade600;
    final title = running
        ? '正在提交结果…'
        : '任务完成${event.resultSummary.isNotEmpty ? ' · ${event.resultSummary}' : ''}';
    final style = theme.textTheme.bodyMedium?.copyWith(height: 1.5);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部长按复制整段结果（正文本身可选区复制，生成中不可选）。
            LongPressCopy(
              entries: () => [CopyEntry('结果', result)],
              child: Row(
              children: [
                Icon(LucideIcons.circleCheck, size: 14, color: accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            ),
            if (result.isNotEmpty) ...[
              const SizedBox(height: 6),
              running
                  ? StreamingMarkdownBody(content: '$result▍', style: style)
                  : SettingAwareMessageSelectionArea(
                      child: AppMarkdown(content: result, style: style),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}
