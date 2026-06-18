import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/application/mcp_servers_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';

/// The human-readable label for an MCP server [type], ported from the web
/// `getServerTypeLabel` / `serverTypes` i18n. Shared by the settings list rows
/// and this detail page.
String mcpServerTypeLabel(McpServerType type) => switch (type) {
  McpServerType.sse => '服务器发送事件 (sse)',
  McpServerType.streamableHttp => '可流式传输的 HTTP (streamableHttp)',
  McpServerType.httpStream => 'HTTP Stream (已废弃)',
  McpServerType.stdio => '标准输入/输出 (stdio)',
  McpServerType.inMemory => '内存服务器',
};

/// The "MCP 服务器详情" page (设置 → MCP 服务器 → a server), a port of
/// `src/pages/Settings/MCPServerDetail.tsx`.
///
/// Edits the persisted [McpServer] config — 基本信息 (启用 / 名称 / 类型 /
/// URL·命令·参数 / 描述 / 超时) plus the 高级设置 请求头 / 环境变量 key-value
/// editors — committing through [McpServers.edit]. Tool / prompt / resource
/// discovery and 测试连接 need a live connection (the request layer, Phase C),
/// so the 可用工具 section and 测试 button surface 「即将支持」 instead of faking it.
class McpServerDetailPage extends ConsumerStatefulWidget {
  const McpServerDetailPage({required this.serverId, super.key});

  final String serverId;

  @override
  ConsumerState<McpServerDetailPage> createState() =>
      _McpServerDetailPageState();
}

class _McpServerDetailPageState extends ConsumerState<McpServerDetailPage> {
  McpServer? _server;

  final _name = TextEditingController();
  final _baseUrl = TextEditingController();
  final _command = TextEditingController();
  final _args = TextEditingController();
  final _description = TextEditingController();
  final _timeout = TextEditingController();

  McpServerType _type = McpServerType.sse;
  bool _isActive = false;
  List<_KvPair> _headers = const [];
  List<_KvPair> _env = const [];

  @override
  void initState() {
    super.initState();
    final found = _find(
      ref.read(mcpServersProvider).asData?.value ?? const <McpServer>[],
      widget.serverId,
    );
    if (found != null) _hydrate(found);
  }

  void _hydrate(McpServer server) {
    _server = server;
    _name.text = server.name;
    _baseUrl.text = server.baseUrl ?? '';
    _command.text = server.command ?? '';
    _args.text = (server.args ?? const <String>[]).join(' ');
    _description.text = server.description ?? '';
    _timeout.text = (server.timeout ?? 60).toString();
    _type = server.type;
    _isActive = server.isActive;
    _headers = _pairsFrom(server.headers);
    _env = _pairsFrom(server.env);
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _command.dispose();
    _args.dispose();
    _description.dispose();
    _timeout.dispose();
    for (final pair in [..._headers, ..._env]) {
      pair.dispose();
    }
    super.dispose();
  }

  static McpServer? _find(List<McpServer> servers, String id) {
    for (final server in servers) {
      if (server.id == id) return server;
    }
    return null;
  }

  static List<_KvPair> _pairsFrom(Map<String, String>? map) =>
      (map ?? const <String, String>{}).entries
          .map((e) => _KvPair(key: e.key, value: e.value))
          .toList();

  static Map<String, String> _mapFrom(List<_KvPair> pairs) => {
    for (final pair in pairs)
      if (pair.key.text.trim().isNotEmpty)
        pair.key.text.trim(): pair.value.text,
  };

  bool get _isHttp =>
      _type == McpServerType.sse ||
      _type == McpServerType.streamableHttp ||
      _type == McpServerType.httpStream;

  Future<void> _save() async {
    final base = _server;
    if (base == null) return;
    final argsText = _args.text.trim();
    final updated = base.copyWith(
      name: _name.text.trim(),
      type: _type,
      isActive: _isActive,
      baseUrl: _isHttp ? _baseUrl.text.trim() : base.baseUrl,
      command: _type == McpServerType.stdio
          ? _command.text.trim()
          : base.command,
      args: _type == McpServerType.stdio
          ? (argsText.isEmpty ? <String>[] : argsText.split(RegExp(r'\s+')))
          : base.args,
      description: _description.text.trim(),
      timeout: int.tryParse(_timeout.text.trim()) ?? 60,
      headers: _mapFrom(_headers),
      env: _mapFrom(_env),
    );
    await ref.read(mcpServersProvider.notifier).edit(updated);
    if (!mounted) return;
    setState(() => _server = updated);
    _toast('保存成功');
  }

  Future<void> _delete() async {
    final base = _server;
    if (base == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('确定要删除服务器 "${base.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await ref.read(mcpServersProvider.notifier).remove(base.id);
    if (!mounted) return;
    context.canPop() ? context.pop() : context.go(AppRouter.mcpServerPath);
  }

  void _toast(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final server = _server;
    if (server == null) {
      return Scaffold(
        appBar: ModelSettingsAppBar(
          title: 'MCP 服务器详情',
          onBack: () => context.canPop()
              ? context.pop()
              : context.go(AppRouter.mcpServerPath),
        ),
        body: const Center(child: Text('未找到该服务器')),
      );
    }

    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: 'MCP 服务器详情',
        onBack: () => context.canPop()
            ? context.pop()
            : context.go(AppRouter.mcpServerPath),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ModelTonalButton(
              label: '保存',
              icon: LucideIcons.save,
              onPressed: _save,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _basicInfoCard(context),
          const SizedBox(height: 16),
          _advancedCard(context),
          const SizedBox(height: 16),
          _toolsCard(context),
          const SizedBox(height: 16),
          _dangerCard(context),
        ],
      ),
    );
  }

  Widget _basicInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    return ModelSettingsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, LucideIcons.settings, '基本信息'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '启用服务器',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                ),
              ),
              if (_isActive)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: _StatusChip(),
                ),
              CustomSwitch(
                value: _isActive,
                onChanged: (v) async {
                  setState(() => _isActive = v);
                  await ref
                      .read(mcpServersProvider.notifier)
                      .toggleActive(_server!.id, isActive: v);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
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
                <McpServerType>[
                  McpServerType.sse,
                  McpServerType.streamableHttp,
                  McpServerType.inMemory,
                  McpServerType.stdio,
                  // httpStream is deprecated (no longer offered for new servers),
                  // but keep it selectable when an existing config already uses it.
                  if (_type == McpServerType.httpStream)
                    McpServerType.httpStream,
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
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '描述',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _timeout,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '超时时间（秒）',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _advancedCard(BuildContext context) {
    final theme = Theme.of(context);
    return ModelSettingsCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Icon(
                LucideIcons.wrench,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '高级设置',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          children: [
            _kvEditor(
              context,
              label: '自定义请求头',
              pairs: _headers,
              keyHint: '如 Authorization',
              valueHint: '如 Bearer xxxxxx',
              addLabel: '添加请求头',
              onChanged: (next) => setState(() => _headers = next),
            ),
            const SizedBox(height: 16),
            _kvEditor(
              context,
              label: '环境变量',
              pairs: _env,
              keyHint: '如 API_KEY',
              valueHint: '如 your-api-key',
              addLabel: '添加环境变量',
              onChanged: (next) => setState(() => _env = next),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kvEditor(
    BuildContext context, {
    required String label,
    required List<_KvPair> pairs,
    required String keyHint,
    required String valueHint,
    required String addLabel,
    required ValueChanged<List<_KvPair>> onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        for (final pair in pairs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pair.key,
                    decoration: InputDecoration(
                      hintText: keyHint,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: pair.value,
                    decoration: InputDecoration(
                      hintText: valueHint,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    LucideIcons.trash2,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: () {
                    pair.dispose();
                    onChanged(pairs.where((p) => p != pair).toList());
                  },
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => onChanged([...pairs, _KvPair()]),
            icon: const Icon(LucideIcons.plus, size: 16),
            label: Text(addLabel),
          ),
        ),
      ],
    );
  }

  Widget _toolsCard(BuildContext context) {
    final theme = Theme.of(context);
    return ModelSettingsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionTitle(context, LucideIcons.blocks, '可用工具'),
              ),
              OutlinedButton.icon(
                onPressed: () => _toast('即将支持'),
                icon: const Icon(LucideIcons.plug, size: 16),
                label: const Text('测试'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '连接服务器后即可发现可用工具（即将支持）',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dangerCard(BuildContext context) {
    final theme = Theme.of(context);
    return ModelSettingsCard(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _delete,
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(
              color: theme.colorScheme.error.withValues(alpha: 0.5),
            ),
          ),
          icon: const Icon(LucideIcons.trash2, size: 18),
          label: const Text('删除服务器'),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, IconData icon, String title) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// An outlined 运行中 status chip (port of the detail page's success `Chip`).
class _StatusChip extends StatelessWidget {
  const _StatusChip();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF22C55E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: const Text(
        '运行中',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// A live, editable header / env pair backing the 高级设置 key-value editors.
class _KvPair {
  _KvPair({String key = '', String value = ''})
    : key = TextEditingController(text: key),
      value = TextEditingController(text: value);

  final TextEditingController key;
  final TextEditingController value;

  void dispose() {
    key.dispose();
    value.dispose();
  }
}
