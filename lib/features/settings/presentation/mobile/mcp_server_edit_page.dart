// MCP 服务器添加 / 编辑独立页：替代原先的 AlertDialog 表单，外部服务器与
// stdio（移动端）两个入口复用本页 —— 外部入口可选类型（SSE / HTTP / 内存 /
// stdio），stdio 入口锁定类型并带运行环境（工作区）/ 环境变量 / 工作目录等
// 字段。页面风格对齐设置页：顶栏返回 + 标题 + 右侧提交按钮，正文单卡片
// 紧凑表单。确认后通过 Navigator.pop 返回 McpServer 草稿，由调用方持久化。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/workspace_access.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/mcp_server_detail_page.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/widgets/app_select_field.dart';

/// 打开添加 / 编辑页；[stdioOnly] 为 true 时锁定 stdio 类型（stdio tab 入口）。
/// 返回用户确认的 McpServer 草稿，取消返回 null。
Future<McpServer?> showMcpServerEditPage(
  BuildContext context, {
  McpServer? initial,
  bool stdioOnly = false,
}) {
  return Navigator.of(context).push<McpServer>(
    MaterialPageRoute(
      builder: (_) => McpServerEditPage(initial: initial, stdioOnly: stdioOnly),
    ),
  );
}

class McpServerEditPage extends ConsumerStatefulWidget {
  const McpServerEditPage({super.key, this.initial, this.stdioOnly = false});

  final McpServer? initial;
  final bool stdioOnly;

  @override
  ConsumerState<McpServerEditPage> createState() => _McpServerEditPageState();
}

class _McpServerEditPageState extends ConsumerState<McpServerEditPage> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _baseUrl = TextEditingController(text: widget.initial?.baseUrl);
  late final _command = TextEditingController(text: widget.initial?.command);
  late final _args = TextEditingController(
    text: widget.initial?.args?.join(' '),
  );
  late final _env = TextEditingController(
    text: widget.initial?.env?.entries
        .map((e) => '${e.key}=${e.value}')
        .join('\n'),
  );
  late final _cwd = TextEditingController(text: widget.initial?.cwd);
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );
  late McpServerType _type =
      widget.initial?.type ??
      (widget.stdioOnly ? McpServerType.stdio : McpServerType.sse);
  late String? _workspaceId = widget.initial?.workspaceId;

  bool get _isEdit => widget.initial != null;
  bool get _isStdio => _type == McpServerType.stdio;
  bool get _isHttp =>
      _type == McpServerType.sse ||
      _type == McpServerType.streamableHttp ||
      _type == McpServerType.httpStream;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _baseUrl, _command]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _baseUrl,
      _command,
      _args,
      _env,
      _cwd,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canSubmit {
    if (_name.text.trim().isEmpty) return false;
    if (_isHttp) return _baseUrl.text.trim().isNotEmpty;
    if (_isStdio) {
      if (_command.text.trim().isEmpty) return false;
      // stdio tab 入口要求选运行环境；外部入口保持旧对话框的宽松校验。
      if (widget.stdioOnly && _workspaceId == null) return false;
    }
    return true;
  }

  Map<String, String>? _parseEnv() {
    final env = <String, String>{};
    for (final raw in _env.text.split('\n')) {
      final line = raw.trim();
      final idx = line.indexOf('=');
      if (idx <= 0) continue;
      env[line.substring(0, idx).trim()] = line.substring(idx + 1);
    }
    return env.isEmpty ? null : env;
  }

  void _submit() {
    if (!_canSubmit) return;
    final argsText = _args.text.trim();
    final base =
        widget.initial ??
        McpServer(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: '',
          type: _type,
          headers: const {},
        );
    Navigator.of(context).pop(
      base.copyWith(
        name: _name.text.trim(),
        type: _type,
        description: _description.text.trim(),
        baseUrl: _isHttp ? _baseUrl.text.trim() : null,
        command: _isStdio ? _command.text.trim() : null,
        args: _isStdio && argsText.isNotEmpty
            ? argsText.split(RegExp(r'\s+'))
            : null,
        env: _isStdio ? _parseEnv() : null,
        cwd: _isStdio && _cwd.text.trim().isNotEmpty ? _cwd.text.trim() : null,
        workspaceId: _isStdio ? _workspaceId : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = _isEdit
        ? (_isStdio ? '编辑 stdio 服务器' : '编辑 MCP 服务器')
        : (widget.stdioOnly ? '添加 stdio 服务器' : '添加 MCP 服务器');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
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
            color: cs.primary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _canSubmit ? _submit : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                _isEdit ? '保存' : '添加',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _name,
                  autofocus: !_isEdit,
                  decoration: const InputDecoration(
                    labelText: '服务器名称',
                    isDense: true,
                  ),
                ),
                if (!widget.stdioOnly && !_isEdit) ...[
                  const SizedBox(height: 14),
                  AppSelectField<McpServerType>(
                    label: '服务器类型',
                    value: _type,
                    options: [
                      for (final t in const [
                        McpServerType.sse,
                        McpServerType.streamableHttp,
                        McpServerType.inMemory,
                        McpServerType.stdio,
                      ])
                        AppSelectOption<McpServerType>(
                          value: t,
                          label: mcpServerTypeLabel(t),
                        ),
                    ],
                    onChanged: (v) => setState(() => _type = v),
                  ),
                ],
                if (_isHttp) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _baseUrl,
                    decoration: const InputDecoration(
                      labelText: '服务器 URL',
                      hintText: 'https://example.com/mcp',
                      isDense: true,
                    ),
                  ),
                ],
                if (_isStdio) ...[
                  const SizedBox(height: 14),
                  _WorkspaceSelect(
                    value: _workspaceId,
                    onChanged: (v) => setState(() => _workspaceId = v),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _command,
                    decoration: const InputDecoration(
                      labelText: '命令',
                      hintText: 'npx, node, python, uvx...',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _args,
                    decoration: const InputDecoration(
                      labelText: '命令参数',
                      hintText: '-y @modelcontextprotocol/server-filesystem',
                      helperText: '用空格分隔',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _env,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: '环境变量（可选）',
                      hintText: 'API_KEY=xxx\n每行一条 KEY=VALUE',
                      alignLabelWithHint: true,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _cwd,
                    decoration: const InputDecoration(
                      labelText: '工作目录（可选）',
                      hintText: '/root/project',
                      isDense: true,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '描述（可选）',
                    alignLabelWithHint: true,
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// stdio 的运行环境（工作区）选择：只列可执行后端（proot / SSH）。
class _WorkspaceSelect extends ConsumerWidget {
  const _WorkspaceSelect({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaces = ref.watch(recentWorkspacesViewProvider);
    final selectable = workspaces
        .where((w) => w.backendType != WorkspaceBackendType.localSaf)
        .toList();
    return AppSelectField<String?>(
      label: '运行环境（工作区）',
      value: value,
      options: [
        if (selectable.isEmpty)
          const AppSelectOption<String?>(
            value: null,
            label: '无可用工作区（需 proot 容器 / SSH）',
          ),
        for (final w in selectable)
          AppSelectOption<String?>(value: w.id, label: w.name),
      ],
      onChanged: onChanged,
    );
  }
}
