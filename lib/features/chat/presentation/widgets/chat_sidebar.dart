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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/assistant_presets.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

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

/// List-frame box (port of the web `border: divider` + `background.paper`):
/// MUI light-theme `divider` = rgba(0,0,0,0.12); paper = white.
const Color _listFrameBorder = Color(0x1F000000);
const Color _listFrameBg = Color(0xFFFFFFFF);

/// The original mobile drawer is 350px wide (`AppSidebar.solid.tsx`).
const double _sidebarWidth = 350;

/// Max height of the ungrouped list box before it scrolls internally — the port
/// of the web list `maxHeight: calc(100vh - 400px)` (clamped so it stays usable
/// on short screens).
double _ungroupedMaxHeight(BuildContext context) {
  final h = MediaQuery.of(context).size.height - 400;
  return h < 160 ? 160 : h;
}

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
    // Restore the last active tab (persisted via [SidebarTabIndex]); the web
    // does the same with `settings.sidebarTabIndex`.
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: ref.read(sidebarTabIndexProvider),
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    // Persist the active tab so it survives reopening the drawer / a restart.
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
    // The persisted index can hydrate from storage after [initState] built the
    // controller (cold start), so keep the controller in sync with it.
    ref.listen<int>(sidebarTabIndexProvider, (previous, next) {
      if (_tabController.index != next) {
        _tabController.index = next;
      }
    });
    final showTranslate = _tabController.index != 2;

    return Drawer(
      width: _sidebarWidth,
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
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              if (searching) ...[
                if (filtered.isEmpty)
                  _EmptyHint(text: '没有找到助手', color: textSecondary)
                else
                  for (final a in filtered) item(a),
              ] else ...[
                if (groups.isEmpty)
                  _EmptyHint(text: '没有助手分组', color: textSecondary)
                else
                  for (final g in groups)
                    _ListFrame(
                      children: [
                        _GroupHeader(
                          group: g,
                          count: g.items.where(byId.containsKey).length,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        ),
                        if (g.expanded)
                          for (final id in g.items)
                            if (byId[id] != null) item(byId[id]!),
                      ],
                    ),
                _SectionLabel(text: '未分组助手', color: textSecondary),
                if (ungrouped.isEmpty)
                  _EmptyHint(text: '暂无未分组助手', color: textSecondary)
                else
                  _ListFrame(
                    maxHeight: _ungroupedMaxHeight(context),
                    children: [for (final a in ungrouped) item(a)],
                  ),
                _CountFooter(text: '共 ${all.length} 个助手', color: textSecondary),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

enum _AssistantMenu { addToGroup, copy, clearTopics, delete }

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
                  itemBuilder: (context) => [
                    _menuItem(
                      _AssistantMenu.addToGroup,
                      LucideIcons.folderPlus,
                      '添加到分组',
                    ),
                    _menuItem(_AssistantMenu.copy, LucideIcons.copy, '复制助手'),
                    _menuItem(
                      _AssistantMenu.clearTopics,
                      LucideIcons.trash2,
                      '清空话题',
                    ),
                    _menuItem(
                      _AssistantMenu.delete,
                      LucideIcons.trash,
                      '删除助手',
                      danger: true,
                    ),
                  ],
                  onSelected: (m) => _onMenu(context, ref, m),
                ),
                _MutedIconButton(
                  icon: LucideIcons.trash,
                  size: 16,
                  box: 26,
                  opacity: 0.6,
                  color: textPrimary,
                  onPressed: () => _deleteAssistant(context, ref),
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
    ref.read(currentTopicIdProvider.notifier).set(id);
    Scaffold.maybeOf(context)?.closeDrawer();
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
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    if (searching) ...[
                      if (filtered.isEmpty)
                        _EmptyHint(text: '没有找到话题', color: textSecondary)
                      else
                        for (final t in filtered) item(t),
                    ] else ...[
                      if (groups.isEmpty)
                        _EmptyHint(text: '没有话题分组', color: textSecondary)
                      else
                        for (final g in groups)
                          _ListFrame(
                            children: [
                              _GroupHeader(
                                group: g,
                                count: g.items.where(byId.containsKey).length,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                              ),
                              if (g.expanded)
                                for (final id in g.items)
                                  if (byId[id] != null) item(byId[id]!),
                            ],
                          ),
                      _SectionLabel(text: '未分组话题', color: textSecondary),
                      if (ungrouped.isEmpty)
                        _EmptyHint(text: '暂无未分组话题', color: textSecondary)
                      else
                        _ListFrame(
                          maxHeight: _ungroupedMaxHeight(context),
                          children: [for (final t in ungrouped) item(t)],
                        ),
                      _CountFooter(
                        text: '共 ${topics.length} 个话题',
                        color: textSecondary,
                      ),
                    ],
                  ],
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
                          padding: 2,
                          itemBuilder: (context) => [
                            _menuItem(
                              _TopicMenu.addToGroup,
                              LucideIcons.folderPlus,
                              '添加到分组',
                            ),
                            _menuItem(
                              _TopicMenu.rename,
                              LucideIcons.edit3,
                              '编辑话题',
                            ),
                            _menuItem(
                              _TopicMenu.togglePin,
                              topic.pinned
                                  ? LucideIcons.pinOff
                                  : LucideIcons.pin,
                              topic.pinned ? '取消固定' : '固定话题',
                            ),
                            _menuItem(
                              _TopicMenu.clearMessages,
                              LucideIcons.trash2,
                              '清空消息',
                            ),
                            if (canMove)
                              _menuItem(
                                _TopicMenu.move,
                                LucideIcons.arrowRight,
                                '移动到...',
                              ),
                            _menuItem(
                              _TopicMenu.delete,
                              LucideIcons.trash,
                              '删除话题',
                              danger: true,
                            ),
                          ],
                          onSelected: (m) => _onMenu(context, ref, m),
                        ),
                        const SizedBox(width: 2),
                        _MutedIconButton(
                          icon: LucideIcons.trash,
                          size: 16,
                          box: 20,
                          padding: 2,
                          opacity: 0.6,
                          color: textPrimary,
                          onPressed: () => _deleteTopic(context, ref),
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
class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      children: [
        _SettingsEntryRow(
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        const _SettingsDivider(),
        _UserAvatarRow(textPrimary: textPrimary, textSecondary: textSecondary),
        const _SettingsDivider(),
        for (var i = 0; i < _mockSettingsSections.length; i++) ...[
          _SettingsSectionRow(
            data: _mockSettingsSections[i],
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          if (i != _mockSettingsSections.length - 1) const _SettingsDivider(),
        ],
      ],
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    // `Divider my: 0.5` → 4px above/below a 1px line.
    return const Divider(height: 9, thickness: 1);
  }
}

class _SettingsEntryRow extends StatelessWidget {
  const _SettingsEntryRow({
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
          Container(
            width: 1,
            height: 24,
            color: Theme.of(context).dividerColor,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          // 侧边栏宽度 toggle.
          Material(
            color: _panelButtonBg,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () {},
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
  const _UserAvatarRow({
    required this.textPrimary,
    required this.textSecondary,
  });

  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
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
          const _MutedIconButton(icon: LucideIcons.user, size: 16, box: 28),
        ],
      ),
    );
  }
}

class _SettingsSectionRow extends StatelessWidget {
  const _SettingsSectionRow({
    required this.data,
    required this.textPrimary,
    required this.textSecondary,
  });

  final _MockSettingsSection data;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                        data.title,
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
                    if (data.chipLabel != null) ...[
                      const SizedBox(width: 6),
                      _Chip(label: data.chipLabel!, color: textPrimary),
                    ],
                  ],
                ),
                Text(
                  data.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (data.hasGear) ...[
            const _MutedIconButton(
              icon: LucideIcons.settings,
              size: 16,
              box: 28,
            ),
            const SizedBox(width: 4),
          ],
          const Icon(LucideIcons.chevronDown, size: 16, color: _mutedIconColor),
        ],
      ),
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
          onTap: () {},
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
                  itemBuilder: (context) => [
                    _menuItem(_GroupMenu.rename, LucideIcons.edit3, '重命名分组'),
                    _menuItem(
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
/// `background.paper` background). When [maxHeight] is set the content scrolls
/// internally with a hidden scrollbar (web `maxHeight: calc(100vh - 400px)`).
class _ListFrame extends StatelessWidget {
  const _ListFrame({required this.children, this.maxHeight});

  final List<Widget> children;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    if (maxHeight != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight!),
        child: ScrollConfiguration(
          behavior: const _NoScrollbarBehavior(),
          child: SingleChildScrollView(child: content),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _listFrameBg,
        border: Border.all(color: _listFrameBorder),
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
/// square tap area, `size` = the glyph). [opacity] dims the whole control like
/// the original's `opacity: 0.6` trailing actions.
class _MutedIconButton extends StatelessWidget {
  const _MutedIconButton({
    required this.icon,
    required this.size,
    required this.box,
    this.padding,
    this.opacity = 1,
    this.color = _mutedIconColor,
    this.onPressed,
  });

  final IconData icon;
  final double size;
  final double box;
  final double? padding;
  final double opacity;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      // Settings-tab icons stay appearance-only; default to an enabled no-op so
      // they keep the original full-color tint (a null handler greys them out).
      onPressed: onPressed ?? () {},
      iconSize: size,
      color: color,
      padding: EdgeInsets.all(padding ?? (box - size) / 2),
      constraints: BoxConstraints.tightFor(width: box, height: box),
      splashRadius: box / 2,
      icon: Icon(icon),
    );
    if (opacity == 1) return button;
    return Opacity(opacity: opacity, child: button);
  }
}

/// A `PopupMenuButton` styled to match [_MutedIconButton]'s compact sizing,
/// used for the per-row 更多 (`moreVertical`) menus.
class _OverflowMenuButton<T> extends StatelessWidget {
  const _OverflowMenuButton({
    required this.itemBuilder,
    required this.onSelected,
    required this.size,
    required this.box,
    this.padding,
    this.opacity = 0.6,
  });

  final List<PopupMenuEntry<T>> Function(BuildContext) itemBuilder;
  final ValueChanged<T> onSelected;
  final double size;
  final double box;
  final double? padding;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: PopupMenuButton<T>(
        itemBuilder: itemBuilder,
        onSelected: onSelected,
        tooltip: '',
        padding: EdgeInsets.all(padding ?? (box - size) / 2),
        iconSize: size,
        icon: const Icon(LucideIcons.moreVertical, color: _mutedIconColor),
      ),
    );
  }
}

PopupMenuItem<T> _menuItem<T>(
  T value,
  IconData icon,
  String label, {
  bool danger = false,
}) {
  final color = danger ? _dangerColor : null;
  return PopupMenuItem<T>(
    value: value,
    height: 40,
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 14, color: color)),
      ],
    ),
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

// ── Settings-tab visual-only mock data (mirrors the original default seed) ──
class _MockSettingsSection {
  const _MockSettingsSection({
    required this.title,
    required this.subtitle,
    this.chipLabel,
    this.hasGear = false,
  });

  final String title;
  final String subtitle;
  final String? chipLabel;
  final bool hasGear;
}

const List<_MockSettingsSection> _mockSettingsSections = [
  _MockSettingsSection(title: '常规设置', subtitle: '8 个基础功能设置'),
  _MockSettingsSection(
    title: '上下文设置',
    subtitle: '窗口: 100,000 | 输出: 8192',
    chipLabel: '兼容 API',
    hasGear: true,
  ),
  _MockSettingsSection(title: '输入设置', subtitle: '粘贴和输入相关的功能设置'),
  _MockSettingsSection(title: '性能节流强度', subtitle: '当前: 中度节流'),
  _MockSettingsSection(title: '代码块设置', subtitle: '配置代码显示和编辑功能'),
  _MockSettingsSection(title: '数学公式设置', subtitle: '渲染引擎: KaTeX'),
  _MockSettingsSection(title: 'MCP 工具', subtitle: '模式: 函数调用'),
];
