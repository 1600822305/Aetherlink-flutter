import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/application/mcp_servers_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/mcp_server_detail_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/config/builtin_mcp_servers.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';

/// The "MCP 服务器" settings page (提示词与工具 → this page), a port of the
/// original `src/pages/Settings/MCPServerSettings.tsx`.
///
/// Reproduces the original's three-tab layout (外部服务器 / 内置工具 / 智能助手)
/// and wires it to the persisted [McpServers] store (Phase A): external servers
/// can be added / imported (JSON) / toggled / opened for editing, and built-in /
/// assistant templates can be added & toggled. Opening or running a connection
/// (tool discovery, execution, chat integration) needs the request layer
/// (Phase C); until then the 测试 / 工具发现 surfaces stay 「即将支持」.
class McpServerSettingsPage extends ConsumerStatefulWidget {
  const McpServerSettingsPage({super.key});

  @override
  ConsumerState<McpServerSettingsPage> createState() =>
      _McpServerSettingsPageState();
}

class _McpServerSettingsPageState extends ConsumerState<McpServerSettingsPage>
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
                onPressed: () => _openAddServer(context, ref),
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

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..clearSnackBars()
    ..showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
}

/// Opens the 添加 MCP 服务器 form and, on confirm, validates and persists the
/// new external server (port of `handleAddServer`).
Future<void> _openAddServer(BuildContext context, WidgetRef ref) async {
  final draft = await showDialog<McpServer>(
    context: context,
    builder: (_) => const _AddServerDialog(),
  );
  if (draft == null) return;
  await ref.read(mcpServersProvider.notifier).add(draft);
  if (context.mounted) _toast(context, '服务器添加成功');
}

/// Opens the 导入 MCP 服务器配置 dialog and, on confirm, imports the JSON,
/// reporting the count / partial failures (port of `handleImportJson`).
Future<void> _openImport(BuildContext context, WidgetRef ref) async {
  final json = await showDialog<String>(
    context: context,
    builder: (_) => const _ImportJsonDialog(),
  );
  if (json == null) return;
  try {
    final result = await ref
        .read(mcpServersProvider.notifier)
        .importFromJson(json);
    if (!context.mounted) return;
    if (result.errors.isEmpty) {
      _toast(context, '成功导入 ${result.imported} 个服务器');
    } else {
      _toast(
        context,
        '成功导入 ${result.imported} 个服务器，${result.errors.length} 个失败',
      );
    }
  } on FormatException catch (e) {
    if (context.mounted) _toast(context, '导入失败：${e.message}');
  } catch (e) {
    if (context.mounted) _toast(context, '导入失败：$e');
  }
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

/// The 外部服务器 tab: the configured external servers (everything not in the
/// built-in / assistant catalog) plus the 导入配置 quick action. Empty until the
/// user adds or imports one.
class _ExternalTab extends ConsumerWidget {
  const _ExternalTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers =
        ref.watch(mcpServersProvider).asData?.value ?? const <McpServer>[];
    // The 外部服务器 tab is every configured server whose name is not in the
    // built-in catalog (port of `externalServers = servers.filter(s =>
    // !isBuiltinServer(s.name))`); added built-ins live under their own tabs.
    final external = servers
        .where((s) => !isBuiltinMcpServerName(s.name))
        .toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (external.isEmpty)
          const _EmptyState()
        else
          _Card(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < external.length; i++) ...[
                  _ExternalServerRow(server: external[i]),
                  if (i < external.length - 1)
                    Divider(
                      height: 1,
                      indent: 16,
                      color: Theme.of(context).dividerColor,
                    ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),
        _Card(
          padding: EdgeInsets.zero,
          child: _ServerRowTile(
            icon: LucideIcons.import,
            iconColor: const Color(0xFF06B6D4),
            title: '导入配置',
            description: '从 JSON 文件导入 MCP 服务器配置',
            onTap: () => _openImport(context, ref),
          ),
        ),
      ],
    );
  }
}

/// The original empty-state `Paper`: a centered server glyph, title, hint and
/// the 添加服务器 / 导入配置 button pair.
class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                onPressed: () => _openAddServer(context, ref),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('添加服务器'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => _openImport(context, ref),
                child: const Text('导入配置'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A configured external server row: tinted avatar, name + type chip + 运行中
/// chip, the active switch, and a tap target opening the detail / edit page.
class _ExternalServerRow extends ConsumerWidget {
  const _ExternalServerRow({required this.server});

  final McpServer server;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    const color = Color(0xFF2196F3);
    return InkWell(
      onTap: () => context.push('${AppRouter.mcpServerPath}/${server.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(LucideIcons.server, size: 20, color: color),
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
                        server.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _Chip(
                        label: mcpServerTypeLabel(server.type),
                        color: color,
                        filled: true,
                      ),
                    ],
                  ),
                  if ((server.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      server.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            CustomSwitch(
              value: server.isActive,
              onChanged: (v) => ref
                  .read(mcpServersProvider.notifier)
                  .toggleActive(server.id, isActive: v),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Tab 1: 内置工具 ───────────────────────────

class _BuiltinTab extends StatelessWidget {
  const _BuiltinTab();

  @override
  Widget build(BuildContext context) {
    return _TemplateList(
      title: '添加内置 MCP 服务器',
      description: '选择并启用内置工具，无需配置即可使用',
      templates: kBuiltinMcpServers
          .where((s) => s.category == McpServerCategory.builtin)
          .toList(),
    );
  }
}

// ─────────────────────────── Tab 2: 智能助手 ───────────────────────────

class _AssistantTab extends StatelessWidget {
  const _AssistantTab();

  @override
  Widget build(BuildContext context) {
    return _TemplateList(
      title: '智能助手',
      description: 'AI 智能助手可以在对话中直接管理应用设置，敏感操作需要用户确认',
      templates: kBuiltinMcpServers
          .where((s) => s.category == McpServerCategory.assistant)
          .toList(),
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
  final List<McpServer> templates;

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
/// 2-line description, tag chips and either the green 添加 button (not yet added)
/// or — once added — a 运行中 chip, an active switch and a tap target to the
/// detail page (port of `BuiltinServerListItem`).
class _TemplateRow extends ConsumerWidget {
  const _TemplateRow({required this.template});

  final McpServer template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAssistant = template.category == McpServerCategory.assistant;
    final color = isAssistant
        ? const Color(0xFF8B5CF6)
        : const Color(0xFF4CAF50);

    final servers =
        ref.watch(mcpServersProvider).asData?.value ?? const <McpServer>[];
    final added = _firstWhereOrNull(servers, (s) => s.name == template.name);
    final tags = template.tags ?? const <String>[];

    final row = Padding(
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
              isAssistant ? LucideIcons.bot : LucideIcons.cpu,
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
                    if (added?.isActive ?? false)
                      const _Chip(label: '运行中', color: Color(0xFF22C55E)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  template.description ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in tags)
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
          if (added == null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _AddButton(
                onPressed: () async {
                  await ref
                      .read(mcpServersProvider.notifier)
                      .addBuiltin(template);
                  if (context.mounted) {
                    _toast(context, '内置服务器 ${template.name} 添加成功');
                  }
                },
              ),
            )
          else
            CustomSwitch(
              value: added.isActive,
              onChanged: (v) => ref
                  .read(mcpServersProvider.notifier)
                  .toggleActive(added.id, isActive: v),
            ),
        ],
      ),
    );

    if (added == null) return row;
    return InkWell(
      onTap: () => context.push('${AppRouter.mcpServerPath}/${added.id}'),
      child: row,
    );
  }
}

T? _firstWhereOrNull<T>(List<T> list, bool Function(T) test) {
  for (final item in list) {
    if (test(item)) return item;
  }
  return null;
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

/// The 添加 MCP 服务器 form (port of `AddServerDialog`): name + type with
/// type-specific URL / 命令 / 参数 fields + description. 添加 stays disabled until
/// the required fields for the chosen type are filled.
class _AddServerDialog extends StatefulWidget {
  const _AddServerDialog();

  @override
  State<_AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<_AddServerDialog> {
  final _name = TextEditingController();
  final _baseUrl = TextEditingController();
  final _command = TextEditingController();
  final _args = TextEditingController();
  final _description = TextEditingController();
  McpServerType _type = McpServerType.sse;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _baseUrl, _command]) {
      c.addListener(_onChanged);
    }
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _command.dispose();
    _args.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _isHttp =>
      _type == McpServerType.sse ||
      _type == McpServerType.streamableHttp ||
      _type == McpServerType.httpStream;

  bool get _canAdd {
    if (_name.text.trim().isEmpty) return false;
    if (_isHttp) return _baseUrl.text.trim().isNotEmpty;
    if (_type == McpServerType.stdio) return _command.text.trim().isNotEmpty;
    return true;
  }

  void _submit() {
    if (!_canAdd) return;
    final argsText = _args.text.trim();
    Navigator.of(context).pop(
      McpServer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        type: _type,
        description: _description.text.trim(),
        baseUrl: _isHttp ? _baseUrl.text.trim() : null,
        command: _type == McpServerType.stdio ? _command.text.trim() : null,
        args: _type == McpServerType.stdio && argsText.isNotEmpty
            ? argsText.split(RegExp(r'\s+'))
            : null,
        headers: const {},
        env: const {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加 MCP 服务器'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '服务器名称',
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<McpServerType>(
              initialValue: _type,
              isDense: true,
              decoration: const InputDecoration(
                labelText: '服务器类型',
                isDense: true,
              ),
              items:
                  const [
                    McpServerType.sse,
                    McpServerType.streamableHttp,
                    McpServerType.inMemory,
                    McpServerType.stdio,
                  ].map((t) {
                    return DropdownMenuItem<McpServerType>(
                      value: t,
                      child: Text(mcpServerTypeLabel(t)),
                    );
                  }).toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            if (_isHttp) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _baseUrl,
                decoration: const InputDecoration(
                  labelText: '服务器 URL',
                  hintText: 'https://example.com/mcp',
                  isDense: true,
                ),
              ),
            ],
            if (_type == McpServerType.stdio) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _command,
                decoration: const InputDecoration(
                  labelText: '命令',
                  hintText: 'npx, node, python, uvx...',
                  helperText: '要执行的命令程序，如 npx、node、python 等',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _args,
                decoration: const InputDecoration(
                  labelText: '命令参数',
                  hintText: '-y @anthropic/mcp-server-fetch',
                  helperText: '命令参数，用空格分隔',
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '描述（可选）',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _canAdd ? _submit : null,
          child: const Text('添加'),
        ),
      ],
    );
  }
}

/// The 导入 MCP 服务器配置 dialog (port of `ImportJsonDialog`): a format example
/// plus a multiline JSON field; 导入 disabled until non-blank.
class _ImportJsonDialog extends StatefulWidget {
  const _ImportJsonDialog();

  @override
  State<_ImportJsonDialog> createState() => _ImportJsonDialogState();
}

class _ImportJsonDialogState extends State<_ImportJsonDialog> {
  final _json = TextEditingController();

  static const String _example = '''{
  "mcpServers": {
    "fetch": {
      "type": "sse",
      "url": "https://example.com/sse"
    }
  }
}''';

  @override
  void initState() {
    super.initState();
    _json.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _json.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('导入 MCP 服务器配置'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '粘贴包含 MCP 服务器配置的 JSON 内容。支持的格式示例：',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _example,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _json,
              autofocus: true,
              minLines: 8,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'JSON 配置',
                hintText: '在此粘贴 JSON 配置...',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _json.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_json.text),
          child: const Text('导入'),
        ),
      ],
    );
  }
}
