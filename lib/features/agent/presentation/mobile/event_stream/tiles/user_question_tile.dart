import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_runner.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';

/// ask_user 提问卡（内嵌事件流）：问题正文 + 可点选的预设选项。
/// 任务在 waitingInput 且该提问未被回答时选项可点，点选即以该选项
/// 作为用户回复落消息并续跑；历史提问卡选项禁用（答案见其后的
/// 用户消息气泡）。开放式提问无选项，用底部输入框回答。
class UserQuestionTile extends ConsumerWidget {
  const UserQuestionTile({required this.event, required this.taskId, super.key});

  final UserQuestionEvent event;
  final String taskId;

  bool _answered(List<AgentEvent> events) => events.any(
        (e) => e is UserMessageEvent && e.seq > event.seq,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    const blue = Colors.blue;
    final task = ref
        .watch(agentTasksProvider)
        .where((t) => t.id == taskId)
        .firstOrNull;
    final events =
        ref.watch(agentTaskEventsProvider(taskId)).value ?? const [];
    final active = task != null &&
        task.status == AgentTaskStatus.waitingInput &&
        !_answered(events);

    return EventRail(
      node: const Icon(LucideIcons.circleHelp, size: 14, color: blue),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: blue.withValues(alpha: 0.5)),
          color: blue.withValues(alpha: 0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              active ? '? 等待回答' : '? 提问',
              style: theme.textTheme.labelMedium?.copyWith(
                color: blue,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(event.question, style: theme.textTheme.bodyMedium),
            if (event.options.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in event.options)
                    ActionChip(
                      label: Text(option),
                      visualDensity: VisualDensity.compact,
                      onPressed: active
                          ? () => ref
                              .read(agentTaskRunnerProvider.notifier)
                              .sendMessage(task, option)
                          : null,
                    ),
                ],
              ),
            ],
            if (active && event.options.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '在下方输入框回复以继续',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
