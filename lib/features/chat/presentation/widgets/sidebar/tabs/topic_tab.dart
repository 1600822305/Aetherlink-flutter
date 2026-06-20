// 话 (topic) tab: list, grouping, per-item actions.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/dialogs/sidebar_dialogs.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/sidebar_tokens.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/sidebar_buttons.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/sidebar_lists.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/sidebar_menus.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';

class TopicTab extends ConsumerStatefulWidget {
  const TopicTab({super.key});

  @override
  ConsumerState<TopicTab> createState() => _TopicTabState();
}

class _TopicTabState extends ConsumerState<TopicTab> {
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

  void _selectTopic(String id) {
    Haptics.instance.onListItem();
    ref.read(currentTopicIdProvider.notifier).set(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;

    final current = ref.watch(currentAssistantProvider);
    final topics = ref.watch(currentAssistantTopicsProvider);
    final selectedTopicId = ref.watch(currentTopicIdProvider);
    final multipleAssistants =
        (ref.watch(assistantsProvider).asData?.value ?? const <Assistant>[])
            .length >
        1;

    final query = _query.trim().toLowerCase();
    final searching = query.isNotEmpty;
    final filtered = searching
        ? topics.where((t) => t.name.toLowerCase().contains(query)).toList()
        : const <Topic>[];

    final groups = current == null
        ? const <Group>[]
        : ref.watch(topicGroupsProvider(current.id));
    final ungrouped = ref.watch(ungroupedTopicsProvider);
    final byId = <String, Topic>{for (final t in topics) t.id: t};

    Widget item(Topic t) => _TopicItem(
      topic: t,
      selected: selectedTopicId == t.id,
      canMove: multipleAssistants,
      onSelect: () => _selectTopic(t.id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: SidebarTabHeader(
            title: current?.name ?? '所有话题',
            trailing: [
              SidebarMutedIconButton(
                icon: LucideIcons.search,
                size: 18,
                box: 28,
                color: _searchOpen
                    ? theme.colorScheme.primary
                    : kSidebarMutedIcon,
                onPressed: _toggleSearch,
              ),
              const SizedBox(width: 8),
              // 创建话题分组: bordered icon-only button (radius 6).
              _BorderedIconButton(
                icon: LucideIcons.folderPlus,
                borderColor: textSecondary,
                color: textPrimary,
                onTap: current == null
                    ? null
                    : () => showCreateGroupDialog(
                        context,
                        ref,
                        type: GroupType.topic,
                        assistantId: current.id,
                      ),
              ),
              const SizedBox(width: 4),
              SidebarPillButton(
                icon: LucideIcons.plus,
                label: '新建话题',
                onPressed: current == null
                    ? null
                    : () =>
                          ref.read(topicsProvider.notifier).create(current.id),
              ),
            ],
          ),
        ),
        if (_searchOpen)
          SidebarSearchField(
            controller: _searchController,
            hint: '搜索话题...',
            onChanged: (v) => setState(() => _query = v),
          ),
        Expanded(
          child: current == null
              ? SidebarEmptyHint(text: '请先在「助手」标签选择一个助手', color: textSecondary)
              : searching
              ? ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    if (filtered.isEmpty)
                      SidebarEmptyHint(text: '没有找到话题', color: textSecondary)
                    else
                      for (final t in filtered) item(t),
                  ],
                )
              // Same as the assistant tab: a non-scrolling column where only
              // the ungrouped list box scrolls internally and the "共 N 个"
              // count is glued directly below it (1:1 with the web).
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (groups.isEmpty)
                        SidebarEmptyHint(text: '没有话题分组', color: textSecondary)
                      else
                        // Groups flow at their natural height so the ungrouped
                        // box below can `Expanded`-fill the rest of the column —
                        // a flex group area would split the height 50/50 and
                        // halve the ungrouped box.
                        ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (final g in groups)
                              SidebarListFrame(
                                children: [
                                  SidebarGroupHeader(
                                    group: g,
                                    count: g.items
                                        .where(byId.containsKey)
                                        .length,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                  ),
                                  if (g.expanded)
                                    for (final id in g.items)
                                      if (byId[id] != null) item(byId[id]!),
                                ],
                              ),
                          ],
                        ),
                      SidebarSectionLabel(text: '未分组话题', color: textSecondary),
                      if (ungrouped.isEmpty)
                        SidebarEmptyHint(text: '暂无未分组话题', color: textSecondary)
                      else
                        Expanded(
                          child: SidebarListFrame(
                            scrollable: true,
                            children: [for (final t in ungrouped) item(t)],
                          ),
                        ),
                      SidebarCountFooter(
                        text: '共 ${topics.length} 个话题',
                        color: textSecondary,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

enum _TopicMenu { addToGroup, rename, togglePin, clearMessages, move, delete }

class _TopicItem extends ConsumerWidget {
  const _TopicItem({
    required this.topic,
    required this.selected,
    required this.canMove,
    required this.onSelect,
  });

  final Topic topic;
  final bool selected;
  final bool canMove;
  final VoidCallback onSelect;

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    _TopicMenu value,
  ) async {
    final notifier = ref.read(topicsProvider.notifier);
    switch (value) {
      case _TopicMenu.addToGroup:
        final assistantId = topic.assistantId;
        await showAddToGroupDialog(
          context,
          ref,
          type: GroupType.topic,
          assistantId: assistantId,
          itemId: topic.id,
        );
      case _TopicMenu.rename:
        final name = await promptText(
          context,
          title: '编辑话题',
          hint: '话题名称',
          initial: topic.name,
        );
        if (name != null) await notifier.rename(topic.id, name);
      case _TopicMenu.togglePin:
        await notifier.togglePin(topic.id);
      case _TopicMenu.clearMessages:
        final ok = await showConfirmDialog(
          context,
          title: '清空消息',
          message: '确定要清空此话题的所有消息吗？此操作不可撤销。',
        );
        if (ok) await notifier.clearMessages(topic.id);
      case _TopicMenu.move:
        await showMoveTopicDialog(context, ref, topic: topic);
      case _TopicMenu.delete:
        await _deleteTopic(context, ref);
    }
  }

  Future<void> _deleteTopic(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除话题',
      message: '确定要删除此话题吗？此操作不可撤销。',
    );
    if (ok) await ref.read(topicsProvider.notifier).delete(topic.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? kSidebarSelectedItemBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (topic.pinned) ...[
                            const Icon(
                              LucideIcons.pin,
                              size: 12,
                              color: kSidebarMutedIcon,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              topic.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.43,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        topic.lastMessagePreview ?? '无消息',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.66,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTopicTime(topic),
                      style: TextStyle(
                        fontSize: 11,
                        height: 1,
                        color: textPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SidebarOverflowMenuButton<_TopicMenu>(
                          size: 16,
                          box: 20,
                          title: topic.name,
                          actions: [
                            const SidebarSheetAction(
                              _TopicMenu.addToGroup,
                              LucideIcons.folderPlus,
                              '添加到分组',
                            ),
                            const SidebarSheetAction(
                              _TopicMenu.rename,
                              LucideIcons.edit3,
                              '编辑话题',
                            ),
                            SidebarSheetAction(
                              _TopicMenu.togglePin,
                              topic.pinned
                                  ? LucideIcons.pinOff
                                  : LucideIcons.pin,
                              topic.pinned ? '取消固定' : '固定话题',
                            ),
                            const SidebarSheetAction(
                              _TopicMenu.clearMessages,
                              LucideIcons.trash2,
                              '清空消息',
                            ),
                            if (canMove)
                              const SidebarSheetAction(
                                _TopicMenu.move,
                                LucideIcons.arrowRight,
                                '移动到...',
                              ),
                            const SidebarSheetAction(
                              _TopicMenu.delete,
                              LucideIcons.trash,
                              '删除话题',
                              danger: true,
                            ),
                          ],
                          onSelected: (m) => _onMenu(context, ref, m),
                        ),
                        const SizedBox(width: 2),
                        SidebarConfirmDeleteButton(
                          size: 16,
                          box: 20,
                          color: textPrimary,
                          // The two-click red state IS the confirmation (1:1
                          // with the web `pendingDelete` flow), so delete
                          // directly here instead of popping a dialog.
                          onConfirm: () => unawaited(
                            ref.read(topicsProvider.notifier).delete(topic.id),
                          ),
                        ),
                      ],
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

/// A bordered icon-only button (创建话题分组): radius 6, 1px border, 16px icon.
class _BorderedIconButton extends StatelessWidget {
  const _BorderedIconButton({
    required this.icon,
    required this.borderColor,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color borderColor;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

/// `MM/DD HH:mm` from `lastMessageTime` (ISO) falling back to `updatedAt`.
String _formatTopicTime(Topic t) {
  final raw = t.lastMessageTime;
  final dt = (raw != null ? DateTime.tryParse(raw) : null) ?? t.updatedAt;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}
