import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/chat/domain/agent_prompt.dart';
import 'package:aetherlink_flutter/features/settings/application/system_prompt_variables_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/system_prompt_variables.dart';
import 'package:aetherlink_flutter/shared/utils/system_prompt_variables.dart';

/// The 智能体提示词集合 page (提示词与工具 → this page), a port of the original
/// `src/pages/Settings/AgentPrompts/index.tsx`.
///
/// Reproduces the original layout top-to-bottom: the 系统提示词变量注入 panel, a
/// search box, and the built-in catalog rendered as collapsible category cards
/// of prompt cards (emoji + name + description + tags + 复制). Search, expand /
/// collapse and copy-to-clipboard are real; the variable toggles persist to the
/// Drift KV store ([SystemPromptVariablesController]) and are injected into the
/// system prompt on send (see `chat_controller._buildSystemPrompt`).
///
/// The catalog is the already-ported static data ([getAgentPromptCategories] /
/// [searchAgentPrompts]) — no service layer, no fabricated runtime state.
class AgentPromptsSettingsPage extends StatefulWidget {
  const AgentPromptsSettingsPage({super.key});

  @override
  State<AgentPromptsSettingsPage> createState() =>
      _AgentPromptsSettingsPageState();
}

class _AgentPromptsSettingsPageState extends State<AgentPromptsSettingsPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedCategories = <String>{'general'};
  String _query = '';
  String? _copiedPromptId;
  Timer? _copiedResetTimer;

  late final List<AgentPromptCategory> _categories = getAgentPromptCategories();

  // Two tabs: 变量注入 (system-prompt variables) and 提示词库 (search + catalog).
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  )..addListener(_onTabChanged);

  // Drive the shown tab off the controller via an [IndexedStack] so content
  // swaps the moment a tab is tapped or swiped (the indicator still slides),
  // mirroring 外观设置.
  int _index = 0;

  // Horizontal swipe accumulator: a >60px drag jumps to the adjacent tab.
  double _swipeDx = 0;

  void _onTabChanged() {
    if (_tabController.index != _index) {
      setState(() => _index = _tabController.index);
    }
  }

  void _onSwipeEnd() {
    if (_swipeDx.abs() <= 60) return;
    final next = (_tabController.index + (_swipeDx < 0 ? 1 : -1)).clamp(0, 1);
    if (next != _tabController.index) _tabController.animateTo(next);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _copiedResetTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleCategory(String categoryId) {
    setState(() {
      if (!_expandedCategories.remove(categoryId)) {
        _expandedCategories.add(categoryId);
      }
    });
  }

  Future<void> _copyPrompt(AgentPrompt prompt) async {
    await Clipboard.setData(ClipboardData(text: prompt.content));
    if (!mounted) return;
    setState(() => _copiedPromptId = prompt.id);
    _copiedResetTimer?.cancel();
    _copiedResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedPromptId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim();
    final results = query.isEmpty
        ? const <AgentPrompt>[]
        : searchAgentPrompts(query);

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
        title: const Text('智能体提示词集合'),
      ),
      body: Column(
        children: [
          _TabBarHeader(controller: _tabController),
          Expanded(
            child: GestureDetector(
              onHorizontalDragStart: (_) => _swipeDx = 0,
              onHorizontalDragUpdate: (d) => _swipeDx += d.delta.dx,
              onHorizontalDragEnd: (_) => _onSwipeEnd(),
              child: IndexedStack(
                index: _index,
                sizing: StackFit.expand,
                children: [
                  const _TabList(
                    children: [
                      _SystemPromptVariablesPanel(),
                      SizedBox(height: 12),
                      _PlaceholderVariablesCard(),
                    ],
                  ),
                  _TabList(
                    children: [
                      _searchCard(theme),
                      if (query.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        if (results.isNotEmpty)
                          _searchResultsCard(theme, results)
                        else
                          _noResultsCard(theme),
                      ] else
                        for (final category in _categories) ...[
                          const SizedBox(height: 8),
                          _categoryCard(theme, category),
                        ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A slim standalone search box (the original verbose 搜索提示词 card header /
  /// subtitle was dropped to compact the 提示词库 tab).
  Widget _searchCard(ThemeData theme) {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: theme.colorScheme.surface,
        hintText: '搜索提示词...',
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        prefixIcon: const Icon(LucideIcons.search, size: 18),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _searchResultsCard(ThemeData theme, List<AgentPrompt> results) {
    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Text(
              '搜索结果 · ${results.length}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                for (var i = 0; i < results.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  _promptCard(theme, results[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noResultsCard(ThemeData theme) {
    return _OutlinedCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            '没有找到匹配的提示词',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryCard(ThemeData theme, AgentPromptCategory category) {
    final isExpanded = _expandedCategories.contains(category.id);
    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _toggleCategory(category.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${category.emoji} ${category.name}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${category.prompts.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(height: 1, color: theme.dividerColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < category.prompts.length; i++) ...[
                    if (i > 0) const SizedBox(height: 6),
                    _promptCard(theme, category.prompts[i]),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _promptCard(ThemeData theme, AgentPrompt prompt) {
    final copied = _copiedPromptId == prompt.id;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '${prompt.emoji} ${prompt.name}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ModelTonalButton(
                  label: copied ? '已复制' : '复制',
                  icon: copied ? LucideIcons.check : LucideIcons.copy,
                  accent: copied ? const Color(0xFF2E7D32) : null,
                  onPressed: () => _copyPrompt(prompt),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              prompt.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12.5,
                height: 1.3,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (prompt.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [for (final tag in prompt.tags) _TagChip(label: tag)],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The 系统提示词变量注入 panel (the port of `SystemPromptVariablesPanel.tsx`):
/// a collapsible card whose header summarises the enabled variables and whose
/// body toggles time / location / OS injection. State is bound to
/// [SystemPromptVariablesController] (Drift-persisted) so toggles take effect on
/// the next sent message.
class _SystemPromptVariablesPanel extends ConsumerStatefulWidget {
  const _SystemPromptVariablesPanel();

  @override
  ConsumerState<_SystemPromptVariablesPanel> createState() =>
      _SystemPromptVariablesPanelState();
}

class _SystemPromptVariablesPanelState
    extends ConsumerState<_SystemPromptVariablesPanel> {
  bool _expanded = false;
  final TextEditingController _locationController = TextEditingController();
  final FocusNode _locationFocus = FocusNode();

  @override
  void dispose() {
    _locationController.dispose();
    _locationFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = ref.watch(systemPromptVariablesControllerProvider);
    final controller = ref.read(
      systemPromptVariablesControllerProvider.notifier,
    );

    // Keep the field in sync with the persisted value (e.g. after async
    // hydration) without disrupting the cursor while the user is typing.
    if (!_locationFocus.hasFocus &&
        _locationController.text != config.customLocation) {
      _locationController.value = TextEditingValue(
        text: config.customLocation,
        selection: TextSelection.collapsed(
          offset: config.customLocation.length,
        ),
      );
    }

    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题 + 状态（时间等）+ 展开箭头同一行
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '🔧 系统提示词变量注入',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusIndicator(theme, config),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // 说明文字单独一行
                  Text(
                    '为系统提示词自动注入时间、位置等动态变量',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: theme.dividerColor),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoBanner(theme),
                  const SizedBox(height: 14),
                  _variableRow(
                    theme: theme,
                    icon: LucideIcons.clock,
                    label: '时间变量',
                    description: '自动注入当前时间：${getCurrentTimeString()}',
                    value: config.enableTimeVariable,
                    onChanged: controller.setEnableTimeVariable,
                    expansion: config.enableTimeVariable
                        ? _hintBox(theme, '将在系统提示词末尾自动追加时间信息')
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _variableRow(
                    theme: theme,
                    icon: LucideIcons.mapPin,
                    label: '位置变量',
                    description:
                        '注入位置信息：${getLocationString(config.customLocation)}',
                    value: config.enableLocationVariable,
                    onChanged: controller.setEnableLocationVariable,
                    expansion: config.enableLocationVariable
                        ? _locationField(theme, controller)
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _variableRow(
                    theme: theme,
                    icon: LucideIcons.monitor,
                    label: '操作系统变量',
                    description: '注入操作系统信息：${getOperatingSystemString()}',
                    value: config.enableOSVariable,
                    onChanged: controller.setEnableOSVariable,
                    expansion: config.enableOSVariable
                        ? _hintBox(theme, '将在系统提示词末尾自动追加操作系统信息')
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _variableRow(
                    theme: theme,
                    icon: LucideIcons.languages,
                    label: '语言变量',
                    description: '注入当前语言：${getLocaleString()}',
                    value: config.enableLocaleVariable,
                    onChanged: controller.setEnableLocaleVariable,
                    expansion: config.enableLocaleVariable
                        ? _hintBox(theme, '将在系统提示词末尾自动追加界面语言，便于模型用对应语言回复')
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusIndicator(ThemeData theme, SystemPromptVariables config) {
    final chips = <Widget>[
      if (config.enableTimeVariable)
        const _StatusChip(icon: LucideIcons.clock, label: '时间'),
      if (config.enableLocationVariable)
        const _StatusChip(icon: LucideIcons.mapPin, label: '位置'),
      if (config.enableOSVariable)
        const _StatusChip(icon: LucideIcons.monitor, label: '系统'),
      if (config.enableLocaleVariable)
        const _StatusChip(icon: LucideIcons.languages, label: '语言'),
    ];
    if (chips.isEmpty) {
      return Text(
        '未启用',
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Wrap(spacing: 4, runSpacing: 4, children: chips);
  }

  Widget _infoBanner(ThemeData theme) {
    final accent = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '启用后，系统会在发送消息时自动在系统提示词末尾追加相应的变量信息。',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                height: 1.35,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _variableRow({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? expansion,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: theme.colorScheme.onSurface),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: CustomSwitch(value: value, onChanged: onChanged),
            ),
          ],
        ),
        if (expansion != null) ...[const SizedBox(height: 12), expansion],
      ],
    );
  }

  Widget _locationField(
    ThemeData theme,
    SystemPromptVariablesController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _locationController,
          focusNode: _locationFocus,
          onChanged: controller.setCustomLocation,
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            hintText: '输入自定义位置（如：北京市朝阳区）',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _hintBox(theme, '将在系统提示词末尾自动追加位置信息\n留空将使用系统检测的位置信息'),
      ],
    );
  }

  Widget _hintBox(ThemeData theme, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          height: 1.35,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The scrollable body of a single tab: its cards, with the page's standard
/// 16px gutter plus the bottom safe-area inset (matches 外观设置's `_TabList`).
class _TabList extends StatelessWidget {
  const _TabList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      children: children,
    );
  }
}

/// The tab strip below the app bar — the project's segmented pill style (a
/// rounded bordered track holding pill tabs with a tinted rounded indicator),
/// matching 外观设置.
class _TabBarHeader extends StatelessWidget {
  const _TabBarHeader({required this.controller});

  final TabController controller;

  static const List<(IconData, String)> _tabs = [
    (LucideIcons.wrench, '变量注入'),
    (LucideIcons.library, '提示词库'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
          color: theme.colorScheme.surface,
        ),
        padding: const EdgeInsets.all(3),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerHeight: 0,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          tabs: [
            for (final (icon, label) in _tabs)
              Tab(
                height: 34,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15),
                    const SizedBox(width: 5),
                    Text(label),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A rounded, bordered surface card with the project's soft shadow; children
/// supply their own padding (mirrors the original `Paper` panels).
class _OutlinedCard extends StatelessWidget {
  const _OutlinedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // rgba(0,0,0,0.05)
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A card section header tinted with the original's faint `rgba(0,0,0,0.01)`.
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: theme.colorScheme.onSurface.withValues(alpha: 0.015),
      child: child,
    );
  }
}

/// An outlined, primary-tinted status pill (icon + label) for the panel header.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// The 占位符变量 reference card (the inline-substitution counterpart of the
/// append-only [_SystemPromptVariablesPanel]): lists the placeholders that
/// [replaceSystemPromptPlaceholders] resolves at send time. Unlike the toggles,
/// these are used by typing them into an assistant / topic 系统提示词, so the card
/// is purely informational — tapping a row copies the token to the clipboard.
class _PlaceholderVariablesCard extends StatefulWidget {
  const _PlaceholderVariablesCard();

  @override
  State<_PlaceholderVariablesCard> createState() =>
      _PlaceholderVariablesCardState();
}

class _PlaceholderVariablesCardState extends State<_PlaceholderVariablesCard> {
  static const List<(String, String)> _placeholders = [
    ('{cur_date}', '当前日期，如 2026-06-28'),
    ('{cur_time}', '当前时间，如 14:30'),
    ('{cur_datetime}', '当前日期时间'),
    ('{model_name}', '当前模型名称'),
    ('{model_id}', '当前模型 ID'),
    ('{assistant_name}', '当前助手名称'),
    ('{provider_name}', '当前供应商名称'),
  ];

  String? _copiedToken;
  Timer? _copiedResetTimer;

  @override
  void dispose() {
    _copiedResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy(String token) async {
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) return;
    setState(() => _copiedToken = token);
    _copiedResetTimer?.cancel();
    _copiedResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedToken = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📝 占位符变量',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '在助手或话题的系统提示词中写入下列占位符，发送时会自动替换为实际值。点按可复制。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12.5,
                    height: 1.35,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (final (token, desc) in _placeholders)
                  _placeholderRow(theme, token, desc),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderRow(ThemeData theme, String token, String desc) {
    final copied = _copiedToken == token;
    final accent = theme.colorScheme.primary;
    return InkWell(
      onTap: () => _copy(token),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: accent.withValues(alpha: 0.08),
              ),
              child: Text(
                token,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12.5,
                  fontFamily: 'monospace',
                  color: accent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                desc,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              copied ? LucideIcons.check : LucideIcons.copy,
              size: 15,
              color: copied ? accent : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// A small outlined tag chip used on prompt cards.
class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 10.5,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
