import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/agent_mcp_page.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/agent_profile_edit_page.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/agent_skills_page.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/agent_task_shell.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/sidebar/agent_sidebar.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/sidebar/tabs/agent_settings_tab.dart';
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
    final profile =
        profiles.where((p) => p.id == profileId).firstOrNull ??
        profiles.firstOrNull;
    final tasks = ref.watch(agentTasksProvider);
    final taskId = ref.watch(selectedAgentTaskIdProvider);
    AgentTask? task;
    for (final t in tasks) {
      if (t.id == taskId && t.profileId == profile?.id) task = t;
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
                profile == null ? '智能体' : '${profile.emoji} ${profile.name}',
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
        // 三点下拉菜单（决策 30）：智能体专属能力入口。当前有
        // 「技能」「MCP」，记忆/工作流/rules 后续逐项加入。
        actions: [
          Builder(
            builder: (context) => PopupMenuButton<String>(
              tooltip: '更多',
              icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
              position: PopupMenuPosition.under,
              // 秒开：去掉弹出/收起过渡动画。
              popUpAnimationStyle: AnimationStyle.noAnimation,
              onSelected: (value) {
                if (value == 'skills') showAgentSkillsPage(context);
                if (value == 'mcp') showAgentMcpPage(context);
                if (value == 'settings') showAgentSettingsPage(context);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'skills',
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.sparkles,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('技能'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'mcp',
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.plug,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('MCP'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.settings,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('设置'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: task != null && task.status != AgentTaskStatus.draft
          ? AgentTaskShell(task: task)
          : profile != null
          // 空白草稿话题与无话题选中同款空态；草稿把 task 传给输入栏，
          // 第一条消息落在该话题上而不是另建新任务。
          ? _DraftTopicView(profile: profile, task: task)
          : Center(
              child: Text(
                '还没有智能体，去侧边栏新建一个',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
    );
  }
}

/// 干净新话题（草稿态）：像普通聊天一样空白，发第一条消息才开始任务。
/// 工作区继承自当前智能体（已拍板：工作区绑在智能体上，在智能体
/// 设置里改），未绑定时在这里提醒去设置。
class _DraftTopicView extends StatelessWidget {
  const _DraftTopicView({required this.profile, this.task});

  final AgentProfile profile;

  /// 非空 = 已在列表占位的草稿话题；空 = 无话题选中。
  final AgentTask? task;

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
        AgentInputBar(task: task),
      ],
    );
  }
}
