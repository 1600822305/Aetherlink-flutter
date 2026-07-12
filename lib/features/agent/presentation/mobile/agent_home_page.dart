import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/agent_sidebar.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/agent_task_shell.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/new_topic_sheet.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_status.dart';

/// 智能体模式主界面壳（/agent）：侧栏宿主 + 当前话题的任务工作台。
/// UI 稿 §二/§四；与聊天主界面通过侧栏底部按钮互切，模式持久化。
class AgentHomePage extends ConsumerWidget {
  const AgentHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profiles = ref.watch(agentProfilesProvider);
    final profileId = ref.watch(selectedAgentProfileIdProvider);
    final profile = profiles.firstWhere(
      (p) => p.id == profileId,
      orElse: () => profiles.first,
    );
    final tasks = ref.watch(agentTasksProvider);
    final taskId = ref.watch(selectedAgentTaskIdProvider);
    AgentTask? task;
    for (final t in tasks) {
      if (t.id == taskId && t.profileId == profile.id) task = t;
    }

    return Scaffold(
      drawer: const AgentSidebar(),
      appBar: task == null
          ? AppBar(
              title: Text('${profile.emoji} ${profile.name}'),
              titleTextStyle: theme.textTheme.titleMedium,
            )
          : AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  AgentStatusLine(task: task),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(LucideIcons.ellipsis, size: 20),
                  onPressed: () {},
                ),
              ],
            ),
      body: task == null
          ? _EmptyState(profileName: profile.name)
          : AgentTaskShell(task: task),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.profileName});

  final String profileName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.bot,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            '「$profileName」还没有任务',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => showNewTopicSheet(context),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('新建话题'),
          ),
        ],
      ),
    );
  }
}
