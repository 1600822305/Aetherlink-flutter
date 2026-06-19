/// Pixel-1:1 port of the original web chat-interface sidebar
/// (`src/components/TopicManagement/`): the 助手 / 话题 / 设置 tab shell plus the
/// per-tab content and the bottom 翻译 button.
///
/// The 助手 / 话题 tabs are wired to the real, Drift-backed application layer
/// ([assistantsProvider] / [topicsProvider] / [groupsProvider] +
/// [currentAssistantProvider] / [currentTopicIdProvider]); the 设置 tab is still
/// appearance-only. Icons are migrated to their lucide counterparts
/// (ADR-0009); every literal color/size below is the value measured from the
/// live web DOM (`getComputedStyle`, light theme).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/mcp_servers_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/chat/application/assistant_presets.dart';
import 'package:aetherlink_flutter/features/chat/application/mcp_tools_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';

// ── Static strings, ported verbatim ────────────────────────────────────────
const String _assistantTabLabel = '助手';
const String _topicTabLabel = '话题';
const String _settingsTabLabel = '设置';

// ── Literal colors measured from the original (annotated with source rgba) ──
/// `Mui-selected` list-item background: `rgba(25, 118, 210, 0.08)`.
const Color _selectedItemBg = Color(0x141976D2);

/// MUI light `action.active` — the default icon-button tint `rgba(0,0,0,0.54)`.
const Color _mutedIconColor = Color(0x8A000000);

/// 设置 entry leading gear, `#1976d2`.
const Color _cogBlue = Color(0xFF1976D2);

/// Destructive (删除) menu/text tint, MUI `error.main` `#d32f2f`.
const Color _dangerColor = Color(0xFFD32F2F);

/// 侧边栏宽度 toggle button background, `rgba(0,0,0,0.04)`.
const Color _panelButtonBg = Color(0x0A000000);

/// 用户头像 row tint `rgba(255,193,7,0.10)` + its `#ffc107` left accent.
const Color _userRowBg = Color(0x1AFFC107);
const Color _userRowAccent = Color(0xFFFFC107);

/// 用户头像 avatar background, `#87d068`.
const Color _userAvatarBg = Color(0xFF87D068);

/// Unselected assistant avatar background, MUI `grey.300` `#e0e0e0`.
const Color _avatarUnselectedBg = Color(0xFFE0E0E0);

/// 兼容 API chip outline, MUI `grey.400` `#bdbdbd`.
const Color _chipBorderColor = Color(0xFFBDBDBD);

class ChatSidebar extends ConsumerStatefulWidget {
  const ChatSidebar({super.key});

  @override
  ConsumerState<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends ConsumerState<ChatSidebar>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Open on the session's last tab (in-memory [SidebarTabIndex]); it is not
    // persisted, so a fresh app launch starts on the default 助手 tab.
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: ref.read(sidebarTabIndexProvider),
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    // Remember the active tab for this session so reopening the drawer keeps it
    // (in-memory only — a restart resets to the default tab).
    final index = _tabController.index;
    if (ref.read(sidebarTabIndexProvider) != index) {
      ref.read(sidebarTabIndexProvider.notifier).set(index);
    }
    // The 翻译 button only renders on the 助手/话题 tabs, so rebuild on switch.
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showTranslate = _tabController.index != 2;
    // 设置 tab 的「侧边栏宽度」对话框驱动这里；按当前屏宽 clamp 到安全范围
    // (`getSafeMaxSidebarWidth`)，对话框拖动时实时预览。
    final rawWidth = ref.watch(
      sidebarSettingsControllerProvider.select((s) => s.sidebarWidth),
    );
    final maxWidth = safeMaxSidebarWidth(MediaQuery.sizeOf(context).width);
    final drawerWidth = rawWidth.clamp(kSidebarWidthMin, maxWidth);

    return Drawer(
      width: drawerWidth,
      backgroundColor: theme.colorScheme.surface,
      // Original mobile drawer: `border-radius: 0 16px 16px 0`.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const _CloseRow(),
            _SidebarTabBar(controller: _tabController),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                // 禁止左右滑动切换 tab，只能点 tab 切换。
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _AssistantTab(
                    onGoToTopics: () => _tabController.animateTo(1),
                  ),
                  const _TopicTab(),
                  const _SettingsTab(),
                ],
              ),
            ),
            if (showTranslate) const _TranslateButton(),
          ],
        ),
      ),
    );
  }
}

// ── Top close row ───────────────────────────────────────────────────────────
/// The drawer's top close affordance: `justify-content: flex-end; padding: 8px;
/// min-height: 48px` with a lucide `X` (size 20) button.
class _CloseRow extends StatelessWidget {
  const _CloseRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      alignment: Alignment.centerRight,
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.all(8),
      child: IconButton(
        onPressed: () => Scaffold.maybeOf(context)?.closeDrawer(),
        iconSize: 20,
        color: theme.colorScheme.onSurface,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        icon: const Icon(LucideIcons.x),
      ),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────
class _SidebarTabBar extends StatelessWidget {
  const _SidebarTabBar({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;

    return Container(
      // Tabs container: `border-bottom: 1px solid divider`, `margin: 0 10px`,
      // `padding: 10px 0`.
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        labelColor: textPrimary,
        unselectedLabelColor: textPrimary.withValues(alpha: 0.6),
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.25,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.25,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        // Indicator: full tab width, height 2px, solid onSurface (#1E293B).
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(width: 2, color: textPrimary),
        ),
        tabs: const [
          _SidebarTab(icon: LucideIcons.bot, label: _assistantTabLabel),
          _SidebarTab(icon: LucideIcons.messageSquare, label: _topicTabLabel),
          _SidebarTab(icon: LucideIcons.settings, label: _settingsTabLabel),
        ],
      ),
    );
  }
}

class _SidebarTab extends StatelessWidget {
  const _SidebarTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Tab box 58px tall; icon 18px with a 2px gap above the label.
    return Tab(
      height: 58,
      iconMargin: const EdgeInsets.only(bottom: 2),
      icon: Icon(icon, size: 18),
      text: label,
    );
  }
}

// ── 助手 tab ─────────────────────────────────────────────────────────────────
class _AssistantTab extends ConsumerStatefulWidget {
  const _AssistantTab({required this.onGoToTopics});

  /// Switches the sidebar to the 话题 tab after selecting an assistant.
  final VoidCallback onGoToTopics;

  @override
  ConsumerState<_AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends ConsumerState<_AssistantTab> {
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
          child: _TabHeader(
            title: '所有助手',
            trailing: [
              _MutedIconButton(
                icon: LucideIcons.search,
                size: 18,
                box: 28,
                color: _searchOpen
                    ? theme.colorScheme.primary
                    : _mutedIconColor,
                onPressed: _toggleSearch,
              ),
              const SizedBox(width: 8),
              _OutlinedPillButton(
                icon: LucideIcons.folderPlus,
                label: '创建分组',
                onPressed: () => _showCreateGroupDialog(
                  context,
                  ref,
                  type: GroupType.assistant,
                ),
              ),
              const SizedBox(width: 4),
              _OutlinedPillButton(
                icon: LucideIcons.plus,
                label: '添加助手',
                onPressed: () => _showAddAssistantDialog(context, ref),
              ),
            ],
          ),
        ),
        if (_searchOpen)
          _SearchField(
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
                      _EmptyHint(text: '没有找到助手', color: textSecondary)
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
                        _EmptyHint(text: '没有助手分组', color: textSecondary)
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
                              _ListFrame(
                                children: [
                                  _GroupHeader(
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
                      _SectionLabel(text: '未分组助手', color: textSecondary),
                      if (ungrouped.isEmpty)
                        _EmptyHint(text: '暂无未分组助手', color: textSecondary)
                      else
                        Expanded(
                          child: _ListFrame(
                            scrollable: true,
                            children: [for (final a in ungrouped) item(a)],
                          ),
                        ),
                      _CountFooter(
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

enum _AssistantMenu { addToGroup, copy, clearTopics, sortAsc, sortDesc, delete }

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
      case _AssistantMenu.addToGroup:
        await _showAddToGroupDialog(
          context,
          ref,
          type: GroupType.assistant,
          itemId: assistant.id,
        );
      case _AssistantMenu.copy:
        await notifier.copy(assistant);
      case _AssistantMenu.clearTopics:
        final ok = await _confirm(
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
    final ok = await _confirm(
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
        color: selected ? _selectedItemBg : Colors.transparent,
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
                    child: _Avatar(
                      text: _assistantAvatarText(assistant),
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
                _OverflowMenuButton<_AssistantMenu>(
                  size: 16,
                  box: 26,
                  title: assistant.name,
                  actions: const [
                    _SheetAction(
                      _AssistantMenu.addToGroup,
                      LucideIcons.folderPlus,
                      '添加到分组',
                    ),
                    _SheetAction(_AssistantMenu.copy, LucideIcons.copy, '复制助手'),
                    _SheetAction(
                      _AssistantMenu.clearTopics,
                      LucideIcons.trash2,
                      '清空话题',
                    ),
                    _SheetAction(
                      _AssistantMenu.sortAsc,
                      LucideIcons.arrowUpAZ,
                      '按拼音升序排列',
                    ),
                    _SheetAction(
                      _AssistantMenu.sortDesc,
                      LucideIcons.arrowDownAZ,
                      '按拼音降序排列',
                    ),
                    _SheetAction(
                      _AssistantMenu.delete,
                      LucideIcons.trash,
                      '删除助手',
                      danger: true,
                    ),
                  ],
                  onSelected: (m) => _onMenu(context, ref, m),
                ),
                _ConfirmDeleteButton(
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

// ── 话题 tab ─────────────────────────────────────────────────────────────────
class _TopicTab extends ConsumerStatefulWidget {
  const _TopicTab();

  @override
  ConsumerState<_TopicTab> createState() => _TopicTabState();
}

class _TopicTabState extends ConsumerState<_TopicTab> {
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
          child: _TabHeader(
            title: current?.name ?? '所有话题',
            trailing: [
              _MutedIconButton(
                icon: LucideIcons.search,
                size: 18,
                box: 28,
                color: _searchOpen
                    ? theme.colorScheme.primary
                    : _mutedIconColor,
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
                    : () => _showCreateGroupDialog(
                        context,
                        ref,
                        type: GroupType.topic,
                        assistantId: current.id,
                      ),
              ),
              const SizedBox(width: 4),
              _OutlinedPillButton(
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
          _SearchField(
            controller: _searchController,
            hint: '搜索话题...',
            onChanged: (v) => setState(() => _query = v),
          ),
        Expanded(
          child: current == null
              ? _EmptyHint(text: '请先在「助手」标签选择一个助手', color: textSecondary)
              : searching
              ? ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    if (filtered.isEmpty)
                      _EmptyHint(text: '没有找到话题', color: textSecondary)
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
                        _EmptyHint(text: '没有话题分组', color: textSecondary)
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
                              _ListFrame(
                                children: [
                                  _GroupHeader(
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
                      _SectionLabel(text: '未分组话题', color: textSecondary),
                      if (ungrouped.isEmpty)
                        _EmptyHint(text: '暂无未分组话题', color: textSecondary)
                      else
                        Expanded(
                          child: _ListFrame(
                            scrollable: true,
                            children: [for (final t in ungrouped) item(t)],
                          ),
                        ),
                      _CountFooter(
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
        await _showAddToGroupDialog(
          context,
          ref,
          type: GroupType.topic,
          assistantId: assistantId,
          itemId: topic.id,
        );
      case _TopicMenu.rename:
        final name = await _promptText(
          context,
          title: '编辑话题',
          hint: '话题名称',
          initial: topic.name,
        );
        if (name != null) await notifier.rename(topic.id, name);
      case _TopicMenu.togglePin:
        await notifier.togglePin(topic.id);
      case _TopicMenu.clearMessages:
        final ok = await _confirm(
          context,
          title: '清空消息',
          message: '确定要清空此话题的所有消息吗？此操作不可撤销。',
        );
        if (ok) await notifier.clearMessages(topic.id);
      case _TopicMenu.move:
        await _showMoveTopicDialog(context, ref, topic: topic);
      case _TopicMenu.delete:
        await _deleteTopic(context, ref);
    }
  }

  Future<void> _deleteTopic(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
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
        color: selected ? _selectedItemBg : Colors.transparent,
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
                              color: _mutedIconColor,
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
                        _OverflowMenuButton<_TopicMenu>(
                          size: 16,
                          box: 20,
                          title: topic.name,
                          actions: [
                            const _SheetAction(
                              _TopicMenu.addToGroup,
                              LucideIcons.folderPlus,
                              '添加到分组',
                            ),
                            const _SheetAction(
                              _TopicMenu.rename,
                              LucideIcons.edit3,
                              '编辑话题',
                            ),
                            _SheetAction(
                              _TopicMenu.togglePin,
                              topic.pinned
                                  ? LucideIcons.pinOff
                                  : LucideIcons.pin,
                              topic.pinned ? '取消固定' : '固定话题',
                            ),
                            const _SheetAction(
                              _TopicMenu.clearMessages,
                              LucideIcons.trash2,
                              '清空消息',
                            ),
                            if (canMove)
                              const _SheetAction(
                                _TopicMenu.move,
                                LucideIcons.arrowRight,
                                '移动到...',
                              ),
                            const _SheetAction(
                              _TopicMenu.delete,
                              LucideIcons.trash,
                              '删除话题',
                              danger: true,
                            ),
                          ],
                          onSelected: (m) => _onMenu(context, ref, m),
                        ),
                        const SizedBox(width: 2),
                        _ConfirmDeleteButton(
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

// ── 设置 tab ─────────────────────────────────────────────────────────────────
class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sidebarSettingsControllerProvider);
    final c = ref.read(sidebarSettingsControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      children: [
        const _SettingsEntryRow(),
        const _SettingsDivider(),
        const _UserAvatarRow(),
        const _SettingsDivider(),
        // 常规设置 (7 项) — fully migrated. 消息分割线 / 代码块可复制 drive the chat
        // view now; the rest persist and light up as their chat widgets land.
        _SettingsGroup(
          title: '常规设置',
          subtitle: '7 个基础功能设置',
          children: [
            _SwitchSettingRow(
              title: '消息分割线',
              description: '在消息之间显示分割线',
              value: s.showMessageDivider,
              onChanged: c.setShowMessageDivider,
            ),
            _SwitchSettingRow(
              title: '代码块可复制',
              description: '允许复制代码块的内容',
              value: s.copyableCodeBlocks,
              onChanged: c.setCopyableCodeBlocks,
            ),
            _SwitchSettingRow(
              title: '渲染用户输入',
              description: '渲染用户输入的 Markdown 格式（关闭后用户消息显示为纯文本）',
              value: s.renderUserInputAsMarkdown,
              onChanged: c.setRenderUserInputAsMarkdown,
              comingSoon: true,
            ),
            _SwitchSettingRow(
              title: '自动下滑',
              description: '新消息时自动滚动到聊天底部',
              value: s.autoScrollToBottom,
              onChanged: c.setAutoScrollToBottom,
            ),
            _SelectSettingRow<MessageStyle>(
              title: '消息样式',
              description: '选择聊天消息的显示样式',
              value: s.messageStyle,
              options: [for (final v in MessageStyle.values) (v, v.label)],
              onChanged: c.setMessageStyle,
              comingSoon: true,
            ),
            _SelectSettingRow<MessageNavigation>(
              title: '对话导航',
              description: '显示上下按钮快速跳转到上一条/下一条消息',
              value: s.messageNavigation,
              options: [for (final v in MessageNavigation.values) (v, v.label)],
              onChanged: c.setMessageNavigation,
              comingSoon: true,
            ),
            _SwitchSettingRow(
              title: 'Token 用量指示',
              description: '在右侧显示上下文 Token 用量呼吸灯',
              value: s.showContextTokenIndicator,
              onChanged: c.setShowContextTokenIndicator,
              comingSoon: true,
            ),
          ],
        ),
        const _SettingsDivider(),
        // 上下文设置 — UI + persist; consumed by the request layer later.
        _SettingsGroup(
          title: '上下文设置',
          subtitle:
              '窗口: ${_formatInt(s.contextWindowSize)} | 输出: ${s.maxOutputTokens}',
          chipLabel: '兼容 API',
          comingSoon: true,
          children: [
            const _ComingSoonNote(text: '设置会先保存，接入请求层后生效。'),
            _NumberSettingRow(
              title: '上下文窗口大小',
              description: '单位 token',
              value: s.contextWindowSize,
              min: 1000,
              max: 2000000,
              onChanged: c.setContextWindowSize,
            ),
            _SliderSettingRow(
              title: '上下文消息数量',
              description: '携带的历史消息条数',
              value: s.contextCount.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              valueLabel: '${s.contextCount}',
              onChanged: (v) => c.setContextCount(v.round()),
            ),
            _SwitchSettingRow(
              title: '启用最大输出限制',
              description: '限制单次回复的最大 token 数',
              value: s.enableMaxOutputTokens,
              onChanged: c.setEnableMaxOutputTokens,
            ),
            if (s.enableMaxOutputTokens)
              _NumberSettingRow(
                title: '最大输出 Token',
                description: '单次回复的 token 上限',
                value: s.maxOutputTokens,
                min: 256,
                max: 200000,
                onChanged: c.setMaxOutputTokens,
              ),
          ],
        ),
        const _SettingsDivider(),
        // 输入设置 — UI + persist.
        _SettingsGroup(
          title: '输入设置',
          subtitle: '粘贴和输入相关的功能设置',
          comingSoon: true,
          children: [
            const _ComingSoonNote(text: '设置会先保存，接入输入框后生效。'),
            _SwitchSettingRow(
              title: '长文本粘贴为文件',
              description: '粘贴超长文本时自动转为文件附件',
              value: s.pasteLongTextAsFile,
              onChanged: c.setPasteLongTextAsFile,
            ),
            if (s.pasteLongTextAsFile)
              _NumberSettingRow(
                title: '触发阈值',
                description: '超过该字符数转为文件',
                value: s.pasteLongTextThreshold,
                min: 100,
                max: 10000,
                onChanged: c.setPasteLongTextThreshold,
              ),
          ],
        ),
        const _SettingsDivider(),
        // 代码块设置 — UI + persist; consumed by 代码块视图 later.
        _SettingsGroup(
          title: '代码块设置',
          subtitle: '配置代码显示和编辑功能',
          comingSoon: true,
          children: [
            const _ComingSoonNote(text: '设置会先保存，接入代码块视图后生效。'),
            _SwitchSettingRow(
              title: '显示行号',
              description: '在代码块左侧显示行号',
              value: s.codeShowLineNumbers,
              onChanged: c.setCodeShowLineNumbers,
            ),
            _SwitchSettingRow(
              title: '可折叠',
              description: '允许折叠/展开代码块',
              value: s.codeCollapsible,
              onChanged: c.setCodeCollapsible,
            ),
            _SwitchSettingRow(
              title: '自动换行',
              description: '过长的代码行自动换行',
              value: s.codeWrappable,
              onChanged: c.setCodeWrappable,
            ),
            _SwitchSettingRow(
              title: '默认折叠',
              description: '代码块默认以折叠状态显示',
              value: s.codeDefaultCollapsed,
              onChanged: c.setCodeDefaultCollapsed,
            ),
            _SwitchSettingRow(
              title: 'Mermaid 图表',
              description: '渲染 Mermaid 流程图 / 时序图',
              value: s.mermaidEnabled,
              onChanged: c.setMermaidEnabled,
            ),
            // 高亮主题：Flutter 暂无 Shiki 同款高亮器，主题列表无法复刻；先展示占位。
            const _StaticSettingRow(
              title: '代码高亮主题',
              value: '自动（跟随应用主题）',
              comingSoon: true,
            ),
          ],
        ),
        const _SettingsDivider(),
        // 数学公式设置 — 引擎下拉删除（Flutter 用 flutter_math 原生渲染）。
        _SettingsGroup(
          title: '数学公式设置',
          subtitle: '渲染引擎: KaTeX',
          comingSoon: true,
          children: [
            const _ComingSoonNote(text: '设置会先保存，接入渲染后生效。'),
            const _StaticSettingRow(
              title: '渲染引擎',
              value: 'KaTeX（flutter_math，原生渲染）',
            ),
            _SwitchSettingRow(
              title: '单美元符号',
              description: r'识别 $...$ 作为行内公式',
              value: s.mathEnableSingleDollar,
              onChanged: c.setMathEnableSingleDollar,
            ),
          ],
        ),
        const _SettingsDivider(),
        // MCP 工具 — 总开关 / 调用模式 / 内联服务器列表，均已接入对话（工具调用）。
        const _McpToolsGroup(),
      ],
    );
  }
}

/// The 设置 tab's MCP 工具 group (port of `MCPSidebarControls`): the 启用 MCP 工具
/// 总开关, the 工具调用模式 (函数调用 / 提示词注入), an inline list of configured
/// servers — each with its own active switch — and a 管理服务器 row into the MCP
/// 服务器 settings page. All of these are live: the toggle / mode feed
/// `ChatController._mcpSetup`, which exposes the active servers' tools to the
/// model and runs the tool-call loop (Phase C/D).
class _McpToolsGroup extends ConsumerWidget {
  const _McpToolsGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tools = ref.watch(mcpToolsControllerProvider);
    final controller = ref.read(mcpToolsControllerProvider.notifier);
    final servers =
        ref.watch(mcpServersProvider).asData?.value ?? const <McpServer>[];
    final activeCount = servers.where((s) => s.isActive).length;
    final modeLabel = tools.mode.label;

    return _SettingsGroup(
      title: 'MCP 工具',
      subtitle: activeCount > 0
          ? '$activeCount 个服务器运行中 | 模式: $modeLabel'
          : '模式: $modeLabel',
      children: [
        _SwitchSettingRow(
          title: '启用 MCP 工具',
          description: '在对话中向模型提供已激活服务器的工具',
          value: tools.enabled,
          onChanged: (v) => controller.setEnabled(enabled: v),
        ),
        _SelectSettingRow<McpMode>(
          title: '工具调用模式',
          description: '函数调用：模型自动调用工具（推荐）；提示词注入：通过提示词指导 AI 使用工具',
          value: tools.mode,
          options: [for (final m in McpMode.values) (m, m.label)],
          onChanged: controller.setMode,
        ),
        if (servers.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 6, 16, 6),
            child: Text(
              '还没有配置 MCP 服务器',
              style: TextStyle(fontSize: 12, color: _mutedIconColor),
            ),
          )
        else
          for (final server in servers)
            _McpServerRow(server: server, toolsEnabled: tools.enabled),
        _SettingItemShell(
          title: '管理服务器',
          description: '添加、导入与配置 MCP 服务器',
          onTap: () => context.push(AppRouter.mcpServerPath),
          trailing: const Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: _mutedIconColor,
          ),
        ),
      ],
    );
  }
}

/// A single configured-server row inside [_McpToolsGroup]: a type-tinted glyph,
/// the server name + short transport label, and an active switch that flips the
/// server's `isActive` via [McpServers.toggleActive] (disabled until 启用 MCP
/// 工具 is on). Tapping the row opens the server's 详情 page. Mirrors the inline
/// server list of the web `MCPSidebarControls`.
class _McpServerRow extends ConsumerWidget {
  const _McpServerRow({required this.server, required this.toolsEnabled});

  final McpServer server;
  final bool toolsEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = _mcpTypeColor(server.type);
    return InkWell(
      onTap: () => context.push('${AppRouter.mcpServerPath}/${server.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 16, 6),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_mcpTypeIcon(server.type), size: 15, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    server.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.3,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    _mcpTypeShortLabel(server.type),
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.3,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: server.isActive,
              onChanged: toolsEnabled
                  ? (v) => ref
                        .read(mcpServersProvider.notifier)
                        .toggleActive(server.id, isActive: v)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

IconData _mcpTypeIcon(McpServerType type) => switch (type) {
  McpServerType.sse ||
  McpServerType.streamableHttp ||
  McpServerType.httpStream => LucideIcons.globe,
  McpServerType.stdio => LucideIcons.terminal,
  McpServerType.inMemory => LucideIcons.database,
};

Color _mcpTypeColor(McpServerType type) => switch (type) {
  McpServerType.sse => const Color(0xFF2196F3),
  McpServerType.streamableHttp => const Color(0xFF00BCD4),
  McpServerType.httpStream => const Color(0xFF9C27B0),
  McpServerType.stdio => const Color(0xFFFF9800),
  McpServerType.inMemory => const Color(0xFF4CAF50),
};

String _mcpTypeShortLabel(McpServerType type) => switch (type) {
  McpServerType.sse => 'SSE',
  McpServerType.streamableHttp => 'Streamable HTTP',
  McpServerType.httpStream => 'HTTP Stream',
  McpServerType.stdio => 'stdio',
  McpServerType.inMemory => '内存',
};

/// Formats an int with thousands separators, e.g. `100000` → `100,000`.
String _formatInt(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Shows a transient 即将支持 toast for affordances whose subsystem is not yet
/// ported (e.g. 头像上传).
void _showComingSoon(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$what即将支持'),
        duration: const Duration(seconds: 2),
      ),
    );
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    // `Divider my: 0.5` → 4px above/below a 1px line.
    return const Divider(height: 9, thickness: 1);
  }
}

class _SettingsEntryRow extends ConsumerWidget {
  const _SettingsEntryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.push(AppRouter.settingsPath),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  const Icon(LucideIcons.cog, size: 20, color: _cogBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '设置',
                          style: TextStyle(
                            fontSize: 15.2,
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          '进入完整设置页面',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: theme.dividerColor,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          // 侧边栏宽度 toggle → 打开宽度对话框。
          Material(
            color: _panelButtonBg,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => _showSidebarWidthDialog(context, ref),
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  LucideIcons.panelLeft,
                  size: 18,
                  color: _mutedIconColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserAvatarRow extends StatelessWidget {
  const _UserAvatarRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    return Container(
      decoration: const BoxDecoration(
        color: _userRowBg,
        border: Border(left: BorderSide(color: _userRowAccent, width: 3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const _Avatar(
            text: '我',
            background: _userAvatarBg,
            size: 36,
            fontSize: 22.86,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '用户头像',
                  style: TextStyle(
                    fontSize: 14.4,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                Text(
                  '设置您的个人头像',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 头像上传 / 裁剪子系统未移植。
          _MutedIconButton(
            icon: LucideIcons.user,
            size: 16,
            box: 28,
            onPressed: () => _showComingSoon(context, '头像上传'),
          ),
        ],
      ),
    );
  }
}

// ── 设置 tab 控件 ─────────────────────────────────────────────────────────────
/// A collapsible 设置 group: a tappable header (title + subtitle + optional chip
/// / 即将支持 badge + rotating chevron) over an expandable body. Mirrors the web
/// `SettingGroup` accordion; collapsed by default.
class _SettingsGroup extends StatefulWidget {
  const _SettingsGroup({
    required this.title,
    required this.subtitle,
    required this.children,
    this.chipLabel,
    this.comingSoon = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final String? chipLabel;
  final bool comingSoon;

  @override
  State<_SettingsGroup> createState() => _SettingsGroupState();
}

class _SettingsGroupState extends State<_SettingsGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.2,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          if (widget.chipLabel != null) ...[
                            const SizedBox(width: 6),
                            _Chip(label: widget.chipLabel!, color: textPrimary),
                          ],
                        ],
                      ),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.comingSoon) ...[
                  const _ComingSoonChip(),
                  const SizedBox(width: 4),
                ],
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(
                    LucideIcons.chevronDown,
                    size: 16,
                    color: _mutedIconColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          ),
      ],
    );
  }
}

/// Shared layout for a 设置 item (web `SettingItem`): title (+ 即将支持 chip) and an
/// optional description on the left, a [trailing] control on the right. When
/// [onTap] is set the whole row is tappable (used by the numeric rows).
class _SettingItemShell extends StatelessWidget {
  const _SettingItemShell({
    required this.title,
    required this.trailing,
    this.description,
    this.comingSoon = false,
    this.onTap,
  });

  final String title;
  final String? description;
  final Widget trailing;
  final bool comingSoon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    if (comingSoon) ...[
                      const SizedBox(width: 6),
                      const _ComingSoonChip(),
                    ],
                  ],
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      description!,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// A boolean 设置 item with a trailing [Switch].
class _SwitchSettingRow extends StatelessWidget {
  const _SwitchSettingRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.comingSoon = false,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return _SettingItemShell(
      title: title,
      description: description,
      comingSoon: comingSoon,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

/// A 设置 item whose value is chosen from a dropdown of [options] `(value, 标签)`.
class _SelectSettingRow<T> extends StatelessWidget {
  const _SelectSettingRow({
    required this.title,
    required this.description,
    required this.value,
    required this.options,
    required this.onChanged,
    this.comingSoon = false,
  });

  final String title;
  final String description;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return _SettingItemShell(
      title: title,
      description: description,
      comingSoon: comingSoon,
      trailing: DropdownButton<T>(
        value: value,
        isDense: true,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(8),
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        items: [
          for (final (v, label) in options)
            DropdownMenuItem<T>(value: v, child: Text(label)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// A numeric 设置 item: shows the current value and opens a number prompt on tap.
class _NumberSettingRow extends StatelessWidget {
  const _NumberSettingRow({
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String title;
  final String description;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SettingItemShell(
      title: title,
      description: description,
      onTap: () async {
        final result = await _promptNumber(
          context,
          title: title,
          initial: value,
          min: min,
          max: max,
        );
        if (result != null) onChanged(result);
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatInt(value),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(LucideIcons.pencil, size: 14, color: _mutedIconColor),
        ],
      ),
    );
  }
}

/// A 设置 item rendered as a labelled slider over `[min, max]`.
class _SliderSettingRow extends StatelessWidget {
  const _SliderSettingRow({
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  final String title;
  final String description;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    color: textPrimary,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          Text(
            description,
            style: TextStyle(fontSize: 11.5, height: 1.3, color: textSecondary),
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// A read-only 设置 item: a label and a fixed value (e.g. 渲染引擎 / 高亮主题占位).
class _StaticSettingRow extends StatelessWidget {
  const _StaticSettingRow({
    required this.title,
    required this.value,
    this.comingSoon = false,
  });

  final String title;
  final String value;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    return _SettingItemShell(
      title: title,
      comingSoon: comingSoon,
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The amber 即将支持 badge. Re-declared here (rather than reusing the settings
/// feature's chip) because the chat feature must not import another feature's
/// presentation layer — `import_boundaries_test` Rule 3.
class _ComingSoonChip extends StatelessWidget {
  const _ComingSoonChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0x1FFFA000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x66FFA000)),
      ),
      child: const Text(
        '即将支持',
        style: TextStyle(
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w500,
          color: Color(0xFFB07400),
        ),
      ),
    );
  }
}

/// A compact info note at the top of an 即将支持 group body, explaining the
/// settings persist now and take effect once the subsystem lands.
class _ComingSoonNote extends StatelessWidget {
  const _ComingSoonNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 2, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.info,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prompts for an integer in `[min, max]`, returning the clamped value or null
/// on 取消.
Future<int?> _promptNumber(
  BuildContext context, {
  required String title,
  required int initial,
  required int min,
  required int max,
}) {
  final controller = TextEditingController(text: initial.toString());
  int? read() {
    final parsed = int.tryParse(controller.text.trim());
    if (parsed == null) return null;
    return parsed.clamp(min, max);
  }

  return showDialog<int>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          helperText: '范围 ${_formatInt(min)} – ${_formatInt(max)}',
        ),
        onSubmitted: (_) => Navigator.of(dialogContext).pop(read()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(read()),
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

/// Opens the 侧边栏宽度 dialog. Dragging live-previews the drawer; 保存 commits,
/// 取消 restores the original width.
Future<void> _showSidebarWidthDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _SidebarWidthDialog(),
  );
}

class _SidebarWidthDialog extends ConsumerStatefulWidget {
  const _SidebarWidthDialog();

  @override
  ConsumerState<_SidebarWidthDialog> createState() =>
      _SidebarWidthDialogState();
}

class _SidebarWidthDialogState extends ConsumerState<_SidebarWidthDialog> {
  late final double _original;
  late double _draft;
  final TextEditingController _field = TextEditingController();

  @override
  void initState() {
    super.initState();
    _original = ref.read(sidebarSettingsControllerProvider).sidebarWidth;
    _draft = _original;
    _field.text = _draft.round().toString();
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _apply(double value, double maxWidth) {
    final clamped = value.clamp(kSidebarWidthMin, maxWidth).toDouble();
    setState(() => _draft = clamped);
    _field.text = clamped.round().toString();
    ref
        .read(sidebarSettingsControllerProvider.notifier)
        .previewSidebarWidth(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxWidth = safeMaxSidebarWidth(MediaQuery.sizeOf(context).width);
    final display = _draft.clamp(kSidebarWidthMin, maxWidth).toDouble();
    final presets = [
      for (final p in kSidebarWidthPresets)
        if (p <= maxWidth) p,
    ];
    final controller = ref.read(sidebarSettingsControllerProvider.notifier);
    return AlertDialog(
      title: const Text('侧边栏宽度'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '当前: ${display.round()}px',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${kSidebarWidthMin.round()} – ${maxWidth.round()}px',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Slider(
            value: display,
            min: kSidebarWidthMin,
            max: maxWidth,
            onChanged: (v) => _apply(v, maxWidth),
          ),
          TextField(
            controller: _field,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              suffixText: 'px',
              labelText: '自定义宽度',
            ),
            onSubmitted: (raw) {
              final parsed = double.tryParse(raw.trim());
              if (parsed != null) _apply(parsed, maxWidth);
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final p in presets)
                ChoiceChip(
                  label: Text('${p.round()}'),
                  selected: display.round() == p.round(),
                  onSelected: (_) => _apply(p, maxWidth),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // 取消恢复原宽度（预览未持久化）。
            controller.previewSidebarWidth(_original);
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            controller.setSidebarWidth(display);
            Navigator.of(context).pop();
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

// ── 翻译 button ──────────────────────────────────────────────────────────────
class _TranslateButton extends StatelessWidget {
  const _TranslateButton();

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => context.push(AppRouter.translatePath),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(LucideIcons.languages, size: 22, color: textPrimary),
          ),
        ),
      ),
    );
  }
}

// ── Shared building blocks ──────────────────────────────────────────────────
/// Section header: `subtitle1` title (18.29px / 500) plus a right-aligned
/// cluster of action buttons.
class _TabHeader extends StatelessWidget {
  const _TabHeader({required this.title, required this.trailing});

  final String title;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18.29,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

/// The per-tab search box, shown when the 搜索 toggle is on. Mirrors the
/// original `TextField size="small"` (40px tall, 8px radius, `搜索…` hint).
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, height: 1.43),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          prefixIcon: const Icon(LucideIcons.search, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
        ),
      ),
    );
  }
}

/// A folder header for an assistant/topic group: expand toggle + name + count
/// + a rename/delete overflow menu.
class _GroupHeader extends ConsumerWidget {
  const _GroupHeader({
    required this.group,
    required this.count,
    required this.textPrimary,
    required this.textSecondary,
  });

  final Group group;
  final int count;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(groupsProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => notifier.toggleExpanded(group.id),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(
                  group.expanded
                      ? LucideIcons.chevronDown
                      : LucideIcons.chevronRight,
                  size: 16,
                  color: textSecondary,
                ),
                const SizedBox(width: 6),
                Icon(LucideIcons.folder, size: 16, color: textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.43,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.66,
                    color: textSecondary,
                  ),
                ),
                _OverflowMenuButton<_GroupMenu>(
                  size: 16,
                  box: 26,
                  title: group.name,
                  actions: const [
                    _SheetAction(_GroupMenu.rename, LucideIcons.edit3, '重命名分组'),
                    _SheetAction(
                      _GroupMenu.delete,
                      LucideIcons.trash,
                      '删除分组',
                      danger: true,
                    ),
                  ],
                  onSelected: (m) async {
                    switch (m) {
                      case _GroupMenu.rename:
                        final name = await _promptText(
                          context,
                          title: '重命名分组',
                          hint: '分组名称',
                          initial: group.name,
                        );
                        if (name != null) await notifier.rename(group.id, name);
                      case _GroupMenu.delete:
                        await notifier.deleteGroup(group.id);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _GroupMenu { rename, delete }

/// A centered, ~52px tall empty hint (matches the original's empty-list slot).
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 14, height: 1.43, color: color),
        ),
      ),
    );
  }
}

/// A "未分组助手 / 未分组话题" section label.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, height: 1.43, color: color),
      ),
    );
  }
}

/// Hides the scrollbar inside a [_ListFrame] — the web list box uses
/// `scrollbar-width: none`.
class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

/// A rounded, 1px-bordered box that frames a list section — the port of the web
/// `VirtualizedList` / group `Accordion` container (border `divider`, radius 8,
/// `background.paper` background). When [scrollable] is true the box fills the
/// height handed to it by its parent (an `Expanded`) and scrolls internally with
/// a hidden scrollbar — the port of the web list `maxHeight: calc(100vh - 400px)`
/// + `overflow: auto`. Filling the parent keeps the ungrouped box a consistent
/// height across the assistant and topic tabs regardless of item count.
class _ListFrame extends StatelessWidget {
  const _ListFrame({required this.children, this.scrollable = false});

  final List<Widget> children;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    if (scrollable) {
      content = ScrollConfiguration(
        behavior: const _NoScrollbarBehavior(),
        child: SingleChildScrollView(child: content),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      // Port of the web `background.paper` + `border: divider`: both follow the
      // theme so the box blends into the sidebar (light & dark) instead of
      // showing a hard-coded white block in dark mode.
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: content,
    );
  }
}

/// The centered "共 N 个…" footer.
class _CountFooter extends StatelessWidget {
  const _CountFooter({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 12, height: 1.66, color: color),
        ),
      ),
    );
  }
}

/// An outlined, pill-ish action button (创建分组 / 添加助手 / 新建话题):
/// `border 1px text.secondary`, radius 8, label 14px / 600, 16px start icon.
class _OutlinedPillButton extends StatelessWidget {
  const _OutlinedPillButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        side: BorderSide(color: theme.colorScheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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

/// A square avatar with a centered glyph (radius 25%, white text).
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.text,
    required this.background,
    required this.size,
    required this.fontSize,
  });

  final String text;
  final Color background;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: fontSize, height: 1, color: Colors.white),
      ),
    );
  }
}

/// The 兼容 API pill: 20px tall, 1px grey outline, 10.4px / 500 label.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: _chipBorderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.4,
          height: 1,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

/// A compact icon button mirroring MUI's `IconButton` sizing (`box` = the
/// 话题删除按钮:两次点击确认(1.5s 超时),像素级复刻原版
/// `TopicItem.handleDeleteClick`。默认态 [`LucideIcons.trash`] / opacity 0.6;
/// 确认态 [`LucideIcons.alertTriangle`] / opacity 1 / 红色。
class _ConfirmDeleteButton extends StatefulWidget {
  const _ConfirmDeleteButton({
    required this.size,
    required this.box,
    required this.color,
    required this.onConfirm,
  });

  final double size;
  final double box;
  final Color color;
  final VoidCallback onConfirm;

  @override
  State<_ConfirmDeleteButton> createState() => _ConfirmDeleteButtonState();
}

class _ConfirmDeleteButtonState extends State<_ConfirmDeleteButton> {
  bool _pending = false;
  Timer? _timer;

  void _handleTap() {
    if (_pending) {
      _reset();
      widget.onConfirm();
    } else {
      setState(() => _pending = true);
      _timer = Timer(const Duration(milliseconds: 1500), _reset);
    }
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _pending = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final danger = _pending;
    return IconButton(
      onPressed: _handleTap,
      iconSize: widget.size,
      color: danger ? _dangerColor : widget.color,
      padding: EdgeInsets.all((widget.box - widget.size) / 2),
      constraints: BoxConstraints.tightFor(
        width: widget.box,
        height: widget.box,
      ),
      splashRadius: widget.box / 2,
      icon: Opacity(
        opacity: danger ? 1 : 0.6,
        child: Icon(danger ? LucideIcons.alertTriangle : LucideIcons.trash),
      ),
    );
  }
}

/// A compact icon button mirroring MUI's `IconButton` sizing (`box` = the
/// square tap area, `size` = the glyph).
class _MutedIconButton extends StatelessWidget {
  const _MutedIconButton({
    required this.icon,
    required this.size,
    required this.box,
    this.color = _mutedIconColor,
    this.onPressed,
  });

  final IconData icon;
  final double size;
  final double box;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      // Settings-tab icons stay appearance-only; default to an enabled no-op so
      // they keep the original full-color tint (a null handler greys them out).
      onPressed: onPressed ?? () {},
      iconSize: size,
      color: color,
      padding: EdgeInsets.all((box - size) / 2),
      constraints: BoxConstraints.tightFor(width: box, height: box),
      splashRadius: box / 2,
      icon: Icon(icon),
    );
  }
}

/// One row in the per-item action sheet opened by [_OverflowMenuButton].
class _SheetAction<T> {
  const _SheetAction(this.value, this.icon, this.label, {this.danger = false});

  final T value;
  final IconData icon;
  final String label;
  final bool danger;
}

/// The per-row 更多 (`moreVertical`) trigger. Tapping opens a bottom action
/// sheet ([_showActionSheet]) rather than an anchored dropdown — far easier to
/// reach on a phone (large targets, never clipped at the screen edge) than the
/// cramped `PopupMenu` it replaces. Sized to match [_MutedIconButton] so the
/// row height is unchanged.
class _OverflowMenuButton<T> extends StatelessWidget {
  const _OverflowMenuButton({
    required this.actions,
    required this.onSelected,
    required this.size,
    required this.box,
    this.title,
    this.opacity = 0.6,
  });

  final List<_SheetAction<T>> actions;
  final ValueChanged<T> onSelected;
  final double size;
  final double box;
  final String? title;
  final double opacity;

  Future<void> _open(BuildContext context) async {
    final selected = await _showActionSheet<T>(
      context,
      title: title,
      actions: actions,
    );
    if (selected != null && context.mounted) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: InkResponse(
        onTap: () => _open(context),
        radius: box * 0.6,
        child: SizedBox(
          width: box,
          height: box,
          child: Icon(
            LucideIcons.moreVertical,
            size: size,
            color: _mutedIconColor,
          ),
        ),
      ),
    );
  }
}

/// A bottom action sheet listing [actions], optionally headed by [title]. Pops
/// with the chosen action's value, or `null` when dismissed. Replaces the
/// per-row anchored dropdown menus throughout the sidebar.
Future<T?> _showActionSheet<T>(
  BuildContext context, {
  required List<_SheetAction<T>> actions,
  String? title,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null && title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            for (final action in actions)
              ListTile(
                leading: Icon(
                  action.icon,
                  size: 20,
                  color: action.danger ? _dangerColor : null,
                ),
                title: Text(
                  action.label,
                  style: TextStyle(
                    fontSize: 15,
                    color: action.danger ? _dangerColor : null,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(action.value),
              ),
          ],
        ),
      );
    },
  );
}

/// Web avatar fallback: the assistant's emoji if set, else its name's first
/// character (`assistant.emoji || name.charAt(0)`).
String _assistantAvatarText(Assistant a) {
  final emoji = a.emoji;
  if (emoji != null && emoji.isNotEmpty) return emoji;
  if (a.name.isEmpty) return '?';
  return String.fromCharCodes(a.name.runes.take(1));
}

/// `MM/DD HH:mm` from `lastMessageTime` (ISO) falling back to `updatedAt`.
String _formatTopicTime(Topic t) {
  final raw = t.lastMessageTime;
  final dt = (raw != null ? DateTime.tryParse(raw) : null) ?? t.updatedAt;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}

// ── Dialogs ───────────────────────────────────────────────────────────────
/// The 添加助手 picker: a scrollable list of the 17 [kAssistantPresets].
Future<void> _showAddAssistantDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: const Text('选择助手'),
        contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  '选择一个预设助手来添加到你的助手列表中',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: kAssistantPresets.length,
                  itemBuilder: (context, index) {
                    final preset = kAssistantPresets[index];
                    return ListTile(
                      leading: Text(
                        preset.emoji ?? '🤖',
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(preset.name),
                      subtitle: preset.description == null
                          ? null
                          : Text(
                              preset.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () {
                        ref.read(assistantsProvider.notifier).addPreset(preset);
                        Navigator.of(dialogContext).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
        ],
      );
    },
  );
}

/// Prompts for a folder name and creates the group (创建分组 / 创建话题分组).
Future<void> _showCreateGroupDialog(
  BuildContext context,
  WidgetRef ref, {
  required GroupType type,
  String? assistantId,
}) async {
  final name = await _promptText(
    context,
    title: type == GroupType.assistant ? '创建助手分组' : '创建话题分组',
    hint: '分组名称',
  );
  if (name == null) return;
  await ref
      .read(groupsProvider.notifier)
      .createGroup(type: type, name: name, assistantId: assistantId);
}

/// Lists same-scope folders to drop [itemId] into, plus a "新建分组" option.
Future<void> _showAddToGroupDialog(
  BuildContext context,
  WidgetRef ref, {
  required GroupType type,
  String? assistantId,
  required String itemId,
}) async {
  final groups = type == GroupType.assistant
      ? ref.read(assistantGroupsProvider)
      : ref.read(topicGroupsProvider(assistantId!));
  final notifier = ref.read(groupsProvider.notifier);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return SimpleDialog(
        title: const Text('添加到分组'),
        children: [
          for (final g in groups)
            SimpleDialogOption(
              onPressed: () {
                notifier.addItemToGroup(g.id, itemId);
                Navigator.of(dialogContext).pop();
              },
              child: Row(
                children: [
                  const Icon(LucideIcons.folder, size: 18),
                  const SizedBox(width: 12),
                  Expanded(child: Text(g.name)),
                ],
              ),
            ),
          if (groups.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Text('还没有分组，先新建一个吧'),
            ),
          const Divider(height: 1),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final name = await _promptText(
                context,
                title: '新建分组',
                hint: '分组名称',
              );
              if (name == null) return;
              final id = await notifier.createGroup(
                type: type,
                name: name,
                assistantId: assistantId,
              );
              if (id != null) await notifier.addItemToGroup(id, itemId);
            },
            child: const Row(
              children: [
                Icon(LucideIcons.folderPlus, size: 18),
                SizedBox(width: 12),
                Text('新建分组'),
              ],
            ),
          ),
        ],
      );
    },
  );
}

/// Lists the other assistants to move [topic] into (移动到…).
Future<void> _showMoveTopicDialog(
  BuildContext context,
  WidgetRef ref, {
  required Topic topic,
}) async {
  final all = ref.read(assistantsProvider).asData?.value ?? const <Assistant>[];
  final others = all.where((a) => a.id != topic.assistantId).toList();
  final notifier = ref.read(topicsProvider.notifier);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return SimpleDialog(
        title: const Text('移动到...'),
        children: [
          for (final a in others)
            SimpleDialogOption(
              onPressed: () {
                notifier.move(topic.id, a.id);
                Navigator.of(dialogContext).pop();
              },
              child: Row(
                children: [
                  Text(
                    _assistantAvatarText(a),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(a.name)),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// A single-field text prompt; returns the trimmed text on 确定, else `null`.
Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String hint,
  String? initial,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) =>
        _PromptTextDialog(title: title, hint: hint, initial: initial),
  );
  if (result == null || result.isEmpty) return null;
  return result;
}

/// The single-field dialog backing [_promptText]. It owns the text field's
/// [TextEditingController] so the controller lives exactly as long as the
/// dialog element and is disposed by the framework when the route unmounts.
class _PromptTextDialog extends StatefulWidget {
  const _PromptTextDialog({
    required this.title,
    required this.hint,
    this.initial,
  });

  final String title;
  final String hint;
  final String? initial;

  @override
  State<_PromptTextDialog> createState() => _PromptTextDialogState();
}

class _PromptTextDialogState extends State<_PromptTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// A destructive confirm dialog; returns `true` only when 确定 is pressed.
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: _dangerColor),
            child: const Text('确定'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
