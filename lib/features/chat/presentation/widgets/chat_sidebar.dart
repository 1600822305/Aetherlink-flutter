/// Pixel-1:1 port of the original web chat-interface sidebar
/// (`src/components/TopicManagement/`): the 助手 / 话题 / 设置 tab shell plus the
/// per-tab content and the bottom 翻译 button.
///
/// This slice is appearance-only ("功能先不接"): nothing is wired to providers.
/// The lists are rendered from local, visual-only mock data ([_mockAssistants],
/// [_mockTopics], [_mockSettingsSections]) that mirrors the original's default
/// seed so the layout can be compared 1:1 against the web. Icons are migrated to
/// their lucide counterparts (ADR-0009); every literal color/size below is the
/// value measured from the live web DOM (`getComputedStyle`, light theme).
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

/// The original mobile drawer is 350px wide (`AppSidebar.solid.tsx`).
const double _sidebarWidth = 350;

class ChatSidebar extends StatefulWidget {
  const ChatSidebar({super.key});

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // The 翻译 button only renders on the 助手/话题 tabs, so rebuild on switch.
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
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
        child: Column(
          children: [
            const _CloseRow(),
            _SidebarTabBar(controller: _tabController),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [_AssistantTab(), _TopicTab(), _SettingsTab()],
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
        // Indicator: height 2px, radius 1px, currentColor @ opacity 0.55.
        indicator: UnderlineTabIndicator(
          borderRadius: BorderRadius.circular(1),
          borderSide: BorderSide(
            width: 2,
            color: textPrimary.withValues(alpha: 0.55),
          ),
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
class _AssistantTab extends StatelessWidget {
  const _AssistantTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: _TabHeader(
            title: '所有助手',
            trailing: [
              _MutedIconButton(icon: LucideIcons.search, size: 18, box: 28),
              SizedBox(width: 8),
              _OutlinedPillButton(icon: LucideIcons.folderPlus, label: '创建分组'),
              SizedBox(width: 4),
              _OutlinedPillButton(icon: LucideIcons.plus, label: '添加助手'),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              // VirtualizedAssistantGroups empty hint (centered, ~52px tall).
              SizedBox(
                height: 52,
                child: Center(
                  child: Text(
                    '没有助手分组',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.43,
                      color: textSecondary,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '未分组助手',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.43,
                    color: textSecondary,
                  ),
                ),
              ),
              for (final a in _mockAssistants)
                _AssistantItem(
                  data: a,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  primaryColor: theme.colorScheme.primary,
                ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    '共 ${_mockAssistants.length} 个助手',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.66,
                      color: textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssistantItem extends StatelessWidget {
  const _AssistantItem({
    required this.data,
    required this.textPrimary,
    required this.textSecondary,
    required this.primaryColor,
  });

  final _MockAssistant data;
  final Color textPrimary;
  final Color textSecondary;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: data.selected ? _selectedItemBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {},
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
                      text: data.avatarText,
                      background: data.selected
                          ? primaryColor
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
                        data.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.43,
                          fontWeight: data.selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        '${data.topicCount} 个话题',
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
                const _MutedIconButton(
                  icon: LucideIcons.moreVertical,
                  size: 16,
                  box: 26,
                  opacity: 0.6,
                ),
                _MutedIconButton(
                  icon: LucideIcons.trash,
                  size: 16,
                  box: 26,
                  opacity: 0.6,
                  color: textPrimary,
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
class _TopicTab extends StatelessWidget {
  const _TopicTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: _TabHeader(
            title: '默认助手',
            trailing: [
              const _MutedIconButton(
                icon: LucideIcons.search,
                size: 18,
                box: 28,
              ),
              const SizedBox(width: 8),
              // 创建话题分组: bordered icon-only button (radius 6).
              _BorderedIconButton(
                icon: LucideIcons.folderPlus,
                borderColor: textSecondary,
                color: textPrimary,
              ),
              const SizedBox(width: 4),
              const _OutlinedPillButton(icon: LucideIcons.plus, label: '新建话题'),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              SizedBox(
                height: 52,
                child: Center(
                  child: Text(
                    '没有话题分组',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.43,
                      color: textSecondary,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '未分组话题',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.43,
                    color: textSecondary,
                  ),
                ),
              ),
              for (final t in _mockTopics)
                _TopicItem(
                  data: t,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    '共 ${_mockTopics.length} 个话题',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.66,
                      color: textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopicItem extends StatelessWidget {
  const _TopicItem({
    required this.data,
    required this.textPrimary,
    required this.textSecondary,
  });

  final _MockTopic data;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: data.selected ? _selectedItemBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {},
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
                      Text(
                        data.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.43,
                          fontWeight: data.selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        data.preview,
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
                      data.time,
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
                        const _MutedIconButton(
                          icon: LucideIcons.moreVertical,
                          size: 16,
                          box: 20,
                          padding: 2,
                          opacity: 0.6,
                        ),
                        const SizedBox(width: 2),
                        _MutedIconButton(
                          icon: LucideIcons.trash,
                          size: 16,
                          box: 20,
                          padding: 2,
                          opacity: 0.6,
                          color: textPrimary,
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

/// An outlined, pill-ish action button (创建分组 / 添加助手 / 新建话题):
/// `border 1px text.secondary`, radius 8, label 14px / 600, 16px start icon.
class _OutlinedPillButton extends StatelessWidget {
  const _OutlinedPillButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: () {},
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
  });

  final IconData icon;
  final Color borderColor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: InkWell(
        onTap: () {},
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
  });

  final IconData icon;
  final double size;
  final double box;
  final double? padding;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: () {},
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

// ── Visual-only mock data (mirrors the original default seed) ───────────────
class _MockAssistant {
  const _MockAssistant({
    required this.name,
    required this.avatarText,
    required this.topicCount,
    this.selected = false,
  });

  final String name;
  final String avatarText;
  final int topicCount;
  final bool selected;
}

const List<_MockAssistant> _mockAssistants = [
  _MockAssistant(name: '默认助手', avatarText: '默', topicCount: 1, selected: true),
  _MockAssistant(name: '网页分析助手', avatarText: '网', topicCount: 1),
];

class _MockTopic {
  const _MockTopic({
    required this.title,
    required this.preview,
    required this.time,
    this.selected = false,
  });

  final String title;
  final String preview;
  final String time;
  final bool selected;
}

const List<_MockTopic> _mockTopics = [
  _MockTopic(
    title: '新的对话',
    preview: '无消息',
    time: '06/16 22:23',
    selected: true,
  ),
];

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
