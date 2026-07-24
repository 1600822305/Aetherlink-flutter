import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/mcp_servers_access.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';

/// `mcp_manage`：让模型自助管理外部 MCP 服务器（全局配置，与设置页
/// 同一份存储）。单一工具 + 最小 schema，详细参数格式与操作流程放在
/// 内置技能「MCP 服务器管理」里按需 read_skill 加载（渐进披露，
/// 不占常驻上下文）。写操作（add/remove/toggle）走 HITL 审批。
const String kMcpManageToolName = 'mcp_manage';

const McpToolDefinition kMcpManageToolDefinition = McpToolDefinition(
  name: kMcpManageToolName,
  description:
      '管理外部 MCP 服务器（全局配置）：list 列出 / add 添加 / '
      'remove 删除 / toggle 启停。add 的 config 格式与完整流程见内置技能'
      '「MCP 服务器管理」（先 read_skill 再调用）。',
  inputSchema: {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['list', 'add', 'remove', 'toggle'],
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

/// 除 list 外都会改配置/拉起子进程，需用户审批。
bool mcpManageNeedsConfirmation(Map<String, Object?> args) =>
    (args['action'] as String?)?.toLowerCase() != 'list';

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
      default:
        return _error('未知的 action: $action（可用：list/add/remove/toggle）');
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
  if (s.description != null) 'description': s.description,
};

Future<List<McpServer>> _servers(Ref ref) =>
    ref.read(mcpServersProvider.future);

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
  if (config is! Map<String, Object?>) {
    return _error('add 需要 config 对象（格式见内置技能「MCP 服务器管理」）');
  }
  final notifier = ref.read(mcpServersProvider.notifier);
  final existing = await _servers(ref);
  if (existing.any((s) => s.name == name)) {
    return _error('已存在同名服务器「$name」；如需修改请先 remove 再 add');
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
  final added = (await _servers(ref)).where((s) => s.name == name).lastOrNull;
  if (added == null) return _error('添加后未找到服务器「$name」');
  if (args['enabled'] != false) {
    await notifier.toggleActive(added.id, isActive: true);
  }
  final current = (await _servers(
    ref,
  )).where((s) => s.id == added.id).firstOrNull;
  return _ok({
    'added': _summary(current ?? added),
    'hint':
        '已添加${args['enabled'] != false ? '并启用' : '（未启用）'}。'
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
