// `@aether/file-editor` built-in MCP server — local execution entry point.
//
// Lets the chat model browse and read the user's workspace through the
// `WorkspaceBackend` (SAF on Android). Tool names/params mirror the original
// AetherLink `@aether/file-editor` server. Write tools (write_to_file /
// apply_diff / …) and the HITL confirmation gateway land in a follow-up PR;
// this file wires the six read-only tools.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_read_handlers.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

/// The built-in MCP server name this router serves.
const String kFileEditorServerName = '@aether/file-editor';

/// Runs a `@aether/file-editor` [toolName] with [args], using [ref] to reach
/// the workspace providers. Returns an error [McpToolResult] for unknown tools
/// or backend failures (never throws).
Future<McpToolResult> runFileEditorTool(
  Ref ref,
  String toolName,
  Map<String, Object?> args,
) async {
  try {
    switch (toolName) {
      case 'list_workspaces':
        return await listWorkspaces(ref);
      case 'get_workspace_files':
        return await getWorkspaceFiles(ref, args);
      case 'list_files':
        return await listFiles(ref, args);
      case 'read_file':
        return await readFile(ref, args);
      case 'get_file_info':
        return await getFileInfo(ref, args);
      case 'search_files':
        return await searchFiles(ref, args);
    }
    return fileEditorError('未知的工具: $toolName');
  } on FileEditorError catch (e) {
    return fileEditorError(e.message);
  } catch (e) {
    return fileEditorError('文件编辑工具执行失败: $e');
  }
}
