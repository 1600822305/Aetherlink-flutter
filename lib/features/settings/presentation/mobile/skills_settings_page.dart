import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/assistants_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/core/platform/platform_providers.dart';
import 'package:aetherlink_flutter/features/settings/application/skills_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';

/// The "技能管理 Skills" settings page (提示词与工具 → this page), a port of the
/// original `src/pages/Settings/SkillsSettings.tsx`.
///
/// The original stacks everything in one scroll (search → built-in list with
/// its own 50vh inner scroll → custom list with another inner scroll → a long
/// tutorial), which nests scroll views and buries the lists under the tutorial.
/// This refactor keeps the original look-and-feel but splits the body into
/// three tabs — 内置 / 自定义 / 说明 — each a single full-height scroll, with the
/// search + stats header pinned above the tab strip (same instant-swap +
/// horizontal-swipe tab mechanic as the MCP 服务器 page).
///
/// The library is read from / mutated through [Skills] (the skill store):
/// enable / disable, delete, create (→ 技能编辑器), import / export JSON, 检查更新,
/// and 绑定助手 are wired. Per-skill 导出 SKILL.md is the only remaining
/// 「即将支持」 (the Markdown serializer is deferred).
class SkillsSettingsPage extends ConsumerStatefulWidget {
  const SkillsSettingsPage({super.key});

  @override
  ConsumerState<SkillsSettingsPage> createState() => _SkillsSettingsPageState();
}

class _SkillsSettingsPageState extends ConsumerState<SkillsSettingsPage>
    with SingleTickerProviderStateMixin {
  static const String _title = '技能管理 Skills';

  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  )..addListener(_onTabChanged);

  // The shown tab is driven straight off the controller via an [IndexedStack]
  // (updated the moment a tab is tapped or swiped), while the strip's indicator
  // still slides — matching the MCP page's instant content swap.
  int _index = 0;

  // Horizontal swipe accumulator; a >60px drag jumps to the adjacent tab.
  double _swipeDx = 0;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  void _onTabChanged() {
    if (_tabController.index != _index) {
      setState(() => _index = _tabController.index);
    }
  }

  void _onSwipeEnd() {
    if (_swipeDx.abs() <= 60) return;
    final next = (_tabController.index + (_swipeDx < 0 ? 1 : -1)).clamp(0, 2);
    if (next != _tabController.index) _tabController.animateTo(next);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  // —— derived data ——

  List<Skill> _filter(List<Skill> list) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.description.toLowerCase().contains(q) ||
              s.tags.any((t) => t.toLowerCase().contains(q)),
        )
        .toList();
  }

  void _toast(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  void _comingSoon() => _toast('即将支持');

  Skills get _skills => ref.read(skillsProvider.notifier);

  // —— actions ——

  /// Creates a blank user skill and jumps straight into the 技能编辑器 (port of
  /// the web 新建技能 → navigate to `/settings/skills/:id`).
  Future<void> _create() async {
    final skill = await _skills.create();
    if (!mounted) return;
    context.push(AppRouter.skillEditorPath(skill.id));
  }

  Future<void> _toggle(Skill skill, bool enabled) async {
    final ok = await _skills.toggle(skill.id, enabled: enabled);
    if (!ok && mounted) _toast('最多同时启用 $kMaxEnabledSkills 个技能');
  }

  Future<void> _delete(Skill skill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除技能'),
        content: Text('确定删除「${skill.name}」吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _skills.remove(skill.id);
    if (mounted) _toast('已删除');
  }

  /// Re-runs the skill store's build (re-merges any newly-shipped built-in).
  void _refresh() {
    ref.invalidate(skillsProvider);
    _toast('已刷新');
  }

  /// Merges built-in catalog upgrades, preserving the user's enabled state
  /// (port of 检查更新 → `SkillManager.upgradeBuiltinSkills`).
  Future<void> _checkUpdates() async {
    final upgraded = await _skills.upgradeBuiltins();
    if (!mounted) return;
    _toast(upgraded > 0 ? '已更新 $upgraded 个内置技能' : '内置技能已是最新');
  }

  /// Picks a JSON file and imports every skill it holds (port of 导入技能).
  Future<void> _import() async {
    final picked = await ref
        .read(fileSystemApiProvider)
        .pickFile(allowedExtensions: const ['json']);
    if (picked == null) return;
    try {
      final raw = await ref
          .read(fileSystemApiProvider)
          .readAsString(picked.path);
      final result = await _skills.importFromJson(raw);
      if (!mounted) return;
      _toast(
        result.skipped > 0
            ? '导入 ${result.imported} 个技能，跳过 ${result.skipped} 个'
            : '成功导入 ${result.imported} 个技能',
      );
    } on FormatException catch (e) {
      if (mounted) _toast('导入失败：${e.message}');
    } catch (e) {
      if (mounted) _toast('导入失败：$e');
    }
  }

  /// Writes the whole library to a temp JSON file and opens the share sheet
  /// (port of 导出全部).
  Future<void> _exportAll() async {
    final fs = ref.read(fileSystemApiProvider);
    final doc = _skills.exportToJson();
    final dir = await fs.temporaryDirectoryPath();
    final path =
        '$dir/aetherlink-skills-${DateTime.now().millisecondsSinceEpoch}.json';
    await fs.writeAsString(
      path,
      const JsonEncoder.withIndent('  ').convert(doc),
    );
    await ref.read(shareApiProvider).shareFiles([path], subject: '技能库导出');
  }

  Future<void> _bind(Skill skill) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _BindAssistantsSheet(skill: skill),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(skillsProvider).asData?.value ?? const <Skill>[];
    // Single-pass split + enabled count.
    final builtin = <Skill>[];
    final custom = <Skill>[];
    var enabledCount = 0;
    for (final s in all) {
      if (s.source == SkillSource.builtin) {
        builtin.add(s);
      } else {
        custom.add(s);
      }
      if (s.enabled) enabledCount++;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            color: theme.colorScheme.primary,
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRouter.settingsPath),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text(_title),
        actions: [
          IconButton(
            tooltip: '技能商店',
            icon: const Icon(LucideIcons.store, size: 18),
            color: theme.colorScheme.primary,
            onPressed: () => context.push(AppRouter.skillStorePath),
          ),
          IconButton(
            tooltip: '导入技能',
            icon: const Icon(LucideIcons.upload, size: 18),
            onPressed: _import,
          ),
          IconButton(
            tooltip: '导出全部',
            icon: const Icon(LucideIcons.download, size: 18),
            onPressed: _exportAll,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: '新建技能',
              icon: const Icon(LucideIcons.plus, size: 20),
              color: theme.colorScheme.primary,
              onPressed: _create,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _searchHeader(theme, all.length, enabledCount),
          _TabBarHeader(controller: _tabController),
          Expanded(
            child: GestureDetector(
              onHorizontalDragStart: (_) => _swipeDx = 0,
              onHorizontalDragUpdate: (d) => _swipeDx += d.delta.dx,
              onHorizontalDragEnd: (_) => _onSwipeEnd(),
              child: _index == 2
                  ? const _TutorialTab()
                  : _index == 1
                      ? _customTab(theme, custom)
                      : _builtinTab(theme, builtin),
            ),
          ),
        ],
      ),
    );
  }

  // —— search + stats header (pinned above the tab strip) ——

  Widget _searchHeader(ThemeData theme, int total, int enabled) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '搜索技能...',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '刷新',
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                onPressed: _refresh,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '共 $total 个技能，$enabled 个已启用',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              TextButton.icon(
                onPressed: _checkUpdates,
                icon: const Icon(LucideIcons.refreshCw, size: 14),
                label: const Text('检查更新'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // —— tab bodies ——

  Widget _builtinTab(ThemeData theme, List<Skill> builtin) {
    final skills = _filter(builtin);
    if (skills.isEmpty) return _noResults(theme);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomPad),
      itemCount: skills.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _card(skills[i]),
    );
  }

  Widget _customTab(ThemeData theme, List<Skill> custom) {
    final skills = _filter(custom);
    if (skills.isEmpty) {
      return _query.trim().isNotEmpty ? _noResults(theme) : _customEmpty(theme);
    }
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomPad),
      itemCount: skills.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _card(skills[i]),
    );
  }

  Widget _card(Skill skill) => _SkillCard(
    skill: skill,
    onTap: () => context.push(AppRouter.skillEditorPath(skill.id)),
    onBind: () => _bind(skill),
    onExport: _comingSoon,
    onToggle: (enabled) => _toggle(skill, enabled),
    onDelete: skill.source == SkillSource.user ? () => _delete(skill) : null,
  );

  Widget _customEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '还没有自定义技能',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _create,
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('创建第一个技能'),
          ),
        ],
      ),
    );
  }

  Widget _noResults(ThemeData theme) {
    return Center(
      child: Text(
        '没有找到匹配的技能',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The full-width tab strip below the search header (icon + label, 1px bottom
/// divider), mirroring the original MUI `Tabs variant="fullWidth"`.
class _TabBarHeader extends StatelessWidget {
  const _TabBarHeader({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: TabBar(
        controller: controller,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        indicatorColor: theme.colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        tabs: const [
          _IconTab(icon: LucideIcons.zap, label: '内置'),
          _IconTab(icon: LucideIcons.users, label: '自定义'),
          _IconTab(icon: LucideIcons.bookOpen, label: '说明'),
        ],
      ),
    );
  }
}

class _IconTab extends StatelessWidget {
  const _IconTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 46,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
      ),
    );
  }
}

/// A single skill row — the port of `renderSkillCard`: emoji + name +
/// description on the left; bind / export / delete (user-only) / enable switch /
/// chevron on the right; tags + usage chips below.
class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.skill,
    required this.onTap,
    required this.onBind,
    required this.onExport,
    required this.onToggle,
    this.onDelete,
  });

  final Skill skill;
  final VoidCallback onTap;
  final VoidCallback onBind;
  final VoidCallback onExport;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.02);
    final hasMeta =
        skill.tags.isNotEmpty ||
        (skill.usageCount != null && skill.usageCount! > 0);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          skill.emoji ?? '🔧',
                          style: const TextStyle(fontSize: 19, height: 1),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                skill.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                skill.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  _iconAction(
                    theme,
                    icon: LucideIcons.users,
                    size: 14,
                    tooltip: '绑定助手',
                    onPressed: onBind,
                  ),
                  _iconAction(
                    theme,
                    icon: LucideIcons.download,
                    size: 14,
                    tooltip: '导出为 SKILL.md',
                    onPressed: onExport,
                  ),
                  if (onDelete != null)
                    _iconAction(
                      theme,
                      icon: LucideIcons.trash2,
                      size: 16,
                      color: theme.colorScheme.error,
                      tooltip: '删除',
                      onPressed: onDelete!,
                    ),
                  const SizedBox(width: 4),
                  CustomSwitch(value: skill.enabled, onChanged: onToggle),
                  const SizedBox(width: 4),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
              if (hasMeta) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final tag in skill.tags.take(3))
                            _TagChip(label: tag),
                        ],
                      ),
                    ),
                    if (skill.usageCount != null && skill.usageCount! > 0)
                      _UsageChip(count: skill.usageCount!),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconAction(
    ThemeData theme, {
    required IconData icon,
    required double size,
    required VoidCallback onPressed,
    String? tooltip,
    Color? color,
  }) {
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      icon: Icon(icon, size: size),
      color: color ?? theme.colorScheme.onSurfaceVariant,
      onPressed: onPressed,
    );
  }
}

/// An outlined tag chip (h20, 11px), the port of the card's `Chip variant
/// "outlined"`.
class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 11,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The filled usage-count chip (BarChart icon + "N次"), the port of the card's
/// `usageCount` chip.
class _UsageChip extends StatelessWidget {
  const _UsageChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.barChart3,
            size: 10,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            '$count次',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The 说明 tab — the port of the original 使用教程 panel: 什么是技能 / 快速上手 /
/// 进阶用法 / 搭配桥梁模式.
class _TutorialTab extends StatelessWidget {
  const _TutorialTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomPad),
      children: [
        _section(
          theme,
          title: '什么是技能？',
          child: _body(
            theme,
            '技能是一段预设的指令（Markdown 格式），可以让 AI 助手获得特定能力。绑定即可用，无需手动激活，多个技能可同时生效。',
          ),
        ),
        const SizedBox(height: 16),
        _section(
          theme,
          title: '快速上手（3步）',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _orderedStep(theme, 1, '启用技能', ' — 打开技能右侧的开关'),
              _orderedStep(theme, 2, '绑定助手', ' — 点击技能上的 👥 图标，勾选要使用此技能的助手'),
              _orderedStep(
                theme,
                3,
                '开启工具',
                ' — 确保 MCP 工具总开关已开启，AI 会通过 read_skill 工具自动读取技能指令',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _section(
          theme,
          title: '进阶用法',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bullet(theme, '绑定多个技能时，AI 根据用户请求自动匹配最合适的技能'),
              _bullet(theme, '点击右上角 + 号可以创建自己的技能'),
              _bullet(theme, '支持导入/导出 JSON 和 SKILL.md 格式，兼容 OpenClaw 技能生态'),
              _bullet(theme, '技能可以关联 MCP 工具服务器，激活技能时自动启动对应工具'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _section(
          theme,
          title: '🔌 搭配桥梁模式',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bullet(
                theme,
                '开启桥梁模式后，AI 同时拥有 read_skill（读取技能）和 mcp_bridge（调用 MCP 工具）两个工具',
              ),
              _bullet(theme, 'AI 可以先读取技能指令，再通过桥梁模式动态调用 MCP 工具完成复杂任务'),
              _bullet(theme, '不开桥梁模式也能用技能 — read_skill 工具独立于桥梁模式，始终可用'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(
    ThemeData theme, {
    required String title,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontSize: 13,
        height: 1.8,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _orderedStep(ThemeData theme, int n, String bold, String rest) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            height: 1.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          children: [
            TextSpan(text: '$n. '),
            TextSpan(
              text: bold,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: rest),
          ],
        ),
      ),
    );
  }

  Widget _bullet(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              height: 1.8,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                height: 1.8,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 绑定助手 bottom sheet — lists every assistant with a checkbox per
/// [skill]. Toggling persists through [Assistants.toggleSkill] (add/remove the
/// skill id on `assistant.skillIds`); the sheet rebuilds off [assistantsProvider]
/// so checkboxes reflect the new binding instantly.
class _BindAssistantsSheet extends ConsumerWidget {
  const _BindAssistantsSheet({required this.skill});

  final Skill skill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final assistants =
        ref.watch(assistantsProvider).asData?.value ?? const <Assistant>[];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(skill.emoji ?? '🔧', style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '绑定到助手 · ${skill.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (assistants.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                '暂无助手',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: assistants.length,
                itemBuilder: (_, i) {
                  final assistant = assistants[i];
                  final bound = (assistant.skillIds ?? const <String>[])
                      .contains(skill.id);
                  return CheckboxListTile(
                    value: bound,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    secondary: Text(
                      assistant.emoji ?? '🤖',
                      style: const TextStyle(fontSize: 18),
                    ),
                    title: Text(
                      assistant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    onChanged: (_) => ref
                        .read(assistantsProvider.notifier)
                        .toggleSkill(assistant.id, skill.id),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
