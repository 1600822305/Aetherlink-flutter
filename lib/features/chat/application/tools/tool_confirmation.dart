import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/knowledge/knowledge_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/settings_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/tool_auth_policy.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/terminal/terminal_tools.dart';

/// Whether this tool call must pause for user approval (HITL) before running:
/// settings tools with `confirm` permission, file-editor / knowledge /
/// terminal write-or-execute tools. [workspaces] 供终端工具按目标工作区的
/// scope 分级审批（双作用域设计稿 §3.2）。
bool toolNeedsConfirmation(
  ToolRoute route,
  String toolName,
  Map<String, Object?> args, {
  List<Workspace> workspaces = const [],
}) {
  return (route is SettingsToolRoute &&
          inferSettingsPermission(toolName) ==
              SettingsToolPermission.confirm) ||
      (route is FileEditorToolRoute &&
          fileEditorNeedsConfirmation(toolName)) ||
      (route is KnowledgeToolRoute &&
          knowledgeToolNeedsConfirmation(toolName, args)) ||
      (route is TerminalToolRoute &&
          terminalToolNeedsConfirmation(
            toolName,
            args,
            workspaces: workspaces,
          ));
}

/// Whether the user's tool authorization whitelist ([policy], 工作区管理页
/// → 工具授权) lets this normally-gated call skip the confirmation prompt.
/// 越出项目工作区 root 的终端命令不受白名单覆盖，仍强制审批
/// （双作用域设计稿 §4.1 硬要求）。
bool toolAutoApprovedByPolicy(
  ToolAuthPolicy policy,
  ToolRoute route,
  String toolName,
  Map<String, Object?> args, {
  List<Workspace> workspaces = const [],
}) {
  final String server;
  if (route is FileEditorToolRoute) {
    server = kFileEditorServerName;
  } else if (route is TerminalToolRoute) {
    server = kTerminalServerName;
  } else {
    return false;
  }
  if (!policy.isAutoApproved(server, toolName)) return false;
  return !(route is TerminalToolRoute &&
      terminalCommandEscapesRoot(toolName, args, workspaces: workspaces));
}

/// Whether this tool call is a command that can be aborted mid-flight
/// through the tool block's 中断 button (`terminal_execute` sends Ctrl-C to
/// the session), so the caller registers a cancel signal before running it.
bool isCancelableCommandCall(ToolRoute route, String toolName) {
  return route is TerminalToolRoute && toolName == 'terminal_execute';
}

/// Human-readable summary for a confirmation dialog.
String toolConfirmSummary(String toolName, Map<String, Object?> args) {
  switch (toolName) {
    case 'create_provider':
      return '创建模型供应商「${args['name'] ?? '未命名'}」';
    case 'delete_provider':
      return '删除模型供应商（ID: ${args['id']})';
    case 'add_model':
      return '向供应商添加模型「${args['name'] ?? '未命名'}」';
    case 'delete_model':
      return '从供应商删除模型「${args['modelId'] ?? ''}」';
    // @aether/file-editor write tools.
    case 'write':
      return args['path'] != null
          ? '覆盖写入文件「${_pathTail(args['path'])}」的全部内容'
          : '在「${_pathTail(args['parent_path'])}」下新建文件「${args['name'] ?? ''}」';
    case 'move':
      return args['destination_path'] != null
          ? '移动「${_pathTail(args['path'] ?? args['source_path'])}」到「${_pathTail(args['destination_path'])}」'
          : '将「${_pathTail(args['path'])}」重命名为「${args['new_name'] ?? ''}」';
    case 'copy_file':
      return '复制「${_pathTail(args['source_path'])}」到「${_pathTail(args['destination_path'])}」';
    case 'delete_file':
      return '删除「${_pathTail(args['path'])}」';
    case 'edit':
      return '在「${_pathTail(args['path'])}」中替换「${args['search'] ?? ''}」';
    case 'terminal_execute':
      return '在工作区执行命令：${args['command'] ?? ''}';
    // 只有 action=write 会走到确认（见 terminalToolNeedsConfirmation）。
    case 'terminal_session':
      return '向终端会话 ${args['session_id'] ?? ''} 的进程输入：${args['input'] ?? ''}';
    // @aether/knowledge 写操作（kb_manage）。
    case 'kb_manage':
      return _knowledgeManageSummary(args);
    default:
      return '执行操作: $toolName';
  }
}

/// Confirmation summary for a `kb_manage` call, keyed by its `action`.
String _knowledgeManageSummary(Map<String, Object?> args) {
  final action = (args['action'] as String?)?.toLowerCase();
  switch (action) {
    case 'create':
      return '创建知识库「${args['name'] ?? '未命名'}」';
    case 'add_note':
      final title = (args['title'] as String?)?.trim();
      return '向知识库添加笔记${title == null || title.isEmpty ? '' : '「$title」'}';
    case 'add_url':
      return '抓取网页并摄取进知识库（${args['url'] ?? ''}）';
    case 'add_workspace':
      return '把工作区目录摄取进知识库（工作区 ID: ${args['workspace_id'] ?? ''}）';
    case 'retry_embeddings':
      return '补嵌知识库中嵌入失败的切块（ID: ${args['base_id'] ?? ''}）';
    case 'delete':
      return '删除知识库（ID: ${args['base_id'] ?? ''}）';
    case 'refresh':
      return '重建知识库索引（ID: ${args['base_id'] ?? ''}）';
    default:
      return '管理知识库: ${action ?? '未知操作'}';
  }
}

/// A short, human-readable tail for an opaque SAF `content://` path, used in
/// confirmation summaries. Falls back to the raw value when it can't decode.
String _pathTail(Object? path) {
  if (path == null) return '?';
  final raw = path.toString();
  if (raw.isEmpty) return '?';
  try {
    final decoded = Uri.decodeComponent(raw);
    final normalized = decoded.replaceAll('\\', '/');
    final segments = normalized
        .split('/')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (segments.isEmpty) return raw;
    var tail = segments.last;
    final colon = tail.lastIndexOf(':');
    if (colon >= 0 && colon < tail.length - 1) tail = tail.substring(colon + 1);
    return tail;
  } catch (_) {
    return raw;
  }
}
