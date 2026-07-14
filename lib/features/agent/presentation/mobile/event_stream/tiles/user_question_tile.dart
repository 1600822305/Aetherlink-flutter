import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/event_rail.dart';

/// ask_user 提问在时间线上的紧凑记录：问题一行 + 回答状态。
/// 实际作答走输入框上方的建议答案面板（AgentFollowupPanel）。
class UserQuestionTile extends ConsumerWidget {
  const UserQuestionTile({
    required this.event,
    required this.taskId,
    super.key,
  });

  final UserQuestionEvent event;
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final events = ref.watch(agentTaskEventsProvider(taskId)).value ?? const [];
    final answer = userQuestionAnswer(event, events);
    final answered = answer != null;

    return EventRail(
      node: Icon(
        answered ? LucideIcons.circleCheck : LucideIcons.circleHelp,
        size: 14,
        color: cs.primary,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: cs.primary.withValues(alpha: answered ? 0.25 : 0.45),
          ),
          color: cs.primary.withValues(alpha: answered ? 0.035 : 0.06),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.messageCircleQuestion,
                  size: 14,
                  color: cs.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    event.question,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              answered ? '回答：${answer.text}' : '等待回答（在下方面板中选择或输入）',
              style: theme.textTheme.bodySmall?.copyWith(
                color: answered ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
