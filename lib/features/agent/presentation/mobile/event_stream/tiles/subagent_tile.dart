import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_subagent.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/agent_event_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';

/// 子任务行（初稿 §5.5 P2 子代理）：父时间线上的 spawn_subagent 工具
/// 调用渲染为「子任务」卡——类型徽标 + 标题 + 状态/结论摘要，点击
/// 展开底部抽屉回看子代理完整事件流（全落库，防失忆）。
class SubagentTile extends StatelessWidget {
  const SubagentTile({required this.event, super.key});

  final ToolCallEvent event;

  ({String type, String title}) _parseArgs() {
    try {
      final args = jsonDecode(event.argsDetail ?? '') as Map<String, dynamic>;
      final type = args['type'] as String? ?? '';
      final desc = (args['description'] as String? ?? '').trim();
      final prompt = (args['prompt'] as String? ?? '').trim();
      final title = desc.isNotEmpty
          ? desc
          : (prompt.length > 40 ? '${prompt.substring(0, 40)}…' : prompt);
      return (type: type, title: title);
    } catch (_) {
      return (type: '', title: event.argSummary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.55);
    final args = _parseArgs();
    final running = event.state == AgentToolCallState.running;
    final (icon, iconColor) = switch (event.state) {
      AgentToolCallState.running => (LucideIcons.loaderCircle, cs.primary),
      AgentToolCallState.success => (LucideIcons.circleCheck, Colors.green),
      _ => (LucideIcons.circleX, cs.error),
    };
    return EventRail(
      node: running
          ? SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            )
          : Icon(icon, size: 14, color: iconColor),
      child: InkWell(
        onTap: () => _showSubagentSheet(context, event),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.bot, size: 14, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    '子任务',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (args.type.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        args.type,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontFamily: 'monospace',
                          color: cs.primary,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Icon(LucideIcons.chevronRight, size: 14, color: muted),
                ],
              ),
              if (args.title.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  args.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (event.resultSummary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '↳ ${event.resultSummary}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: event.state == AgentToolCallState.failure
                        ? cs.error
                        : muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部抽屉：子代理完整事件流（含审批卡——子代理等审批时在这里裁决）。
void _showSubagentSheet(BuildContext context, ToolCallEvent event) {
  final childTaskId = subagentTaskIdFor(event.id);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) =>
          _SubagentEventStream(taskId: childTaskId, controller: scrollController),
    ),
  );
}

class _SubagentEventStream extends ConsumerWidget {
  const _SubagentEventStream({required this.taskId, required this.controller});

  final String taskId;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final events = ref.watch(agentTaskEventsProvider(taskId));
    return events.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败：$e')),
      data: (list) => list.isEmpty
          ? Center(
              child: Text(
                '子代理尚未产生事件',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            )
          : ListView.builder(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              itemCount: list.length,
              itemBuilder: (context, i) =>
                  AgentEventTile(event: list[i], taskId: taskId),
            ),
    );
  }
}
