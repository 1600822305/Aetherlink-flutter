// `run_command` handler for the `@aether/file-editor` built-in MCP server
// (设计文档 §8.1). Runs one shell command in the workspace's 长驻默认会话
// （与 @aether/terminal 共用会话池：cd / 环境变量跨命令保留，终端页可联动
// 围观 / 接管）— only exec-capable backends (内置终端 / SSH / Termux); SAF
// cannot. The call is gated high-risk through the chat layer's HITL
// confirmation before it ever reaches here (see fileEditorRiskLevel).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

/// Default command timeout when the caller doesn't specify one.
const int _kDefaultTimeoutMs = 60000;

/// Runs the `command` arg in the target workspace's 长驻默认会话 and returns
/// the output / exit code (`sessionId` 随结果返回，聊天卡片据此提供「在终端中
/// 查看」跳转）。The target is the `workspace` arg (index / id / name) when
/// given, otherwise the currently-open workspace, otherwise the most recently
/// opened one.
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

  final workspace = resolved.workspace;
  final session = await ref
      .read(workspaceSessionPoolManagerProvider)
      .poolFor(
        backend,
        workspaceLabel: workspace.name,
        workspaceId: workspace.id,
      )
      .acquireDefault(
        workingDirectory: workspace.root,
        environment: workspace.scope == WorkspaceScope.project
            ? {
                'WORKSPACE_ROOT': workspace.root,
                'WORKSPACE_NAME': workspace.name,
                if (workspace.isolatedHomePath != null)
                  'HOME': workspace.isolatedHomePath!,
              }
            : const {},
      );
  // 会话里 cwd 是 shell 状态；显式传 cwd 时先 cd 过去再执行。
  final cwd = optionalString(args, 'cwd');
  final effective = (cwd == null || cwd.isEmpty)
      ? command
      : "cd '${cwd.replaceAll("'", r"'\''")}' && $command";
  final timeoutMs = optionalInt(args, 'timeout_ms') ?? _kDefaultTimeoutMs;

  final result = await session.exec(
    effective,
    timeout: Duration(
      milliseconds: timeoutMs > 0 ? timeoutMs : _kDefaultTimeoutMs,
    ),
    cancelSignal: cancelSignal,
    onOutput: onOutput,
  );

  return fileEditorOk({
    'command': command,
    'workspace': workspace.name,
    'sessionId': session.id,
    if (cwd != null && cwd.isNotEmpty) 'cwd': cwd,
    'exitCode': result.exitCode,
    'timedOut': result.timedOut,
    'canceled': result.canceled,
    if (result.timedOut)
      'hint': '命令超时未结束，仍在会话里继续跑；可稍后用 terminal_session_output 回看输出。'
    else if (result.canceled)
      'hint': '命令被用户中断（已向会话发 Ctrl-C），会话仍可继续使用。',
    'stdout': result.output,
    'stderr': '',
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
