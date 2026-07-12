// 话题 tab：当前智能体的话题单一列表（开头状态灯区分进行中/完成）
// + 新建话题（参考聊天侧边栏话题 tab 架构）。已完成的话题也能继续
// 发新指令。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_status.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';

/// 选中话题底色：与聊天侧边栏 `kSidebarSelectedItemBg` 同值（样式对齐，
/// 不 import chat 内部）。
const Color _kSelectedTopicBg = Color(0x141976D2);

class AgentTopicTab extends ConsumerWidget {
  const AgentTopicTab({super.key});

  void _openTask(BuildContext context, WidgetRef ref, String taskId) {
    Haptics.instance.onListItem();
    ref.read(selectedAgentTaskIdProvider.notifier).select(taskId);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final profiles = ref.watch(agentProfilesProvider);
    final selectedProfileId = ref.watch(selectedAgentProfileIdProvider);
    final selectedTaskId = ref.watch(selectedAgentTaskIdProvider);
    final profile = profiles.firstWhere(
      (p) => p.id == selectedProfileId,
      orElse: () => profiles.first,
    );
    final tasks = ref
        .watch(agentTasksProvider)
        .where((t) => t.profileId == profile.id)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 当前智能体标头 + 新建话题（与聊天话题 tab 的助手标头一致定位）。
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              Text(profile.emoji, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: '新建话题',
                // 已拍板：新话题是干净空态（像普通聊天），发第一条消息才开始
                // 任务；工作区继承自当前智能体，不单独选。
                onPressed: () {
                  ref.read(selectedAgentTaskIdProvider.notifier).select(null);
                  Navigator.of(context).pop();
                },
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(LucideIcons.plus),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final t in tasks)
                _TaskCard(
                  task: t,
                  selected: t.id == selectedTaskId,
                  onTap: () => _openTask(context, ref, t.id),
                ),
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    '还没有话题，点右上角 + 新建',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '共 ${tasks.length} 个话题',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
  }
}

/// 话题卡：状态色点 + 标题 + 工作区 chip + 最近事件摘要（UI 稿 §三）。
class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.selected,
    required this.onTap,
  });

  final AgentTask task;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final statusColor = agentStatusColor(context, task.status);
    final needsAttention = task.status == AgentTaskStatus.waitingApproval ||
        task.status == AgentTaskStatus.waitingInput;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Material(
        color: selected ? _kSelectedTopicBg : cs.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: needsAttention
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.6)),
                  )
                : null,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: task.status == AgentTaskStatus.cancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (needsAttention)
                      Icon(LucideIcons.triangleAlert,
                          size: 14, color: statusColor),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.workspaceName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '第${task.rounds}轮 · ${formatElapsed(task.elapsed)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
                if (task.lastEventSummary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.lastEventSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
