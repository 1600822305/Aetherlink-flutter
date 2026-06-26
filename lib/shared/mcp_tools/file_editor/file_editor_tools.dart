// `@aether/file-editor` built-in MCP server — local execution entry point.
//
// Lets the chat model browse and read the user's workspace through the
// `WorkspaceBackend` (SAF on Android). Tool names/params mirror the original
// AetherLink `@aether/file-editor` server. Read tools run unguarded; write
// tools (write_to_file / apply_diff / …) are gated behind the chat layer's
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
    case 'write_to_file':
    case 'apply_diff':
    case 'delete_file':
      return FileEditorRisk.high;
    case 'create_file':
    case 'rename_file':
    case 'move_file':
    case 'copy_file':
    case 'insert_content':
    case 'replace_in_file':
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
      case 'write_to_file':
        return await writeToFile(ref, args);
      case 'create_file':
        return await createFile(ref, args);
      case 'rename_file':
        return await renameFile(ref, args);
      case 'move_file':
        return await moveFile(ref, args);
      case 'copy_file':
        return await copyFile(ref, args);
      case 'delete_file':
        return await deleteFile(ref, args);
      case 'insert_content':
        return await insertContent(ref, args);
      case 'apply_diff':
        return await applyDiff(ref, args);
      case 'replace_in_file':
        return await replaceInFile(ref, args);
    }
    return fileEditorError('未知的工具: $toolName');
  } on FileEditorError catch (e) {
    return fileEditorError(e.message);
  } catch (e) {
    return fileEditorError('文件编辑工具执行失败: $e');
  }
}
