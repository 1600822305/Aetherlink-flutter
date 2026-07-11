// `run_command` handler for the `@aether/file-editor` built-in MCP server
// (设计文档 §8.1: AI 一次性 exec). Runs one shell command on the workspace's
// backend — only remote backends (SSH / Termux) can exec; SAF cannot. The call
// is gated high-risk through the chat layer's HITL confirmation before it ever
// reaches here (see fileEditorRiskLevel).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

/// Default command timeout when the caller doesn't specify one.
const int _kDefaultTimeoutMs = 60000;

/// Runs the `command` arg on the target workspace's backend and returns its
/// stdout / stderr / exit code. The target is the `workspace` arg (index / id /
/// name) when given, otherwise the currently-open workspace, otherwise the most
/// recently opened one.
Future<McpToolResult> runCommand(
  Ref ref,
  Map<String, Object?> args, {
  Future<void>? cancelSignal,
  void Function(String chunk)? onOutput,
}) async {
  final command = requireString(args, 'command');
  final resolved = await _resolveTarget(ref, args);
  final backend = resolved.backend;

  if (!backend.capabilities.canExec) {
    return fileEditorError(
      '工作区「${resolved.workspace.name}」的后端不支持命令执行（仅 SSH / Termux / 内置终端支持）。',
    );
  }

  final cwd = optionalString(args, 'cwd') ?? resolved.workspace.root;
  final timeoutMs = optionalInt(args, 'timeout_ms') ?? _kDefaultTimeoutMs;
  final timeout = timeoutMs > 0 ? Duration(milliseconds: timeoutMs) : null;

  final result = await backend.exec(
    command,
    workingDirectory: cwd,
    timeout: timeout,
    cancelSignal: cancelSignal,
    onOutput: onOutput,
  );

  return fileEditorOk({
    'command': command,
    'workspace': resolved.workspace.name,
    'cwd': cwd,
    'exitCode': result.exitCode,
    'timedOut': result.timedOut,
    if (result.timedOut)
      'hint': '命令超时已被终止。长任务建议改用 @aether/terminal 的 terminal_session_exec'
          '（传 workspace 参数指定本工作区）：超时不杀命令、后台继续跑，'
          '可用 terminal_session_output 回看。',
    'canceled': result.canceled,
    'stdout': result.stdout,
    'stderr': result.stderr,
  });
}

Future<ResolvedWorkspace> _resolveTarget(
  Ref ref,
  Map<String, Object?> args,
) async {
  // An explicit workspace arg wins; reuse the shared resolver (index/id/name).
  if (optionalString(args, 'workspace') != null) {
    return resolveWorkspace(ref, args);
  }
  final workspaces = await loadWorkspaces(ref);
  if (workspaces.isEmpty) {
    throw const FileEditorError(
      '当前没有任何工作区，请先在工作区页面「打开文件夹」后再试。',
    );
  }
  final target = ref.read(currentWorkspaceProvider) ?? workspaces.first;
  return ResolvedWorkspace(target, ref.read(workspaceBackendProvider(target)));
}
