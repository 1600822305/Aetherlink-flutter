import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/agent_task_shell.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/sidebar/agent_sidebar.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_input_bar.dart';
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
          ? _DraftTopicView(profile: profile)
          : AgentTaskShell(task: task),
    );
  }
}

/// 干净新话题（草稿态）：像普通聊天一样空白，发第一条消息才开始任务。
/// 工作区继承自当前智能体（已拍板：工作区绑在智能体上，在智能体
/// 设置里改），未绑定时在这里提醒去设置。
class _DraftTopicView extends StatelessWidget {
  const _DraftTopicView({required this.profile});

  final AgentProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bound = profile.workspaceName != null;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(profile.emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.folderTree,
                        size: 14,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        bound
                            ? profile.workspaceName!
                            : '未绑定工作区 · 去智能体设置选择',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  bound ? '发送第一条消息开始任务' : '绑定工作区后即可开始任务',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        const AgentInputBar(),
      ],
    );
  }
}
