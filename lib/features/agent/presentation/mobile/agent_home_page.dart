import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/agent_profile_edit_page.dart';
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

    // 顶栏 chrome 与主聊天同款：纸面 surface、无阴影、1px 底分隔线。
    return Scaffold(
      drawer: const AgentSidebar(),
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        titleSpacing: 0,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: '打开侧边栏',
            icon: const Icon(LucideIcons.menu, size: 20),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: task == null
            ? Text(
                '${profile.emoji} ${profile.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AgentStatusLine(task: task),
                ],
              ),
        actions: task == null
            ? null
            : [_TaskMenuButton(task: task), const SizedBox(width: 4)],
      ),
      body: task == null
          ? _DraftTopicView(profile: profile)
          : AgentTaskShell(task: task),
    );
  }
}

/// 话题顶栏「…」菜单：重命名 / 删除话题（UI 先行阶段写会话内 provider）。
class _TaskMenuButton extends ConsumerWidget {
  const _TaskMenuButton({required this.task});

  final AgentTask task;

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: task.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名话题'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (title != null && title.isNotEmpty) {
      ref.read(agentTasksProvider.notifier).rename(task.id, title);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除话题'),
        content: Text('确定删除「${task.title}」？事件流记录将一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      ref.read(selectedAgentTaskIdProvider.notifier).select(null);
      ref.read(agentTasksProvider.notifier).remove(task.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(LucideIcons.ellipsis, size: 20),
      onSelected: (value) => switch (value) {
        'rename' => _rename(context, ref),
        'delete' => _delete(context, ref),
        _ => null,
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(LucideIcons.pencil, size: 16),
              SizedBox(width: 10),
              Text('重命名话题'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(LucideIcons.trash2, size: 16),
              SizedBox(width: 10),
              Text('删除话题'),
            ],
          ),
        ),
      ],
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
                Material(
                  color: cs.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    // 点工作区 chip 直达智能体编辑页（绑定/换绑工作区）。
                    onTap: () =>
                        showAgentProfileEditPage(context, profile: profile),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
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
                            bound ? profile.workspaceName! : '未绑定工作区 · 点这里去绑定',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
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
