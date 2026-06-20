// 助 (assistant) tab: list, grouping, per-item actions.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/edit_assistant_dialog.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/dialogs/sidebar_dialogs.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/sidebar_tokens.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/sidebar_avatar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/sidebar_buttons.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/sidebar_lists.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/sidebar_menus.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';

/// Unselected assistant avatar background, MUI `grey.300` `#e0e0e0`.
const Color _avatarUnselectedBg = Color(0xFFE0E0E0);

class AssistantTab extends ConsumerStatefulWidget {
  const AssistantTab({super.key, required this.onGoToTopics});

  /// Switches the sidebar to the 话题 tab after selecting an assistant.
  final VoidCallback onGoToTopics;

  @override
  ConsumerState<AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends ConsumerState<AssistantTab> {
  final TextEditingController _searchController = TextEditingController();
  bool _searchOpen = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectAssistant(String id) async {
    Haptics.instance.onListItem();
    ref.read(currentAssistantIdProvider.notifier).set(id);
    widget.onGoToTopics();
    await ref.read(topicsProvider.notifier).selectFirstOrCreate(id);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;

    final all =
        ref.watch(assistantsProvider).asData?.value ?? const <Assistant>[];
    final current = ref.watch(currentAssistantProvider);
    final counts = ref.watch(topicCountByAssistantProvider);
    final groups = ref.watch(assistantGroupsProvider);
    final ungrouped = ref.watch(ungroupedAssistantsProvider);
    final byId = <String, Assistant>{for (final a in all) a.id: a};

    final query = _query.trim().toLowerCase();
    final searching = query.isNotEmpty;
    final filtered = searching
        ? all
              .where(
                (a) =>
                    a.name.toLowerCase().contains(query) ||
                    (a.systemPrompt ?? '').toLowerCase().contains(query),
              )
              .toList()
        : const <Assistant>[];

    Widget item(Assistant a) => _AssistantItem(
      assistant: a,
      selected: current?.id == a.id,
      topicCount: counts[a.id] ?? 0,
      onSelect: () => _selectAssistant(a.id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: SidebarTabHeader(
            title: '所有助手',
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
              SidebarPillButton(
                icon: LucideIcons.folderPlus,
                label: '创建分组',
                onPressed: () => showCreateGroupDialog(
                  context,
                  ref,
                  type: GroupType.assistant,
                ),
              ),
              const SizedBox(width: 4),
              SidebarPillButton(
                icon: LucideIcons.plus,
                label: '添加助手',
                onPressed: () => showAddAssistantDialog(context, ref),
              ),
            ],
          ),
        ),
        if (_searchOpen)
          SidebarSearchField(
            controller: _searchController,
            hint: '搜索助手...',
            onChanged: (v) => setState(() => _query = v),
          ),
        Expanded(
          child: searching
              ? ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    if (filtered.isEmpty)
                      SidebarEmptyHint(text: '没有找到助手', color: textSecondary)
                    else
                      for (final a in filtered) item(a),
                  ],
                )
              // The tab is a non-scrolling column; only the ungrouped list box
              // scrolls internally (Expanded + internal scroll) and the "共 N 个"
              // count is glued directly below it — 1:1 with the web
              // `VirtualizedAssistantList`, where the count sits right under the
              // box (`mt:1`) inside a container that does not scroll as a whole.
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (groups.isEmpty)
                        SidebarEmptyHint(text: '没有助手分组', color: textSecondary)
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
                      SidebarSectionLabel(text: '未分组助手', color: textSecondary),
                      if (ungrouped.isEmpty)
                        SidebarEmptyHint(text: '暂无未分组助手', color: textSecondary)
                      else
                        Expanded(
                          child: SidebarListFrame(
                            scrollable: true,
                            children: [for (final a in ungrouped) item(a)],
                          ),
                        ),
                      SidebarCountFooter(
                        text: '共 ${all.length} 个助手',
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

enum _AssistantMenu {
  edit,
  addToGroup,
  copy,
  clearTopics,
  sortAsc,
  sortDesc,
  delete,
}

class _AssistantItem extends ConsumerWidget {
  const _AssistantItem({
    required this.assistant,
    required this.selected,
    required this.topicCount,
    required this.onSelect,
  });

  final Assistant assistant;
  final bool selected;
  final int topicCount;
  final VoidCallback onSelect;

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    _AssistantMenu value,
  ) async {
    final notifier = ref.read(assistantsProvider.notifier);
    switch (value) {
      case _AssistantMenu.edit:
        await showEditAssistantDialog(context, assistant);
      case _AssistantMenu.addToGroup:
        await showAddToGroupDialog(
          context,
          ref,
          type: GroupType.assistant,
          itemId: assistant.id,
        );
      case _AssistantMenu.copy:
        await notifier.copy(assistant);
      case _AssistantMenu.clearTopics:
        final ok = await showConfirmDialog(
          context,
          title: '清空话题',
          message: '确定要清空「${assistant.name}」的所有话题吗？此操作不可撤销。',
        );
        if (ok) await notifier.clearTopics(assistant.id);
      case _AssistantMenu.sortAsc:
        ref
            .read(assistantSortOrderControllerProvider.notifier)
            .set(AssistantSortOrder.asc);
      case _AssistantMenu.sortDesc:
        ref
            .read(assistantSortOrderControllerProvider.notifier)
            .set(AssistantSortOrder.desc);
      case _AssistantMenu.delete:
        await _deleteAssistant(context, ref);
    }
  }

  Future<void> _deleteAssistant(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: '删除助手',
      message: '确定要删除助手「${assistant.name}」吗？其所有话题也会被删除，此操作不可撤销。',
    );
    if (ok) await ref.read(assistantsProvider.notifier).delete(assistant.id);
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
              children: [
                // ListItemAvatar: min-width 56, 32px avatar (radius 25%).
                SizedBox(
                  width: 56,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SidebarAvatar(
                      text: assistantAvatarText(assistant),
                      background: selected
                          ? theme.colorScheme.primary
                          : _avatarUnselectedBg,
                      size: 32,
                      fontSize: 19.2,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        assistant.name,
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
                      Text(
                        '$topicCount 个话题',
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
                SidebarOverflowMenuButton<_AssistantMenu>(
                  size: 16,
                  box: 26,
                  title: assistant.name,
                  actions: const [
                    SidebarSheetAction(
                      _AssistantMenu.edit,
                      LucideIcons.squarePen,
                      '编辑助手',
                    ),
                    SidebarSheetAction(
                      _AssistantMenu.addToGroup,
                      LucideIcons.folderPlus,
                      '添加到分组',
                    ),
                    SidebarSheetAction(
                      _AssistantMenu.copy,
                      LucideIcons.copy,
                      '复制助手',
                    ),
                    SidebarSheetAction(
                      _AssistantMenu.clearTopics,
                      LucideIcons.trash2,
                      '清空话题',
                    ),
                    SidebarSheetAction(
                      _AssistantMenu.sortAsc,
                      LucideIcons.arrowUpAZ,
                      '按拼音升序排列',
                    ),
                    SidebarSheetAction(
                      _AssistantMenu.sortDesc,
                      LucideIcons.arrowDownAZ,
                      '按拼音降序排列',
                    ),
                    SidebarSheetAction(
                      _AssistantMenu.delete,
                      LucideIcons.trash,
                      '删除助手',
                      danger: true,
                    ),
                  ],
                  onSelected: (m) => _onMenu(context, ref, m),
                ),
                SidebarConfirmDeleteButton(
                  size: 16,
                  box: 26,
                  color: textPrimary,
                  // Two-click red state IS the confirmation (same as the topic
                  // delete), so delete directly instead of popping a dialog.
                  onConfirm: () => unawaited(
                    ref.read(assistantsProvider.notifier).delete(assistant.id),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
