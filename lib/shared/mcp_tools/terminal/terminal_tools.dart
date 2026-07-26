// `@aether/terminal` built-in MCP server — 终端 AI 工具。
//
// 默认目标是内置终端（PRoot + Alpine 沙箱）；传 `workspace` 参数可指向任何
// canExec 的工作区（SSH / Termux），在其远端 shell 里执行。只有两个工具：
// terminal_execute（执行命令，可选 session 指定会话——传名字/ID，存在就
// 复用、不存在自动新建（tmux new -A 语义），不传则复用长驻默认会话）
// 和 terminal_session（会话管理，用 action 参数区分 list / output / write /
// interrupt / close：interrupt 发 Ctrl-C 中断卡住的命令，close 关掉不用的
// 会话——否则跑飞的前台命令会让会话永久 busy、占满池后 AI 无法自救），
// 都走 WorkspaceBackend 层的长驻会话池（exec 超时
// 后台继续跑 + tailOutput 回看，见 workspace_session_pool.dart）。命令执行类
// 工具经聊天层 HITL 审批（见 terminalToolNeedsConfirmation），并统一过命令
// 黑名单（设计文档 §3.2）。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/terminal/application/terminal_engine_manager.dart';
import 'package:aetherlink_flutter/features/terminal/domain/terminal_command_guard.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';
import 'package:aetherlink_flutter/features/workspace/data/proot_local_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_session_protocol.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

/// The built-in MCP server name this router serves.
const String kTerminalServerName = '@aether/terminal';

/// Default one-shot command timeout（设计文档 §2.3：默认 120s，可配）。
const int _kDefaultTimeoutMs = 120000;

/// timeout_ms 参数上限（对标 CC BASH_MAX_TIMEOUT_MS = 10 分钟）：
/// 与引擎兜底超时分级的封顶一致，超过按上限收敛。
const int kTerminalMaxTimeoutMs = 600000;

/// 单次 exec 返回给模型的输出上限（字符）：超出时保留头尾、中间省略，
/// 防止 cat 大文件 / 长构建日志一次性灌爆模型上下文。
const int _kExecOutputLimit = 30000;

/// 超长输出裁剪：保留开头 1/4 和结尾 3/4（错误通常在尾部）。
String _clipExecOutput(String output) {
  if (output.length <= _kExecOutputLimit) return output;
  final head = _kExecOutputLimit ~/ 4;
  final tail = _kExecOutputLimit - head;
  final omitted = output.length - head - tail;
  return '${output.substring(0, head)}\n'
      '…（输出过长，中间省略 $omitted 字符，可用 terminal_session '
      'action=output 回看尾部）…\n'
      '${output.substring(output.length - tail)}';
}

/// Whether [toolName] runs commands and therefore requires HITL confirmation
/// before executing（默认白名单审批模式，设计文档 §3.2）。
///
/// 双作用域设计稿 §3.2：目标是项目模式（scope=project）工作区时按
/// [evaluateCommandRisk] 分级——root 内低危只读命令免审批，其余照常；
/// 全机模式 / 未指定工作区时按 [isReadOnlyCommand] 分级——纯只读命令
/// （ls / cat / pwd 等白名单，无重定向/提权）在沙箱内无副作用，
/// 同样免审批，其余全量审批。[workspaces] 用于同步解析
/// `workspace` 参数（编号 / ID / 名称，与 resolveWorkspace 同规则）。
bool terminalToolNeedsConfirmation(
  String toolName,
  Map<String, Object?> args, {
  List<Workspace> workspaces = const [],
}) {
  switch (toolName) {
    case 'terminal_execute':
      break;
    // stdin 写入可驱动会话里的任意程序（shell 提示符下等同执行命令），
    // 无法静态评级 → 全量审批；其余 action 免审批。
    case 'terminal_session':
      return args['action']?.toString() == 'write';
    default:
      return false;
  }
  final command = args['command']?.toString() ?? '';
  final workspace = _matchWorkspaceArg(args, workspaces);
  if (workspace == null || workspace.scope != WorkspaceScope.project) {
    return !isReadOnlyCommand(command);
  }
  return evaluateCommandRisk(command, root: workspace.root) !=
      CommandRisk.safeInRoot;
}

/// 高危终端调用（提权/换根、命中黑名单、递归强删，见
/// [isHighRiskCommand]）必须逐条审批 —— 白名单/免确认窗口/auto 模式
/// 均不覆盖；其余命令可被预授权放行。
bool terminalCommandIsHighRisk(String toolName, Map<String, Object?> args) {
  switch (toolName) {
    case 'terminal_execute':
      return isHighRiskCommand(args['command']?.toString() ?? '');
    // stdin 写入可驱动会话里的任意程序，按命令同标准评级。
    case 'terminal_session':
      if (args['action']?.toString() != 'write') return false;
      return isHighRiskCommand(args['input']?.toString() ?? '');
  }
  return false;
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
/// [onOutput]（命令类工具）每到一块输出即回调，供 UI 实时展示。
Future<McpToolResult> runTerminalTool(
  Ref ref,
  String toolName,
  Map<String, Object?> args, {
  Future<void>? cancelSignal,
  void Function(String chunk)? onOutput,
}) async {
  try {
    switch (toolName) {
      case 'terminal_execute':
        return await _execute(
          ref,
          args,
          cancelSignal: cancelSignal,
          onOutput: onOutput,
        );
      case 'terminal_session':
        switch (requireString(args, 'action')) {
          case 'list':
            return await _sessionList(ref, args);
          case 'output':
            return await _sessionOutput(ref, args);
          case 'write':
            return await _sessionWrite(ref, args);
          case 'interrupt':
            return await _sessionInterrupt(ref, args);
          case 'close':
            return await _sessionClose(ref, args);
        }
        return fileEditorError(
          '未知的 action: ${args['action']}'
          '（支持 list / output / write / interrupt / close）',
        );
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
    this.greeting,
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

  /// 新建会话时注入的初始化命令（内置终端的 PS1 + 横幅，与用户终端
  /// tab 一致）；远程后端不动对方 shell 配置，为 null。
  final String? greeting;
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
      greeting: workspace.backendType == WorkspaceBackendType.prootLocal
          ? buildProotGreeting(name: workspace.name, root: workspace.root)
          : null,
      environment: {
        // 非交互环境兜底（只注 AI 会话）：git 要凭据/编辑器快速失败、
        // pager 不分页，apt 非交互，避免没必要的交互挂住。
        ...kAgentNonInteractiveEnv,
        if (workspace.scope == WorkspaceScope.project) ...{
          'WORKSPACE_ROOT': workspace.root,
          'WORKSPACE_NAME': workspace.name,
          // L2 语言级隔离（设计稿 §4 P5）：独立 HOME 按工作区隔离
          // rc 文件 / 全局配置 / 缓存。
          if (workspace.isolatedHomePath != null)
            'HOME': workspace.isolatedHomePath!,
        },
        // Android 共享存储（FUSE/sdcardfs）不支持符号链接，npm 装
        // bin 链接必然 EACCES；注入等效于 --no-bin-links 的环境变量，
        // npm/pnpm 都识别 npm_config_* 形式。
        if (_isSharedStoragePath(workspace.root))
          'npm_config_bin_links': 'false',
      },
    );
  } else {
    target = _ExecTarget(
      backend: ref.read(prootLocalBackendProvider),
      label: '内置终端',
      environment: kAgentNonInteractiveEnv,
      greeting: buildProotGreeting(name: '内置终端', root: '/root'),
    );
  }
  if (target.backend is ProotLocalBackend &&
      !await TerminalEngineManager.instance.isInstalled()) {
    throw const FileEditorError('内置终端环境未安装。请让用户在「工作区 → 打开文件夹 → 内置终端」里完成安装后再试。');
  }
  return target;
}

/// Whether [path] lives on Android shared storage, where the underlying
/// FUSE/sdcardfs filesystem rejects symlinks (breaks npm bin links etc.).
bool _isSharedStoragePath(String path) =>
    path.startsWith('/storage/emulated/') || path.startsWith('/sdcard');

/// 命中黑名单的命令统一拦截（设计文档 §3）；只管 AI 通道，用户在交互式
/// 终端里手动执行不受限。
McpToolResult? _guardCommand(String command) {
  final reason = blockedCommandReason(command);
  if (reason == null) return null;
  return fileEditorError('命令被安全黑名单拦截（$reason），未执行。如确需执行，请让用户在终端里手动运行。');
}

/// terminal_execute —— 默认跑在长驻默认会话里（IDE 体验：cd / 环境变量跨
/// 命令保留，终端页可联动围观）。传 session（名字/ID）时在指定会话里
/// 执行，不存在则以该名字自动新建（tmux new -A 语义），不需要单独的
/// create 步骤。
Future<McpToolResult> _execute(
  Ref ref,
  Map<String, Object?> args, {
  Future<void>? cancelSignal,
  void Function(String chunk)? onOutput,
}) async {
  final command = requireString(args, 'command');
  final blocked = _guardCommand(command);
  if (blocked != null) return blocked;
  final manager = ref.read(workspaceSessionPoolManagerProvider);
  // 兼容旧参数名 session_id。
  final sessionRef =
      optionalString(args, 'session') ?? optionalString(args, 'session_id');
  final PooledWorkspaceSession session;
  if (sessionRef != null) {
    session =
        _findSession(
          manager,
          sessionRef,
          workspaceId: await _scopedWorkspaceId(ref, args),
          scopeStrict: true,
        ) ??
        await _createNamedSession(ref, args, sessionRef);
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
          greeting: target.greeting,
        );
  }
  // 会话里 cwd 是 shell 状态；显式传 cwd 时先 cd 过去再执行。
  final cwd = optionalString(args, 'cwd');
  final effective = (cwd == null || cwd.isEmpty)
      ? command
      : "cd '${cwd.replaceAll("'", r"'\''")}' && $command";
  final requestedMs = optionalInt(args, 'timeout_ms') ?? _kDefaultTimeoutMs;
  final timeoutMs = (requestedMs > 0 ? requestedMs : _kDefaultTimeoutMs).clamp(
    1,
    kTerminalMaxTimeoutMs,
  );
  final result = await session.exec(
    effective,
    timeout: Duration(milliseconds: timeoutMs),
    cancelSignal: cancelSignal,
    onOutput: onOutput,
  );
  return fileEditorOk({
    'command': command,
    'workspace': session.workspaceLabel,
    'sessionId': session.id,
    if (cwd != null && cwd.isNotEmpty) 'cwd': cwd,
    'exitCode': result.exitCode,
    'timedOut': result.timedOut,
    'canceled': result.canceled,
    'waitingInput': result.waitingInput,
    if (result.waitingInput)
      'hint':
          '命令疑似在等交互输入（未结束，仍在会话里跑，会话保持占用）：'
          '看 stdout 尾部的提示，用 terminal_session action=write 往 stdin '
          '写入回答（需要回车确认就在末尾带 \n）；action=output 可回看'
          '后续输出。如果判断不需要交互，可继续用 action=output 等它跑完。'
    else if (result.timedOut)
      'hint':
          '命令超时未结束，仍在会话里继续跑（该会话在其结束前保持占用）；'
          '可用 terminal_session action=output 回看进度，若它在等交互输入可用 '
          'action=write 写 stdin；需要并行执行其他命令请传新的 session 名字。'
    else if (result.canceled)
      'hint': '命令被用户中断（已向会话发 Ctrl-C），会话仍可继续使用。',
    'stdout': _clipExecOutput(result.output),
    'stderr': '',
  });
}

/// 按 ID 或名称查会话（名称重名时取最近使用的一个）。
///
/// [scopeStrict]（执行类调用）：ID 和名称都限定在 [workspaceId] 对应的
/// 会话池内（未传 workspace 参数时为内置终端的 null 池）——会话 name
/// 与全局 ID（s1/s2…）共用命名空间，若 ID 查找不受 workspace 约束，
/// 模型传的名字可能碰巧命中另一个工作区的会话 ID，命令就会跑到
/// 错误的工作区 / 远端主机上。
///
/// 非 strict（output / write / interrupt / close 等只读或已有 HITL 的
/// 会话操作）：未传 workspace 参数时 ID 保持全局直达、名称全局查找；
/// 传了则同样限定在该工作区池内。
PooledWorkspaceSession? _findSession(
  WorkspaceSessionPoolManager manager,
  String ref, {
  required String? workspaceId,
  bool scopeStrict = false,
}) {
  final scoped = scopeStrict || workspaceId != null;
  final byId = manager.find(ref);
  if (byId != null && (!scoped || byId.workspaceId == workspaceId)) {
    return byId;
  }
  PooledWorkspaceSession? match;
  for (final s in manager.allSessions()) {
    if (scoped && s.workspaceId != workspaceId) continue;
    if (s.name == ref &&
        (match == null || s.lastUsedAt.isAfter(match.lastUsedAt))) {
      match = s;
    }
  }
  return match;
}

/// `workspace` 参数存在时解析为工作区 ID（会话级工具的隔离边界），
/// 未传时返回 null（不限定）。
Future<String?> _scopedWorkspaceId(Ref ref, Map<String, Object?> args) async {
  if (optionalString(args, 'workspace') == null) return null;
  return (await resolveWorkspace(ref, args)).workspace.id;
}

/// session 参数指向的会话不存在 → 以该名字自动新建（tmux new -A 语义）。
Future<PooledWorkspaceSession> _createNamedSession(
  Ref ref,
  Map<String, Object?> args,
  String name,
) async {
  final target = await _resolveTarget(ref, args);
  return ref
      .read(workspaceSessionPoolManagerProvider)
      .poolFor(
        target.backend,
        workspaceLabel: target.label,
        workspaceId: target.workspaceId,
      )
      .create(
        name: name,
        workingDirectory: optionalString(args, 'cwd') ?? target.defaultCwd,
        environment: target.environment,
        greeting: target.greeting,
      );
}

Future<McpToolResult> _sessionList(Ref ref, Map<String, Object?> args) async {
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

/// 解析 output / write / interrupt / close 的目标会话（session_id 参数
/// 兼容会话名称，与 terminal_execute 的 session 参数对称）。
Future<PooledWorkspaceSession?> _resolveSessionArg(
  Ref ref,
  Map<String, Object?> args,
  String sessionRef,
) async {
  return _findSession(
    ref.read(workspaceSessionPoolManagerProvider),
    sessionRef,
    workspaceId: await _scopedWorkspaceId(ref, args),
  );
}

Future<McpToolResult> _sessionOutput(Ref ref, Map<String, Object?> args) async {
  final sessionId = requireString(args, 'session_id');
  final session = await _resolveSessionArg(ref, args, sessionId);
  if (session == null) {
    return fileEditorError(
      '没有找到会话 $sessionId（可用 terminal_session action=list 查看）',
    );
  }
  final tail = optionalInt(args, 'tail_chars') ?? 4000;
  return fileEditorOk({
    'sessionId': session.id,
    'workspace': session.workspaceLabel,
    'busy': session.busy,
    'output': session.tailOutput(tail > 0 ? tail : 4000),
  });
}

/// write 的 keys 参数支持的特殊按键 → 控制序列（驱动箭头选择器 /
/// TUI，设计稿 §3.4：纯文本 stdin 无法表达方向键与控制组合键）。
const Map<String, String> _kWriteKeySequences = {
  'enter': '\r',
  'tab': '\t',
  'space': ' ',
  'esc': '\x1b',
  'backspace': '\x7f',
  'up': '\x1b[A',
  'down': '\x1b[B',
  'right': '\x1b[C',
  'left': '\x1b[D',
  'ctrl-c': '\x03',
  'ctrl-d': '\x04',
  'ctrl-z': '\x1a',
};

/// 往长驻会话的运行中进程写 stdin（交互式程序输入，设计稿 §3.4）。
/// 传 input 写文本；传 keys 发特殊按键序列（两者可同时传，先 input 后 keys）。
Future<McpToolResult> _sessionWrite(Ref ref, Map<String, Object?> args) async {
  final sessionId = requireString(args, 'session_id');
  final session = await _resolveSessionArg(ref, args, sessionId);
  if (session == null) {
    return fileEditorError(
      '没有找到会话 $sessionId（可用 terminal_session action=list 查看）',
    );
  }
  final input = optionalString(args, 'input');
  final rawKeys = args['keys'];
  final keys = rawKeys is List ? rawKeys.map((k) => '$k').toList() : null;
  if ((input == null || input.isEmpty) && (keys == null || keys.isEmpty)) {
    return fileEditorError('write 需要 input（文本）或 keys（特殊按键）参数');
  }
  if (input != null && input.isNotEmpty) {
    // stdin 在提示符下等同执行命令，黑名单同样生效，堵住绕过
    // terminal_execute 拦截的口子（用户手动输入不受限）。
    final blocked = _guardCommand(input);
    if (blocked != null) return blocked;
    final pressEnter =
        args['press_enter'] != false && (keys == null || keys.isEmpty);
    session.writeInput(
      pressEnter && !input.endsWith('\n') ? '$input\n' : input,
    );
  }
  if (keys != null && keys.isNotEmpty) {
    final buf = StringBuffer();
    for (final key in keys) {
      final seq = _kWriteKeySequences[key.toLowerCase()];
      if (seq == null) {
        return fileEditorError(
          '不支持的按键：$key（支持 ${_kWriteKeySequences.keys.join(' / ')}）',
        );
      }
      buf.write(seq);
    }
    session.writeInput(buf.toString());
  }
  return fileEditorOk({
    'sessionId': session.id,
    'workspace': session.workspaceLabel,
    'written': true,
    'hint': '已写入 stdin；可用 terminal_session action=output 回看进程响应。',
  });
}

/// 向会话发 Ctrl-C 中断当前前台命令（会话保活）：命令跑飞 / 等交互
/// 答错时 AI 的自救手段，避免会话永久 busy。
Future<McpToolResult> _sessionInterrupt(
  Ref ref,
  Map<String, Object?> args,
) async {
  final sessionId = requireString(args, 'session_id');
  final session = await _resolveSessionArg(ref, args, sessionId);
  if (session == null) {
    return fileEditorError(
      '没有找到会话 $sessionId（可用 terminal_session action=list 查看）',
    );
  }
  session.interrupt();
  return fileEditorOk({
    'sessionId': session.id,
    'workspace': session.workspaceLabel,
    'interrupted': true,
    'hint':
        '已向会话发 Ctrl-C；可用 terminal_session action=output 确认命令'
        '已退出。若程序不响应 SIGINT，可用 action=close 直接关掉会话。',
  });
}

/// 关闭会话（终止其 shell 进程）：释放池位，避免跑飞的命令把会话池
/// 占满后 AI 无法再执行任何命令。
Future<McpToolResult> _sessionClose(Ref ref, Map<String, Object?> args) async {
  final sessionId = requireString(args, 'session_id');
  final session = await _resolveSessionArg(ref, args, sessionId);
  if (session == null) {
    return fileEditorError(
      '没有找到会话 $sessionId（可用 terminal_session action=list 查看）',
    );
  }
  await ref.read(workspaceSessionPoolManagerProvider).close(session.id);
  return fileEditorOk({
    'sessionId': session.id,
    'workspace': session.workspaceLabel,
    'closed': true,
  });
}
