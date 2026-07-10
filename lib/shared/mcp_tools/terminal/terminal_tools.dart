// `@aether/terminal` built-in MCP server — 终端 AI 工具。
//
// 默认目标是内置终端（PRoot + Alpine 沙箱）；传 `workspace` 参数可指向任何
// canExec 的工作区（SSH / Termux），在其远端 shell 里执行。terminal_execute
// 走一次性 exec（stdout/stderr/exit code 干净分离）；terminal_session_* 走
// WorkspaceBackend 层的长驻会话池（exec 超时后台继续跑 + tailOutput 回看，
// 见 workspace_session_pool.dart）。命令执行类工具经聊天层 HITL 审批（见
// terminalToolNeedsConfirmation），并统一过命令黑名单（设计文档 §3.2）。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/terminal/application/terminal_engine_manager.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_command_guard.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';
import 'package:aetherlink_flutter/features/workspace/data/proot_local_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

/// The built-in MCP server name this router serves.
const String kTerminalServerName = '@aether/terminal';

/// Default one-shot command timeout（设计文档 §2.3：默认 120s，可配）。
const int _kDefaultTimeoutMs = 120000;

/// Whether [toolName] runs commands and therefore requires HITL confirmation
/// before executing（默认白名单审批模式，设计文档 §3.2）。
///
/// 双作用域设计稿 §3.2：目标是项目模式（scope=project）工作区时按
/// [evaluateCommandRisk] 分级——root 内低危只读命令免审批，其余照常；
/// 全机模式 / 未指定工作区维持全量审批。[workspaces] 用于同步解析
/// `workspace` 参数（编号 / ID / 名称，与 resolveWorkspace 同规则）。
bool terminalToolNeedsConfirmation(
  String toolName,
  Map<String, Object?> args, {
  List<Workspace> workspaces = const [],
}) {
  switch (toolName) {
    case 'terminal_execute':
    case 'terminal_session_exec':
      break;
    // stdin 写入可驱动会话里的任意程序（shell 提示符下等同执行命令），
    // 无法静态评级 → 全量审批。
    case 'terminal_session_write':
      return true;
    default:
      return false;
  }
  final workspace = _matchWorkspaceArg(args, workspaces);
  if (workspace == null || workspace.scope != WorkspaceScope.project) {
    return true;
  }
  final command = args['command']?.toString() ?? '';
  return evaluateCommandRisk(command, root: workspace.root) !=
      CommandRisk.safeInRoot;
}

/// Whether this terminal call escapes its project workspace root and must
/// therefore always prompt — 免确认窗口（任务级预授权）不覆盖越界命令
/// （双作用域设计稿 §4.1 硬要求）。
bool terminalCommandEscapesRoot(
  String toolName,
  Map<String, Object?> args, {
  List<Workspace> workspaces = const [],
}) {
  switch (toolName) {
    case 'terminal_execute':
    case 'terminal_session_exec':
      break;
    default:
      return false;
  }
  final workspace = _matchWorkspaceArg(args, workspaces);
  if (workspace == null || workspace.scope != WorkspaceScope.project) {
    return false;
  }
  final command = args['command']?.toString() ?? '';
  return evaluateCommandRisk(command, root: workspace.root) ==
      CommandRisk.escapesRoot;
}

/// 同步版的 `workspace` 参数解析（编号 / ID / 名称），解析不到返回 null。
Workspace? _matchWorkspaceArg(
  Map<String, Object?> args,
  List<Workspace> workspaces,
) {
  final raw = args['workspace']?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  final index = int.tryParse(raw);
  if (index != null && index >= 1 && index <= workspaces.length) {
    return workspaces[index - 1];
  }
  for (final w in workspaces) {
    if (w.id == raw) return w;
  }
  for (final w in workspaces) {
    if (w.name == raw) return w;
  }
  return null;
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
    switch (toolName) {
      case 'terminal_execute':
        return await _execute(ref, args, cancelSignal: cancelSignal);
      case 'terminal_session_create':
        return await _sessionCreate(ref, args);
      case 'terminal_session_list':
        return await _sessionList(ref, args);
      case 'terminal_session_exec':
        return await _sessionExec(ref, args);
      case 'terminal_session_output':
        return _sessionOutput(ref, args);
      case 'terminal_session_write':
        return _sessionWrite(ref, args);
      case 'terminal_session_close':
        return await _sessionClose(ref, args);
    }
    return fileEditorError('未知的工具: $toolName');
  } on FileEditorError catch (e) {
    return fileEditorError(e.message);
  } on WorkspaceSessionException catch (e) {
    return fileEditorError(e.message);
  } catch (e) {
    return fileEditorError('终端工具执行失败: $e');
  }
}

/// 命令的执行目标：默认内置终端，`workspace` 参数指定时为该工作区的后端。
class _ExecTarget {
  const _ExecTarget({
    required this.backend,
    required this.label,
    this.defaultCwd,
    this.workspaceId,
    this.environment = const {},
  });

  final WorkspaceBackend backend;

  /// 展示名：工作区名，内置终端为「内置终端」。
  final String label;

  /// 未指定 cwd 时的工作目录（SSH 为工作区根；内置终端为 null → /root）。
  final String? defaultCwd;

  /// 锚定的工作区 ID（会话池按它隔离，双作用域设计稿 §3.1）；
  /// 未指定 workspace 时的内置终端默认目标为 null。
  final String? workspaceId;

  /// 新建会话时注入的环境变量（项目模式下为 WORKSPACE_ROOT / NAME）。
  final Map<String, String> environment;
}

/// Resolves the `workspace` arg to an exec-capable backend, defaulting to the
/// built-in PRoot terminal. Ensures the PRoot engine is installed when it is
/// the target.
Future<_ExecTarget> _resolveTarget(Ref ref, Map<String, Object?> args) async {
  final _ExecTarget target;
  if (optionalString(args, 'workspace') != null) {
    final resolved = await resolveWorkspace(ref, args);
    if (!resolved.backend.capabilities.canExec) {
      throw FileEditorError(
        '工作区「${resolved.workspace.name}」的后端不支持命令执行'
        '（仅内置终端 / SSH / Termux 支持）。',
      );
    }
    final workspace = resolved.workspace;
    target = _ExecTarget(
      backend: resolved.backend,
      label: workspace.name,
      defaultCwd: workspace.root,
      workspaceId: workspace.id,
      environment: workspace.scope == WorkspaceScope.project
          ? {
              'WORKSPACE_ROOT': workspace.root,
              'WORKSPACE_NAME': workspace.name,
              // L2 语言级隔离（设计稿 §4 P5）：独立 HOME 按工作区隔离
              // rc 文件 / 全局配置 / 缓存。
              if (workspace.isolatedHomePath != null)
                'HOME': workspace.isolatedHomePath!,
            }
          : const {},
    );
  } else {
    target = _ExecTarget(
      backend: ref.read(prootLocalBackendProvider),
      label: '内置终端',
    );
  }
  if (target.backend is ProotLocalBackend &&
      !await TerminalEngineManager.instance.isInstalled()) {
    throw const FileEditorError(
      '内置终端环境未安装。请让用户在「工作区 → 打开文件夹 → 内置终端」里完成安装后再试。',
    );
  }
  return target;
}

/// 命中黑名单的命令统一拦截（设计文档 §3）；只管 AI 通道，用户在交互式
/// 终端里手动执行不受限。
McpToolResult? _guardCommand(String command) {
  final reason = blockedCommandReason(command);
  if (reason == null) return null;
  return fileEditorError(
    '命令被安全黑名单拦截（$reason），未执行。如确需执行，请让用户在终端里手动运行。',
  );
}

Future<McpToolResult> _execute(
  Ref ref,
  Map<String, Object?> args, {
  Future<void>? cancelSignal,
}) async {
  final command = requireString(args, 'command');
  final blocked = _guardCommand(command);
  if (blocked != null) return blocked;
  final target = await _resolveTarget(ref, args);
  final cwd = optionalString(args, 'cwd') ?? target.defaultCwd;
  final timeoutMs = optionalInt(args, 'timeout_ms') ?? _kDefaultTimeoutMs;
  final result = await target.backend.exec(
    command,
    workingDirectory: cwd,
    timeout: timeoutMs > 0 ? Duration(milliseconds: timeoutMs) : null,
    cancelSignal: cancelSignal,
  );
  return fileEditorOk({
    'command': command,
    'workspace': target.label,
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
  final target = await _resolveTarget(ref, args);
  final pool = ref.read(workspaceSessionPoolManagerProvider).poolFor(
        target.backend,
        workspaceLabel: target.label,
        workspaceId: target.workspaceId,
      );
  final session = await pool.create(
    name: optionalString(args, 'name'),
    workingDirectory: optionalString(args, 'cwd') ?? target.defaultCwd,
    environment: target.environment,
  );
  return fileEditorOk({
    'sessionId': session.id,
    'name': session.name,
    'workspace': session.workspaceLabel,
    'createdAt': session.createdAt.toIso8601String(),
  });
}

Future<McpToolResult> _sessionList(
  Ref ref,
  Map<String, Object?> args,
) async {
  var sessions = ref.read(workspaceSessionPoolManagerProvider).allSessions();
  // 传 workspace 参数时只列该工作区的会话（双作用域设计稿 §3.1）。
  if (optionalString(args, 'workspace') != null) {
    final resolved = await resolveWorkspace(ref, args);
    sessions = [
      for (final s in sessions)
        if (s.workspaceId == resolved.workspace.id) s,
    ];
  }
  return fileEditorOk({
    'sessions': [
      for (final s in sessions)
        {
          'sessionId': s.id,
          'name': s.name,
          'workspace': s.workspaceLabel,
          if (s.workspaceId != null) 'workspaceId': s.workspaceId,
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
  final blocked = _guardCommand(command);
  if (blocked != null) return blocked;
  final manager = ref.read(workspaceSessionPoolManagerProvider);
  final sessionId = optionalString(args, 'session_id');
  final PooledWorkspaceSession session;
  if (sessionId != null) {
    session = manager.find(sessionId) ??
        (throw FileEditorError(
          '没有找到会话 $sessionId（可用 terminal_session_list 查看）',
        ));
  } else {
    final target = await _resolveTarget(ref, args);
    session = await manager
        .poolFor(
          target.backend,
          workspaceLabel: target.label,
          workspaceId: target.workspaceId,
        )
        .acquireDefault(
          workingDirectory: target.defaultCwd,
          environment: target.environment,
        );
  }
  final timeoutMs = optionalInt(args, 'timeout_ms') ?? _kDefaultTimeoutMs;
  final result = await session.exec(
    command,
    timeout: Duration(milliseconds: timeoutMs > 0 ? timeoutMs : _kDefaultTimeoutMs),
  );
  return fileEditorOk({
    'sessionId': session.id,
    'workspace': session.workspaceLabel,
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
  final session =
      ref.read(workspaceSessionPoolManagerProvider).find(sessionId);
  if (session == null) {
    return fileEditorError('没有找到会话 $sessionId（可用 terminal_session_list 查看）');
  }
  final tail = optionalInt(args, 'tail_chars') ?? 4000;
  return fileEditorOk({
    'sessionId': session.id,
    'workspace': session.workspaceLabel,
    'busy': session.busy,
    'output': session.tailOutput(tail > 0 ? tail : 4000),
  });
}

/// 往长驻会话的运行中进程写 stdin（交互式程序输入，设计稿 §3.4）。
McpToolResult _sessionWrite(Ref ref, Map<String, Object?> args) {
  final sessionId = requireString(args, 'session_id');
  final session =
      ref.read(workspaceSessionPoolManagerProvider).find(sessionId);
  if (session == null) {
    return fileEditorError('没有找到会话 $sessionId（可用 terminal_session_list 查看）');
  }
  final input = requireString(args, 'input');
  final pressEnter = args['press_enter'] != false;
  session.writeInput(pressEnter && !input.endsWith('\n') ? '$input\n' : input);
  return fileEditorOk({
    'sessionId': session.id,
    'workspace': session.workspaceLabel,
    'written': true,
    'hint': '已写入 stdin；可用 terminal_session_output 回看进程响应。',
  });
}

Future<McpToolResult> _sessionClose(
  Ref ref,
  Map<String, Object?> args,
) async {
  final sessionId = requireString(args, 'session_id');
  final closed =
      await ref.read(workspaceSessionPoolManagerProvider).close(sessionId);
  return closed
      ? fileEditorOk({'sessionId': sessionId, 'closed': true})
      : fileEditorError('没有找到会话 $sessionId（可能已结束）');
}
