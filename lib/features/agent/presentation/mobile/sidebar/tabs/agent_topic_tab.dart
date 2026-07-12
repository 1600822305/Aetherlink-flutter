// 话题 tab：当前智能体的话题单一列表（开头状态灯区分进行中/完成）
// + 新建话题（参考聊天侧边栏话题 tab 架构）。已完成的话题也能继续
// 发新指令。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/sidebar/widgets/agent_sidebar_widgets.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_status.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';

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
    final profile =
        profiles.where((p) => p.id == selectedProfileId).firstOrNull ??
        profiles.firstOrNull;
    if (profile == null) {
      return Center(
        child: Text(
          '还没有智能体，先到智能体 tab 新建一个',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }
    final tasks = ref
        .watch(agentTasksProvider)
        .where((t) => t.profileId == profile.id)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 标头 + 胶囊新建按钮（与聊天话题 tab 同款布局）。
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: AgentSidebarTabHeader(
            title: '${profile.emoji} ${profile.name}',
            trailing: [
              AgentSidebarPillButton(
                icon: LucideIcons.plus,
                label: '新建话题',
                // 已拍板：新话题是干净空态（像普通聊天），发第一条消息才开始
                // 任务；工作区继承自当前智能体，不单独选。
                onPressed: () {
                  ref.read(selectedAgentTaskIdProvider.notifier).select(null);
                  Navigator.of(context).pop();
                },
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

enum _TaskMenu { rename, delete }

/// 话题卡：状态色点 + 标题 + 工作区 chip + 最近事件摘要（UI 稿 §三）
/// + 右侧「更多」菜单（重命名/删除，对齐聊天话题项）。
class _TaskCard extends ConsumerWidget {
  const _TaskCard({
    required this.task,
    required this.selected,
    required this.onTap,
  });

  final AgentTask task;
  final bool selected;
  final VoidCallback onTap;

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    _TaskMenu value,
  ) async {
    switch (value) {
      case _TaskMenu.rename:
        final title = await agentPromptText(
          context,
          title: '编辑话题',
          hint: '话题名称',
          initial: task.title,
        );
        if (title != null) {
          ref.read(agentTasksProvider.notifier).rename(task.id, title);
        }
      case _TaskMenu.delete:
        final ok = await agentConfirmDialog(
          context,
          title: '删除话题',
          message: '确定要删除此话题吗？此操作不可撤销。',
        );
        if (ok) {
          if (ref.read(selectedAgentTaskIdProvider) == task.id) {
            ref.read(selectedAgentTaskIdProvider.notifier).select(null);
          }
          ref.read(agentTasksProvider.notifier).remove(task.id);
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final statusColor = agentStatusColor(context, task.status);
    // 状态只靠开头状态灯区分，卡片不描边；waitingApproval/Input 另加 ⚠ 图标。
    final needsAttention =
        task.status == AgentTaskStatus.waitingApproval ||
        task.status == AgentTaskStatus.waitingInput;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Material(
        color: selected
            ? kAgentSidebarSelectedItemBg
            : cs.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
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
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
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
                      Icon(
                        LucideIcons.triangleAlert,
                        size: 14,
                        color: statusColor,
                      ),
                    const SizedBox(width: 4),
                    AgentSidebarOverflowMenuButton<_TaskMenu>(
                      size: 16,
                      box: 20,
                      title: task.title,
                      actions: const [
                        AgentSidebarSheetAction(
                          _TaskMenu.rename,
                          LucideIcons.edit3,
                          '编辑话题',
                        ),
                        AgentSidebarSheetAction(
                          _TaskMenu.delete,
                          LucideIcons.trash,
                          '删除话题',
                          danger: true,
                        ),
                      ],
                      onSelected: (m) => _onMenu(context, ref, m),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
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
