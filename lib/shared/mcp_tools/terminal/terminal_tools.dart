// `@aether/terminal` built-in MCP server — 内置终端（PRoot + Alpine）AI 工具。
//
// terminal_execute 走一次性 proot 进程（stdout/stderr/exit code 干净分离）；
// terminal_session_* 走长驻会话池（毫秒级复用、可跑后台任务）。命令执行类
// 工具经聊天层 HITL 审批（见 terminalToolNeedsConfirmation），rootfs 天然是
// 沙箱：AI 只能碰 rootfs 内部（设计文档 §3.2）。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/terminal/application/proot_session_pool.dart';
import 'package:aetherlink_flutter/features/terminal/application/terminal_engine_manager.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

/// The built-in MCP server name this router serves.
const String kTerminalServerName = '@aether/terminal';

/// Default one-shot command timeout（设计文档 §2.3：默认 120s，可配）。
const int _kDefaultTimeoutMs = 120000;

/// Whether [toolName] runs commands and therefore requires HITL confirmation
/// before executing（默认白名单审批模式，设计文档 §3.2）。
bool terminalToolNeedsConfirmation(String toolName) {
  switch (toolName) {
    case 'terminal_execute':
    case 'terminal_session_exec':
      return true;
  }
  return false;
}

/// Runs a `@aether/terminal` [toolName] with [args]. Returns an error
/// [McpToolResult] for unknown tools or backend failures (never throws).
Future<McpToolResult> runTerminalTool(
  Ref ref,
  String toolName,
  Map<String, Object?> args, {
  Future<void>? cancelSignal,
}) async {
  try {
    if (!await TerminalEngineManager.instance.isInstalled()) {
      return fileEditorError(
        '内置终端环境未安装。请让用户在「工作区 → 打开文件夹 → 内置终端」里完成安装后再试。',
      );
    }
    switch (toolName) {
      case 'terminal_execute':
        return await _execute(ref, args, cancelSignal: cancelSignal);
      case 'terminal_session_create':
        return await _sessionCreate(ref, args);
      case 'terminal_session_list':
        return _sessionList(ref);
      case 'terminal_session_exec':
        return await _sessionExec(ref, args);
      case 'terminal_session_output':
        return _sessionOutput(ref, args);
      case 'terminal_session_close':
        return await _sessionClose(ref, args);
    }
    return fileEditorError('未知的工具: $toolName');
  } on FileEditorError catch (e) {
    return fileEditorError(e.message);
  } catch (e) {
    return fileEditorError('终端工具执行失败: $e');
  }
}

Future<McpToolResult> _execute(
  Ref ref,
  Map<String, Object?> args, {
  Future<void>? cancelSignal,
}) async {
  final command = requireString(args, 'command');
  final cwd = optionalString(args, 'cwd');
  final timeoutMs = optionalInt(args, 'timeout_ms') ?? _kDefaultTimeoutMs;
  final result = await ref.read(prootLocalBackendProvider).exec(
        command,
        workingDirectory: cwd,
        timeout: timeoutMs > 0 ? Duration(milliseconds: timeoutMs) : null,
        cancelSignal: cancelSignal,
      );
  return fileEditorOk({
    'command': command,
    'cwd': cwd ?? '/root',
    'exitCode': result.exitCode,
    'timedOut': result.timedOut,
    'canceled': result.canceled,
    'stdout': result.stdout,
    'stderr': result.stderr,
  });
}

Future<McpToolResult> _sessionCreate(
  Ref ref,
  Map<String, Object?> args,
) async {
  final pool = ref.read(prootSessionPoolProvider);
  final session = await pool.create(
    name: optionalString(args, 'name'),
    workingDirectory: optionalString(args, 'cwd'),
  );
  return fileEditorOk({
    'sessionId': session.id,
    'name': session.name,
    'createdAt': session.createdAt.toIso8601String(),
  });
}

McpToolResult _sessionList(Ref ref) {
  final sessions = ref.read(prootSessionPoolProvider).list();
  return fileEditorOk({
    'sessions': [
      for (final s in sessions)
        {
          'sessionId': s.id,
          'name': s.name,
          'busy': s.busy,
          'createdAt': s.createdAt.toIso8601String(),
          'lastUsedAt': s.lastUsedAt.toIso8601String(),
        },
    ],
  });
}

Future<McpToolResult> _sessionExec(
  Ref ref,
  Map<String, Object?> args,
) async {
  final command = requireString(args, 'command');
  final pool = ref.read(prootSessionPoolProvider);
  final sessionId = optionalString(args, 'session_id');
  final session = sessionId == null
      ? await pool.acquireDefault()
      : (pool.find(sessionId) ??
          (throw FileEditorError('没有找到会话 $sessionId（可用 terminal_session_list 查看）')));
  final timeoutMs = optionalInt(args, 'timeout_ms') ?? _kDefaultTimeoutMs;
  final result = await session.exec(
    command,
    timeout: Duration(milliseconds: timeoutMs > 0 ? timeoutMs : _kDefaultTimeoutMs),
  );
  return fileEditorOk({
    'sessionId': session.id,
    'command': command,
    'exitCode': result.exitCode,
    'timedOut': result.timedOut,
    if (result.timedOut)
      'hint': '命令超时未结束，仍在会话里继续跑；可稍后用 terminal_session_output 回看输出。',
    'output': result.output,
  });
}

McpToolResult _sessionOutput(Ref ref, Map<String, Object?> args) {
  final sessionId = requireString(args, 'session_id');
  final session = ref.read(prootSessionPoolProvider).find(sessionId);
  if (session == null) {
    return fileEditorError('没有找到会话 $sessionId（可用 terminal_session_list 查看）');
  }
  final tail = optionalInt(args, 'tail_chars') ?? 4000;
  return fileEditorOk({
    'sessionId': session.id,
    'busy': session.busy,
    'output': session.tailOutput(tail > 0 ? tail : 4000),
  });
}

Future<McpToolResult> _sessionClose(
  Ref ref,
  Map<String, Object?> args,
) async {
  final sessionId = requireString(args, 'session_id');
  final closed = await ref.read(prootSessionPoolProvider).close(sessionId);
  return closed
      ? fileEditorOk({'sessionId': sessionId, 'closed': true})
      : fileEditorError('没有找到会话 $sessionId（可能已结束）');
}
