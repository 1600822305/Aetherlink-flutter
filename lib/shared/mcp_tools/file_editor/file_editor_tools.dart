// `@aether/file-editor` built-in MCP server — local execution entry point.
//
// Lets the chat model browse and read the user's workspace through the
// `WorkspaceBackend` (SAF on Android). Tool names/params mirror the original
// AetherLink `@aether/file-editor` server. Read tools run unguarded; write
// tools (write / edit / …) are gated behind the chat layer's
// HITL confirmation gateway (see `fileEditorRiskLevel`).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_read_handlers.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_write_handlers.dart';

/// The built-in MCP server name this router serves.
const String kFileEditorServerName = '@aether/file-editor';

/// Risk classification for a `@aether/file-editor` write tool, mirroring the
/// original AetherLink ToolConfirmationService registry. `null` means the tool
/// is read-only and needs no confirmation.
enum FileEditorRisk { medium, high }

/// Maps a [toolName] to its confirmation risk, or `null` when it's read-only.
/// Destructive / whole-file-rewriting ops are [FileEditorRisk.high]; the
/// rest of the mutating ops are [FileEditorRisk.medium].
FileEditorRisk? fileEditorRiskLevel(String toolName) {
  switch (toolName) {
    case 'write':
    case 'delete_file':
      return FileEditorRisk.high;
    case 'create_directory':
    case 'move':
    case 'copy_file':
    case 'edit':
      return FileEditorRisk.medium;
  }
  return null;
}

/// Whether [toolName] is a `@aether/file-editor` write tool requiring HITL
/// confirmation before it runs.
bool fileEditorNeedsConfirmation(String toolName) =>
    fileEditorRiskLevel(toolName) != null;

/// Runs a `@aether/file-editor` [toolName] with [args], using [ref] to reach
/// the workspace providers. Returns an error [McpToolResult] for unknown tools
/// or backend failures (never throws). [sessionKey] scopes the read-state
/// registry (读取去重 + 陈旧检测) to the calling conversation / agent task.
Future<McpToolResult> runFileEditorTool(
  Ref ref,
  String toolName,
  Map<String, Object?> args, {
  String sessionKey = '',
}) async {
  try {
    switch (toolName) {
      case 'list_files':
        return await listFiles(ref, args);
      case 'read_file':
        return await readFile(ref, args, sessionKey: sessionKey);
      case 'get_file_info':
        return await getFileInfo(ref, args);
      case 'search_files':
        return await searchFiles(ref, args);
      case 'get_diagnostics':
        return await getDiagnostics(ref, args);
      case 'write':
        return await writeFile(ref, args, sessionKey: sessionKey);
      case 'create_directory':
        return await createDirectory(ref, args);
      case 'move':
        return await moveEntry(ref, args);
      case 'copy_file':
        return await copyFile(ref, args);
      case 'delete_file':
        return await deleteFile(ref, args);
      case 'edit':
        return await editFile(ref, args, sessionKey: sessionKey);
    }
    return fileEditorError('未知的工具: $toolName');
  } on FileEditorError catch (e) {
    return fileEditorError(e.message);
  } catch (e) {
    return fileEditorError('文件编辑工具执行失败: $e');
  }
}
