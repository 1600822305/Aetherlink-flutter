// 话题 tab：当前智能体的话题单一列表（开头状态灯区分进行中/完成）
// + 搜索 / 固定 / 新建话题（对齐聊天侧边栏话题 tab 架构）。
// 已完成的话题也能继续发新指令。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/workspace_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_runner.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/sidebar/widgets/agent_sidebar_widgets.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_status.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_ops/primary_terminal_sheet.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

class AgentTopicTab extends ConsumerStatefulWidget {
  const AgentTopicTab({super.key});

  @override
  ConsumerState<AgentTopicTab> createState() => _AgentTopicTabState();
}

class _AgentTopicTabState extends ConsumerState<AgentTopicTab> {
  final TextEditingController _searchController = TextEditingController();
  bool _searchOpen = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        _query = '';
      }
    });
  }

  void _openTask(String taskId) {
    Haptics.instance.onListItem();
    ref.read(selectedAgentTaskIdProvider.notifier).select(taskId);
    Navigator.of(context).pop();
  }

  /// 新建话题（对齐聊天 TopicsController.create）：立即创建一条空白
  /// 草稿话题并选中，列表按最近活跃排序自然浮到顶部；当前已有
  /// 空白草稿时直接复用，不堆重复空话题。
  Future<void> _createTopic(AgentProfile profile, List<AgentTask> tasks) async {
    final navigator = Navigator.of(context);
    final existingDraft = tasks
        .where((t) => t.status == AgentTaskStatus.draft)
        .firstOrNull;
    final task =
        existingDraft ??
        await ref
            .read(agentTaskRunnerProvider.notifier)
            .createDraft(
              profile: profile,
              mode: ref.read(agentUiSettingsControllerProvider).defaultMode,
            );
    ref.read(selectedAgentTaskIdProvider.notifier).select(task.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
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
    // 与聊天话题 tab 同款排序：固定的话题置顶，其余按最近活跃
    // （updatedAt）降序，新建/刚活跃的话题自然浮在顶部。
    final tasks =
        ref
            .watch(agentTasksProvider)
            .where((t) => t.profileId == profile.id && !t.isSubtask)
            .toList()
          ..sort((a, b) {
            if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
            return b.updatedAt.compareTo(a.updatedAt);
          });

    final query = _query.trim().toLowerCase();
    final searching = query.isNotEmpty;
    final visible = searching
        ? tasks.where((t) => t.title.toLowerCase().contains(query)).toList()
        : tasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 标头 + 搜索开关 + 胶囊新建按钮（与聊天话题 tab 同款布局）。
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: AgentSidebarTabHeader(
            title: '${profile.emoji} ${profile.name}',
            trailing: [
              AgentSidebarMutedIconButton(
                icon: LucideIcons.search,
                size: 18,
                box: 28,
                color: _searchOpen ? cs.primary : kAgentSidebarMutedIcon,
                onPressed: _toggleSearch,
              ),
              const SizedBox(width: 8),
              AgentSidebarPillButton(
                icon: LucideIcons.plus,
                label: '新建话题',
                // 对齐聊天：立即创建空白草稿话题并选中（发第一条消息
                // 才启动任务）；工作区继承自当前智能体，不单独选。
                onPressed: () => _createTopic(profile, tasks),
              ),
            ],
          ),
        ),
        if (_searchOpen)
          AgentSidebarSearchField(
            controller: _searchController,
            hint: '搜索话题...',
            onChanged: (v) => setState(() => _query = v),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final t in visible)
                _TaskCard(
                  task: t,
                  selected: t.id == selectedTaskId,
                  onTap: () => _openTask(t.id),
                ),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    searching ? '没有找到话题' : '还没有话题，点右上角 + 新建',
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

enum _TaskMenu { rename, workspace, togglePin, delete }

/// 话题卡：状态色点 + 标题 + 工作区 chip + 活跃时间
/// （UI 稿 §三）+ 右侧「更多」菜单（重命名/固定/删除）
/// + 两击确认快速删除（对齐聊天话题项）。
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
      case _TaskMenu.workspace:
        await _switchWorkspace(context, ref);
      case _TaskMenu.togglePin:
        ref.read(agentTasksProvider.notifier).togglePin(task.id);
      case _TaskMenu.delete:
        final ok = await agentConfirmDialog(
          context,
          title: '删除话题',
          message: '确定要删除此话题吗？此操作不可撤销。',
        );
        if (ok) _delete(ref);
    }
  }

  /// 切换话题绑定的工作区：引擎跑动中（运行/等审批/等输入）工具正在
  /// 该工作区里执行，中途换会错位，先拦下；已暂停/完成等其余状态
  /// 可换，下一轮生效。
  Future<void> _switchWorkspace(BuildContext context, WidgetRef ref) async {
    if (task.isActive && task.status != AgentTaskStatus.paused) {
      AppToast.warning(context, '任务进行中，先暂停/完成后再切换工作区');
      return;
    }
    final workspaces = ref.read(recentWorkspacesViewProvider);
    final picked = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('切换工作区', style: TextStyle(fontSize: 16)),
        children: [
          for (final ws in workspaces)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop((ws.id, ws.name)),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.folderTree,
                    size: 16,
                    color: ws.id == task.workspaceId
                        ? Theme.of(ctx).colorScheme.primary
                        : kAgentSidebarMutedIcon,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ws.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: ws.id == task.workspaceId
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (ws.id == task.workspaceId)
                    Icon(
                      LucideIcons.check,
                      size: 14,
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                ],
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(('', '')),
            child: Row(
              children: [
                Icon(
                  LucideIcons.folderPlus,
                  size: 16,
                  color: Theme.of(ctx).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '选目录新建绑定…',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;
    var (id, name) = picked;
    if (id.isEmpty) {
      // 用主终端选择器新建一个工作区（不切换当前工作区，
      // 对齐智能体编辑页的绑定交互）。
      if (!context.mounted) return;
      final workspace = await pickFolderWithTerminalPicker(
        context,
        ref,
        switchTo: false,
      );
      if (workspace == null) return;
      id = workspace.id;
      name = workspace.name;
    }
    if (id == task.workspaceId) return;
    await ref
        .read(agentTasksProvider.notifier)
        .updateWorkspace(task.id, id, name);
  }

  void _delete(WidgetRef ref) {
    if (ref.read(selectedAgentTaskIdProvider) == task.id) {
      ref.read(selectedAgentTaskIdProvider.notifier).select(null);
    }
    ref.read(agentTasksProvider.notifier).remove(task.id);
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
                    if (task.pinned) ...[
                      const Icon(
                        LucideIcons.pin,
                        size: 12,
                        color: kAgentSidebarMutedIcon,
                      ),
                      const SizedBox(width: 4),
                    ],
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
                      actions: [
                        const AgentSidebarSheetAction(
                          _TaskMenu.rename,
                          LucideIcons.edit3,
                          '编辑话题',
                        ),
                        const AgentSidebarSheetAction(
                          _TaskMenu.workspace,
                          LucideIcons.folderTree,
                          '切换工作区',
                        ),
                        AgentSidebarSheetAction(
                          _TaskMenu.togglePin,
                          task.pinned ? LucideIcons.pinOff : LucideIcons.pin,
                          task.pinned ? '取消固定' : '固定话题',
                        ),
                        const AgentSidebarSheetAction(
                          _TaskMenu.delete,
                          LucideIcons.trash,
                          '删除话题',
                          danger: true,
                        ),
                      ],
                      onSelected: (m) => _onMenu(context, ref, m),
                    ),
                    const SizedBox(width: 2),
                    // 两击变红即确认（对齐聊天 pendingDelete 交互），
                    // 不再弹确认框。
                    AgentSidebarConfirmDeleteButton(
                      size: 16,
                      box: 20,
                      color: cs.onSurface,
                      onConfirm: () => _delete(ref),
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
                    Expanded(
                      child: Text(
                        '第${task.rounds}轮 · ${formatElapsed(task.elapsed)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    Text(
                      _formatTaskTime(task.updatedAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `MM/DD HH:mm`（对齐聊天话题项的时间格式）。
String _formatTaskTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}
