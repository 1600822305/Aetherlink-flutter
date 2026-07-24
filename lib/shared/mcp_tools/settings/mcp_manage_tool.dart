import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/mcp_servers_access.dart';
import 'package:aetherlink_flutter/features/workspace/application/primary_terminal_store.dart';
import 'package:aetherlink_flutter/features/workspace/domain/primary_terminal.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/shared/config/builtin_mcp_servers.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

/// `mcp_manage`：让模型自助管理外部 MCP 服务器（全局配置，与设置页
/// 同一份存储）。单一工具 + 最小 schema，详细参数格式与操作流程放在
/// 内置技能「MCP 服务器管理」里按需 read_skill 加载（渐进披露，
/// 不占常驻上下文）。写操作（add/remove/toggle）走 HITL 审批。
const String kMcpManageToolName = 'mcp_manage';

const McpToolDefinition kMcpManageToolDefinition = McpToolDefinition(
  name: kMcpManageToolName,
  description:
      '管理外部 MCP 服务器（全局配置）：list 列出 / add 添加 / '
      'remove 删除 / toggle 启停 / workspaces 列出 stdio 可用运行环境。'
      'add 的 config 格式与完整流程见内置技能'
      '「MCP 服务器管理」（先 read_skill 再调用）。',
  inputSchema: {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['list', 'add', 'remove', 'toggle', 'workspaces'],
        'description': '操作类型',
      },
      'name': {
        'type': 'string',
        'description': 'add 必填：服务器名称；remove/toggle 可用名称或 id 定位',
      },
      'config': {
        'type': 'object',
        'description':
            'add 必填：服务器配置（Claude Desktop mcpServers 条目'
            '格式，详见技能）',
      },
      'id': {'type': 'string', 'description': 'remove/toggle 定位用服务器 id'},
      'workspace': {
        'type': 'string',
        'description':
            'add stdio 可选：运行环境工作区（id 或名称，用 '
            'workspaces 查看）；缺省自动选（主终端后端优先）',
      },
      'enabled': {
        'type': 'boolean',
        'description':
            'toggle 必填：是否启用；add 时可选（默认 true，'
            '添加后立即启用）',
      },
    },
    'required': ['action'],
  },
);

/// 除只读的 list / workspaces 外都会改配置/拉起子进程，需用户审批。
bool mcpManageNeedsConfirmation(Map<String, Object?> args) => !const {
  'list',
  'workspaces',
}.contains((args['action'] as String?)?.toLowerCase());

/// 审批卡摘要。
String mcpManageConfirmSummary(Map<String, Object?> args) {
  final action = (args['action'] as String?)?.toLowerCase();
  final target = args['name'] ?? args['id'] ?? '';
  switch (action) {
    case 'add':
      return '添加 MCP 服务器「$target」';
    case 'remove':
      return '删除 MCP 服务器「$target」';
    case 'toggle':
      return '${args['enabled'] == false ? '停用' : '启用'} MCP 服务器「$target」';
    default:
      return '管理 MCP 服务器: ${action ?? '未知操作'}';
  }
}

Future<McpToolResult> runMcpManageTool(
  Ref ref,
  Map<String, Object?> args,
) async {
  final action = (args['action'] as String?)?.toLowerCase() ?? '';
  try {
    switch (action) {
      case 'list':
        return _list(ref);
      case 'add':
        return _add(ref, args);
      case 'remove':
        return _remove(ref, args);
      case 'toggle':
        return _toggle(ref, args);
      case 'workspaces':
        return _workspaces(ref);
      default:
        return _error(
          '未知的 action: $action（可用：list/add/remove/toggle/workspaces）',
        );
    }
  } catch (e) {
    return _error('mcp_manage 执行失败: $e');
  }
}

McpToolResult _ok(Object? data) => McpToolResult(
  const JsonEncoder.withIndent('  ').convert({'success': true, 'data': data}),
);

McpToolResult _error(String message) => McpToolResult(
  jsonEncode({'success': false, 'error': message}),
  isError: true,
);

Map<String, Object?> _summary(McpServer s) => {
  'id': s.id,
  'name': s.name,
  'type': s.type.name,
  'isActive': s.isActive,
  if (s.command != null) 'command': s.command,
  if (s.args != null) 'args': s.args,
  if (s.baseUrl != null) 'url': s.baseUrl,
  if (s.workspaceId != null && s.workspaceId!.isNotEmpty)
    'workspaceId': s.workspaceId,
  if (s.description != null) 'description': s.description,
};

/// stdio 可用的运行环境：有 shell 的工作区（SAF 无终端，排除）。
Future<List<Workspace>> _execWorkspaces(Ref ref) async =>
    (await loadWorkspaces(
      ref,
    )).where((w) => w.backendType != WorkspaceBackendType.localSaf).toList();

/// 缺省自动选运行环境：优先默认主终端同后端（同连接）的工作区，
/// 其次最近打开的可执行工作区；都没有返回 null。
Future<Workspace?> _defaultStdioWorkspace(Ref ref) async {
  final candidates = await _execWorkspaces(ref);
  if (candidates.isEmpty) return null;
  PrimaryTerminal? primary;
  try {
    primary = await ref.read(primaryTerminalStoreProvider.future);
  } catch (_) {}
  final p = primary;
  if (p != null) {
    final matched = candidates
        .where(
          (w) =>
              w.backendType == p.type &&
              (p.connectionId == null || w.connectionId == p.connectionId),
        )
        .firstOrNull;
    if (matched != null) return matched;
  }
  return candidates.first;
}

Future<McpToolResult> _workspaces(Ref ref) async {
  final candidates = await _execWorkspaces(ref);
  final auto = await _defaultStdioWorkspace(ref);
  return _ok({
    'workspaces': [
      for (final w in candidates)
        {
          'id': w.id,
          'name': w.name,
          'backend': w.backendType.name,
          if (w.id == auto?.id) 'default': true,
        },
    ],
    if (candidates.isEmpty)
      'hint': '没有可执行的工作区（proot / Termux / SSH），请用户先到工作区页打开一个。',
  });
}

/// mcp_manage 只管外部服务器：内置/助手类（@aether/* inMemory）与外部
/// 配置同住一个存储，但它们由工具分组/设置页管理，不应在这里
/// 被列出或被 remove/toggle 误伤。
Future<List<McpServer>> _servers(Ref ref) async =>
    (await ref.read(mcpServersProvider.future))
        .where(
          (s) =>
              s.type != McpServerType.inMemory &&
              !isBuiltinMcpServerName(s.name),
        )
        .toList();

Future<McpServer?> _find(Ref ref, Map<String, Object?> args) async {
  final id = (args['id'] as String?)?.trim();
  final name = (args['name'] as String?)?.trim();
  final servers = await _servers(ref);
  if (id != null && id.isNotEmpty) {
    return servers.where((s) => s.id == id).firstOrNull;
  }
  if (name != null && name.isNotEmpty) {
    return servers.where((s) => s.name == name).firstOrNull;
  }
  return null;
}

Future<McpToolResult> _list(Ref ref) async {
  final servers = await _servers(ref);
  return _ok(servers.map(_summary).toList());
}

Future<McpToolResult> _add(Ref ref, Map<String, Object?> args) async {
  final name = (args['name'] as String?)?.trim() ?? '';
  final config = args['config'];
  if (name.isEmpty) return _error('add 需要 name');
  if (isBuiltinMcpServerName(name)) {
    return _error('「$name」是内置工具服务器名称，不能用作外部服务器名');
  }
  if (config is! Map<String, Object?>) {
    return _error('add 需要 config 对象（格式见内置技能「MCP 服务器管理」）');
  }
  final notifier = ref.read(mcpServersProvider.notifier);
  final existing = await _servers(ref);
  if (existing.any((s) => s.name == name)) {
    return _error('已存在同名服务器「$name」；如需修改请先 remove 再 add');
  }
  // stdio 需要运行环境（工作区终端）：先解析好再写入，避免添加一半。
  final isStdio =
      config['command'] != null ||
      (config['type'] as String?)?.toLowerCase().contains('stdio') == true;
  Workspace? runEnv;
  if (isStdio) {
    final requested = (args['workspace'] as String?)?.trim();
    if (requested != null && requested.isNotEmpty) {
      final candidates = await _execWorkspaces(ref);
      runEnv = candidates.where((w) => w.id == requested).firstOrNull ??
          candidates.where((w) => w.name == requested).firstOrNull;
      if (runEnv == null) {
        return _error(
          '找不到运行环境「$requested」（用 action=workspaces 查看可用工作区）',
        );
      }
    } else {
      runEnv = await _defaultStdioWorkspace(ref);
      if (runEnv == null) {
        return _error(
          'stdio 服务器需要运行环境，但当前没有可执行的工作区'
          '（proot / Termux / SSH）；请用户先到工作区页打开一个。',
        );
      }
    }
  }
  // 复用设置页 JSON 导入的解析（Claude Desktop mcpServers 条目格式：
  // command/args/env → stdio，url/headers → sse/http，type 可显式指定）。
  final result = await notifier.importFromJson(
    jsonEncode({
      'mcpServers': {name: config},
    }),
  );
  if (result.imported == 0) {
    return _error('添加失败: ${result.errors.join('; ')}');
  }
  final imported = (await _servers(
    ref,
  )).where((s) => s.name == name).lastOrNull;
  if (imported == null) return _error('添加后未找到服务器「$name」');
  final added = runEnv == null
      ? imported
      : imported.copyWith(workspaceId: runEnv.id);
  if (runEnv != null) await notifier.edit(added);
  if (args['enabled'] != false) {
    await notifier.toggleActive(added.id, isActive: true);
  }
  final addedId = added.id;
  final current = (await _servers(
    ref,
  )).where((s) => s.id == addedId).firstOrNull;
  return _ok({
    'added': _summary(current ?? added),
    if (runEnv != null) 'runEnvironment': runEnv.name,
    'hint':
        '已添加${args['enabled'] != false ? '并启用' : '（未启用）'}。'
        '${runEnv != null ? '运行环境：${runEnv.name}（可用 workspace 参数指定其他）。' : ''}'
        'stdio 服务器启用即拉起子进程；如启动失败可在设置页查看日志。',
  });
}

Future<McpToolResult> _remove(Ref ref, Map<String, Object?> args) async {
  final server = await _find(ref, args);
  if (server == null) return _error('未找到指定的服务器（用 list 查看现有列表）');
  if (server.isActive) {
    await ref
        .read(mcpServersProvider.notifier)
        .toggleActive(server.id, isActive: false);
  }
  await ref.read(mcpServersProvider.notifier).remove(server.id);
  return _ok({'removed': _summary(server)});
}

Future<McpToolResult> _toggle(Ref ref, Map<String, Object?> args) async {
  final enabled = args['enabled'];
  if (enabled is! bool) return _error('toggle 需要 enabled（true/false）');
  final server = await _find(ref, args);
  if (server == null) return _error('未找到指定的服务器（用 list 查看现有列表）');
  await ref
      .read(mcpServersProvider.notifier)
      .toggleActive(server.id, isActive: enabled);
  return _ok({
    'id': server.id,
    'name': server.name,
    'isActive': enabled,
    if (enabled && server.type == McpServerType.stdio)
      'hint': '已尝试拉起 stdio 进程；启动失败不会回滚开关，可在设置页查看日志。',
  });
}
