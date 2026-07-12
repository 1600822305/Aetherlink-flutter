import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/app_main_mode.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/new_topic_sheet.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_status.dart';

/// 智能体侧边栏：智能体列表（上）+ 当前智能体的话题列表（下）+
/// 底部「回聊天」（UI 稿 §三）。
class AgentSidebar extends ConsumerWidget {
  const AgentSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profiles = ref.watch(agentProfilesProvider);
    final selectedProfileId = ref.watch(selectedAgentProfileIdProvider);
    final selectedTaskId = ref.watch(selectedAgentTaskIdProvider);
    final tasks = ref
        .watch(agentTasksProvider)
        .where((t) => t.profileId == selectedProfileId)
        .toList();
    final active = tasks.where((t) => t.isActive).toList();
    final history = tasks.where((t) => !t.isActive).toList();

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: [
                  const _SectionLabel(label: '智能体'),
                  for (final p in profiles)
                    _ProfileRow(
                      emoji: p.emoji,
                      name: p.name,
                      selected: p.id == selectedProfileId,
                      onTap: () {
                        ref
                            .read(selectedAgentProfileIdProvider.notifier)
                            .select(p.id);
                        ref
                            .read(selectedAgentTaskIdProvider.notifier)
                            .select(null);
                      },
                    ),
                  _ActionRow(
                    icon: LucideIcons.plus,
                    label: '新建智能体',
                    onTap: () {},
                  ),
                  const Divider(height: 24),
                  _SectionLabel(
                    label:
                        '话题（${profiles.firstWhere((p) => p.id == selectedProfileId, orElse: () => profiles.first).name}）',
                  ),
                  if (active.isNotEmpty) ...[
                    _SubLabel(label: '进行中 (${active.length})'),
                    for (final t in active)
                      _TaskCard(
                        task: t,
                        selected: t.id == selectedTaskId,
                        onTap: () => _openTask(context, ref, t.id),
                      ),
                  ],
                  if (history.isNotEmpty) ...[
                    const _SubLabel(label: '历史'),
                    for (final t in history)
                      _TaskCard(
                        task: t,
                        selected: t.id == selectedTaskId,
                        onTap: () => _openTask(context, ref, t.id),
                      ),
                  ],
                  _ActionRow(
                    icon: LucideIcons.plus,
                    label: '新建话题',
                    onTap: () {
                      Navigator.of(context).pop();
                      showNewTopicSheet(context);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _BackToChatRow(
              onTap: () {
                ref
                    .read(appMainModeControllerProvider.notifier)
                    .use(AppMainMode.chat);
                context.go(AppRouter.chatPath);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openTask(BuildContext context, WidgetRef ref, String taskId) {
    ref.read(selectedAgentTaskIdProvider.notifier).select(taskId);
    Navigator.of(context).pop();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SubLabel extends StatelessWidget {
  const _SubLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.emoji,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (selected)
                Icon(LucideIcons.check,
                    size: 16, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 16, color: muted),
              const SizedBox(width: 10),
              Text(label,
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
            ],
          ),
        ),
      ),
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
        color: selected
            ? cs.primary.withValues(alpha: 0.08)
            : cs.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: needsAttention
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.6)),
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

class _BackToChatRow extends StatelessWidget {
  const _BackToChatRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.arrowLeftRight,
                  size: 18, color: theme.colorScheme.onSurface),
              const SizedBox(width: 8),
              Text('回聊天', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
