import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// The "MCP 服务器" settings page (提示词与工具 → this page), a UI-only port of
/// the original `src/pages/Settings/MCPServerSettings.tsx`.
///
/// Reproduces the original's three-tab layout (外部服务器 / 内置工具 / 智能助手),
/// the empty-state card, the import quick-action and the built-in template list
/// rows (avatar + type chip + description + tags + 添加 button). The whole MCP
/// subsystem (connecting servers, persistence, tool discovery) is **not** ported
/// — every action (添加 / 导入 / 启用) surfaces a 「即将支持」 hint instead of
/// faking success, matching the project's UI-complete-but-unwired convention.
///
/// The built-in / assistant templates are the original's static
/// `BUILTIN_MCP_SERVERS` catalog (`src/shared/config/builtinMCPServers.ts`),
/// lifted to const data here the same way [kSettingsGroups] lifts the hub — no
/// service layer, no fabricated runtime state.
class McpServerSettingsPage extends StatefulWidget {
  const McpServerSettingsPage({super.key});

  @override
  State<McpServerSettingsPage> createState() => _McpServerSettingsPageState();
}

class _McpServerSettingsPageState extends State<McpServerSettingsPage>
    with SingleTickerProviderStateMixin {
  static const String _title = 'MCP 服务器';

  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  )..addListener(_onTabChanged);

  void _onTabChanged() {
    // The original only shows the 添加 app-bar action on the 外部服务器 tab.
    if (!_tabController.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onExternalTab = _tabController.index == 0;

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
          if (onExternalTab)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ModelTonalButton(
                label: '添加',
                icon: LucideIcons.plus,
                onPressed: () => _comingSoon(context),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _TabBarHeader(controller: _tabController),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [_ExternalTab(), _BuiltinTab(), _AssistantTab()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the project's standard 「即将支持」 toast (`message_toolbar` convention).
void _comingSoon(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)
    ?..clearSnackBars()
    ..showSnackBar(
      const SnackBar(content: Text('即将支持'), duration: Duration(seconds: 2)),
    );
}

/// The full-width tab strip below the app bar (icon + label, 1px bottom
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
          _IconTab(icon: LucideIcons.server, label: '外部服务器'),
          _IconTab(icon: LucideIcons.wrench, label: '内置工具'),
          _IconTab(icon: LucideIcons.bot, label: '智能助手'),
        ],
      ),
    );
  }
}

/// A 42px tab with the glyph to the left of the label (`iconPosition="start"`).
class _IconTab extends StatelessWidget {
  const _IconTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 42,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

// ─────────────────────────── Tab 0: 外部服务器 ───────────────────────────

/// The 外部服务器 tab. With no MCP backend there are genuinely no configured
/// servers, so it renders the original's empty state plus the 导入配置 quick
/// action; both buttons surface 「即将支持」.
class _ExternalTab extends StatelessWidget {
  const _ExternalTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        const _EmptyState(),
        const SizedBox(height: 16),
        _Card(
          padding: EdgeInsets.zero,
          child: _ServerRowTile(
            icon: LucideIcons.plus,
            iconColor: const Color(0xFF06B6D4),
            title: '导入配置',
            description: '从 JSON 文件导入 MCP 服务器配置',
            onTap: () => _comingSoon(context),
          ),
        ),
      ],
    );
  }
}

/// The original empty-state `Paper`: a centered server glyph, title, hint and
/// the 添加服务器 / 导入配置 button pair.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        children: [
          const Icon(LucideIcons.server, size: 48, color: Color(0xFF2196F3)),
          const SizedBox(height: 16),
          Text(
            '还没有配置 MCP 服务器',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'MCP 服务器可以为 AI 提供额外的工具和功能',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => _comingSoon(context),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('添加服务器'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => _comingSoon(context),
                child: const Text('导入配置'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Tab 1: 内置工具 ───────────────────────────

class _BuiltinTab extends StatelessWidget {
  const _BuiltinTab();

  @override
  Widget build(BuildContext context) {
    return const _TemplateList(
      title: '添加内置 MCP 服务器',
      description: '选择并启用内置工具，无需配置即可使用',
      templates: _kBuiltinTools,
    );
  }
}

// ─────────────────────────── Tab 2: 智能助手 ───────────────────────────

class _AssistantTab extends StatelessWidget {
  const _AssistantTab();

  @override
  Widget build(BuildContext context) {
    return const _TemplateList(
      title: '智能助手',
      description: 'AI 智能助手可以在对话中直接管理应用设置，敏感操作需要用户确认',
      templates: _kAssistantTemplates,
    );
  }
}

/// A single card holding a header (title + description), a divider and the
/// template rows — the shared layout of the 内置工具 / 智能助手 tabs.
class _TemplateList extends StatelessWidget {
  const _TemplateList({
    required this.title,
    required this.description,
    required this.templates,
  });

  final String title;
  final String description;
  final List<_McpTemplate> templates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _Card(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),
              for (var i = 0; i < templates.length; i++) ...[
                _TemplateRow(template: templates[i]),
                if (i < templates.length - 1)
                  Divider(height: 1, indent: 16, color: theme.dividerColor),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A built-in template row: tinted avatar, name + 内存服务器 type chip, the
/// 2-line description, tag chips and the green 添加 button (→ 「即将支持」).
class _TemplateRow extends StatelessWidget {
  const _TemplateRow({required this.template});

  final _McpTemplate template;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = template.isAssistant
        ? const Color(0xFF8B5CF6)
        : const Color(0xFF4CAF50);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              template.isAssistant ? LucideIcons.bot : LucideIcons.cpu,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      template.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _Chip(label: '内存服务器', color: color, filled: true),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  template.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (template.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in template.tags)
                        _Chip(
                          label: tag,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _AddButton(onPressed: () => _comingSoon(context)),
          ),
        ],
      ),
    );
  }
}

/// The green contained 添加 button from `BuiltinServerListItem`.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF10B981),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Text(
            '添加',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// A simple list tile inside a card (the 导入配置 quick action): tinted avatar,
/// title + description and a tap target.
class _ServerRowTile extends StatelessWidget {
  const _ServerRowTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small chip: a filled low-alpha tint for the type label, or an outlined
/// neutral pill for tags.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, this.filled = false});

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(8),
        border: filled ? null : Border.all(color: theme.dividerColor),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: filled ? 11 : 10.5,
          fontWeight: filled ? FontWeight.w500 : FontWeight.w400,
          color: filled ? color : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The original `cardStyle`: 24px radius, 1px divider border, surface fill, no
/// shadow (matches `ChatInterfaceSettings` cards).
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: child,
    );
  }
}

/// A built-in MCP template (UI-only mirror of `BUILTIN_MCP_SERVERS`).
@immutable
class _McpTemplate {
  const _McpTemplate({
    required this.name,
    required this.description,
    required this.tags,
    this.isAssistant = false,
  });

  final String name;
  final String description;
  final List<String> tags;
  final bool isAssistant;
}

/// The original 内置工具 (`category: 'builtin'`) templates, verbatim from
/// `src/shared/config/builtinMCPServers.ts`.
const List<_McpTemplate> _kBuiltinTools = [
  _McpTemplate(
    name: '@aether/time',
    description: '获取当前时间和日期，支持多种格式（本地化、ISO 8601、时间戳）和时区设置',
    tags: ['时间', '日期', '工具'],
  ),
  _McpTemplate(
    name: '@aether/fetch',
    description: '获取网页内容，支持 HTML、JSON 和纯文本格式，可自定义请求头',
    tags: ['网页', '抓取', 'HTTP', 'API'],
  ),
  _McpTemplate(
    name: '@aether/calculator',
    description: '高级计算器，支持基本运算、科学计算、进制转换、单位转换和统计计算',
    tags: ['计算', '数学', '转换', '统计', '工具'],
  ),
  _McpTemplate(
    name: '@aether/calendar',
    description: '日历管理工具，支持创建、查询、修改和删除日历事件，查看日历列表',
    tags: ['日历', '事件', '提醒', '时间管理', '工具'],
  ),
  _McpTemplate(
    name: '@aether/alarm',
    description: '闹钟和提醒工具，支持设置单次或重复闹钟，管理所有提醒',
    tags: ['闹钟', '提醒', '通知', '时间管理', '工具'],
  ),
  _McpTemplate(
    name: '@aether/metaso-search',
    description: '秘塔AI官方API，提供网页搜索、内容阅读器和AI智能对话。支持5种知识范围、3种模型、引用来源和关键要点提取',
    tags: ['搜索', 'AI', '对话', '阅读器', '工具'],
  ),
  _McpTemplate(
    name: '@aether/file-editor',
    description: 'AI 文件编辑工具，支持读取、写入、插入、替换、应用 diff 等操作。可用于工作区和笔记文件的编辑。',
    tags: ['文件', '编辑', 'AI', '工作区', '笔记', '工具'],
  ),
  _McpTemplate(
    name: '@aether/dex-editor',
    description:
        'DEX 文件编辑工具，让 AI 可以浏览、搜索、查看和修改 APK 中的 Smali 代码。支持列出类、获取方法、搜索代码、编辑保存和签名。',
    tags: ['DEX', 'Smali', 'APK', '逆向', '编辑', 'Android', '工具'],
  ),
  _McpTemplate(
    name: '@aether/grok-search',
    description:
        'Grok AI 搜索工具，支持任何 OpenAI 兼容 API 进行联网搜索。支持多维度搜索（自动拆分复杂查询并行搜索）、智能重试、思考内容过滤',
    tags: ['搜索', 'AI', '联网', '工具'],
  ),
  _McpTemplate(
    name: '@aether/searxng',
    description:
        '基于自部署 SearXNG 的元搜索引擎，聚合 Google、Bing、DuckDuckGo 等 70+ 搜索引擎。支持互联网搜索和网页内容抓取',
    tags: ['搜索', '网页', '抓取', '工具'],
  ),
];

/// The original 智能助手 (`category: 'assistant'`) templates.
const List<_McpTemplate> _kAssistantTemplates = [
  _McpTemplate(
    name: '@aether/settings',
    description: '智能设置助手，让 AI 管理知识库（创建、编辑、删除、搜索）和应用设置。支持自然语言操作，危险操作需用户确认。',
    tags: ['设置', '知识库', '管理', 'AI', '工具'],
    isAssistant: true,
  ),
];
