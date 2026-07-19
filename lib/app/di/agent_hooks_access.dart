// 智能体 Hooks 执行层（Hooks H2/H3，阶段 5.5 自 agent_runtime_access 拆出）。
//
// 纯逻辑（事件/配置解析/退出协议/stdin JSON/stderr 拆分）在
// `features/agent/domain/agent_hooks.dart`；本文件放需要跨 feature
// 组装的执行与接线：配置加载（手动 hooks + 已信任的工作区
// hooks.json）、hook 命令经 terminal_execute 执行、工具执行器装饰层、
// userPromptSubmit hooks。因依赖 chat 侧工具路由（agent 与 chat 互不
// import 的架构硬约束），与 DI 同层放在 `app/di`。

import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_hooks_trust.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_manual_hooks.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_executor.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_hooks.dart';
import 'package:aetherlink_flutter/features/agent/domain/permission_request.dart';
import 'package:aetherlink_flutter/features/agent/domain/shell_command_patterns.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/terminal/terminal_tools.dart';

/// 读工作区根目录下的配置文件（`.aetherlink/permissions.json` /
/// `.aetherlink/hooks.json`）；不存在或读取失败返回 null。
Future<String?> readWorkspaceConfigFile(
  Ref ref,
  Workspace bound,
  String relative,
) async {
  try {
    final root = bound.root.endsWith('/')
        ? bound.root.substring(0, bound.root.length - 1)
        : bound.root;
    final path = '$root/$relative';
    final backend = await backendForPath(ref, path);
    return await backend.readFile(path);
  } catch (_) {
    return null;
  }
}

Map<String, Object?> decodeToolArgsJson(String argsJson) {
  try {
    final decoded = jsonDecode(argsJson);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  return const <String, Object?>{};
}

/// 工具调用 → 权限域：内置工具用工具名（write / terminal_execute …，
/// 规则/hook 可用 `terminal_*` 这类通配整组）；外部 MCP 工具用
/// `mcp:<server>/<tool>`（可用 `mcp:*` 整体管控）。审批门与 hooks 共用。
String permissionOfToolRoute(ToolRoute route, String toolName) {
  if (route is RemoteToolRoute) return 'mcp:${route.server.name}/$toolName';
  if (route is StdioToolRoute) return 'mcp:${route.server.name}/$toolName';
  return toolName;
}

/// 工具调用 → 参与判定的 patterns：终端命令按子命令拆分（注入特征
/// 退化为整条原文），文件编辑取路径参数，其余按整工具（`*`）。
List<String> patternsOfToolCall(
  ToolRoute route,
  String toolName,
  Map<String, Object?> args,
) {
  if (route is TerminalToolRoute) {
    final command = terminalCommandText(toolName, args);
    if (command != null) return terminalPermissionPatterns(command);
    return const ['*'];
  }
  if (route is FileEditorToolRoute) return fileEditorPermissionPatterns(args);
  return const ['*'];
}

/// hooks 配置的统一加载（执行器与 userPromptSubmit 共用）：设置页
/// 手动添加的 hooks（天然可信，不走文件信任门槛）+ 已信任的工作区
/// hooks.json（内容必须与用户已信任的原文一致，防恶意仓库携带 hooks
/// 直接拿到执行权）。两者均无 → config 为 null。
Future<({AgentHooksConfig? config, String? root})> loadAgentHooksConfig(
  Ref ref,
  String? workspaceId,
) async {
  final manual = [
    for (final m in ref.read(agentManualHooksProvider))
      if (m.enabled) m.hook,
  ];
  AgentHooksConfig? fileConfig;
  String? root;
  if (workspaceId != null && workspaceId.isNotEmpty) {
    try {
      final workspaces = await loadWorkspaces(ref);
      final bound = workspaces.where((w) => w.id == workspaceId).firstOrNull;
      if (bound != null) {
        root = bound.root;
        final raw =
            await readWorkspaceConfigFile(ref, bound, '.aetherlink/hooks.json');
        if (raw != null &&
            raw.trim().isNotEmpty &&
            ref.read(agentHooksTrustProvider)[workspaceId] == raw) {
          fileConfig = decodeAgentHooksConfig(raw);
        }
      }
    } catch (_) {}
  }
  final hooks = [...manual, ...?fileConfig?.hooks];
  return (
    config: hooks.isEmpty ? null : AgentHooksConfig(hooks: hooks),
    root: root,
  );
}

/// preToolUse / postToolUse hooks 的执行器装饰层（Hooks H2）。
///
/// hook 命令经 terminal_execute 跑在绑定工作区的长驻会话里，
/// 退出协议见 [interpretAgentHookExit]：preToolUse 阻断时本次调用
/// 不执行（阻断原因作为失败结果回给模型）；postToolUse 阻断时
/// 把反馈追加进工具结果（如格式化/编译报错）。
class HookedAgentToolExecutor implements AgentToolExecutor {
  HookedAgentToolExecutor(
    this._refOf,
    this._inner,
    this._routes, {
    String? boundWorkspaceId,
  }) : _boundWorkspaceId = boundWorkspaceId;

  final Ref Function() _refOf;
  final AgentToolExecutor _inner;
  final Map<String, ToolRoute> _routes;
  final String? _boundWorkspaceId;

  AgentHooksConfig? _config;
  bool _configLoaded = false;
  String? _workspaceRoot;

  /// preToolUse 裁决缓存：审批门先跑一遍，执行器复用后移除，
  /// 保证同一次调用 hooks 只执行一次。
  final Map<String, AgentHookResult> _preVerdicts = {};

  String _verdictKey(AgentToolCallRequest call) =>
      '${call.name}\u0000${call.argsJson}';

  /// preToolUse hooks 的聚合裁决（审批门与执行器共用）：优先级
  /// block > ask > allow > proceed；block 时携带回给模型的原因。
  /// 无 hooks 配置或无命中时返回 null / proceed。
  Future<AgentHookResult?> preToolUseVerdict(AgentToolCallRequest call) async {
    final key = _verdictKey(call);
    final cached = _preVerdicts[key];
    if (cached != null) return cached;
    final config = await _hooks();
    if (config == null || config.isEmpty) return null;

    final route = _routes[call.name];
    final args = decodeToolArgsJson(call.argsJson);
    final permission =
        route == null ? call.name : permissionOfToolRoute(route, call.name);
    final patterns = route == null
        ? const <String>['*']
        : patternsOfToolCall(route, call.name, args);
    final path = args['path'];
    final filePath = path is String && path.isNotEmpty ? path : null;

    AgentHookResult? aggregate;
    final contexts = <String>[];
    for (final hook in hooksForToolCall(
        config, AgentHookEvent.preToolUse, permission, patterns)) {
      final result = await _runHook(hook,
          eventName: AgentHookEvent.preToolUse.name,
          toolName: call.name,
          argsJson: call.argsJson,
          filePath: filePath);
      if (result.additionalContext.isNotEmpty) {
        contexts.add(result.additionalContext);
      }
      if (result.outcome == AgentHookOutcome.block) {
        aggregate = AgentHookResult(
          outcome: AgentHookOutcome.block,
          message: result.message.isEmpty
              ? 'hook（${hook.command}）拦截了本次调用。'
              : result.message,
        );
        break;
      }
      if (result.outcome == AgentHookOutcome.ask) {
        aggregate = result;
      } else if (result.outcome == AgentHookOutcome.allow &&
          aggregate?.outcome != AgentHookOutcome.ask) {
        aggregate = result;
      }
    }
    final base =
        aggregate ?? const AgentHookResult(outcome: AgentHookOutcome.proceed);
    final verdict = contexts.isEmpty
        ? base
        : AgentHookResult(
            outcome: base.outcome,
            message: base.message,
            additionalContext: contexts.join('\n'),
          );
    _preVerdicts[key] = verdict;
    return verdict;
  }

  /// hooks 配置（任务运行内只读一次），见 [loadAgentHooksConfig]。
  Future<AgentHooksConfig?> _hooks() async {
    if (_configLoaded) return _config;
    _configLoaded = true;
    if (_boundWorkspaceId == null) return null;
    final loaded = await loadAgentHooksConfig(_refOf(), _boundWorkspaceId);
    _workspaceRoot = loaded.root;
    _config = loaded.config;
    return _config;
  }

  @override
  Future<AgentToolResult> execute(
    AgentToolCallRequest call,
    AgentCancellationToken cancel,
  ) async {
    final config = await _hooks();
    if (config == null || config.isEmpty) return _inner.execute(call, cancel);

    final route = _routes[call.name];
    final args = decodeToolArgsJson(call.argsJson);
    final permission =
        route == null ? call.name : permissionOfToolRoute(route, call.name);
    final patterns = route == null
        ? const <String>['*']
        : patternsOfToolCall(route, call.name, args);

    final path = args['path'];
    final filePath = path is String && path.isNotEmpty ? path : null;
    final preVerdict = await preToolUseVerdict(call);
    _preVerdicts.remove(_verdictKey(call));
    if (preVerdict != null && preVerdict.outcome == AgentHookOutcome.block) {
      return AgentToolResult(
        ok: false,
        summary: '被 preToolUse hook 拦截 ✗',
        detail: preVerdict.message.isEmpty
            ? 'preToolUse hook 拦截了本次调用。'
            : preVerdict.message,
      );
    }

    final toolResult = await _inner.execute(call, cancel);
    final postEvent = toolResult.ok
        ? AgentHookEvent.postToolUse
        : AgentHookEvent.postToolUseFailure;

    final feedback = <String>[];
    final contexts = <String>[
      if (preVerdict != null && preVerdict.additionalContext.isNotEmpty)
        preVerdict.additionalContext,
    ];
    for (final hook
        in hooksForToolCall(config, postEvent, permission, patterns)) {
      final result = await _runHook(hook,
          eventName: postEvent.name,
          toolName: call.name,
          argsJson: call.argsJson,
          filePath: filePath,
          toolOutput: toolResult.detail ?? toolResult.summary,
          toolOk: toolResult.ok);
      if (result.additionalContext.isNotEmpty) {
        contexts.add(result.additionalContext);
      }
      if (result.outcome == AgentHookOutcome.block) {
        feedback.add(result.message.isEmpty
            ? 'hook（${hook.command}）报告了问题（无输出）。'
            : result.message);
      }
    }
    if (feedback.isEmpty && contexts.isEmpty) return toolResult;
    final sections = [
      if (feedback.isNotEmpty)
        '[${postEvent.name} hook 反馈]\n${feedback.join('\n')}',
      if (contexts.isNotEmpty)
        '[hook additionalContext]\n${contexts.join('\n')}',
    ];
    return AgentToolResult(
      ok: toolResult.ok,
      summary: toolResult.summary,
      detail: '${toolResult.detail ?? ''}\n\n${sections.join('\n\n')}',
      overflowPath: toolResult.overflowPath,
    );
  }

  /// 任务收尾前跑 stop hooks（引擎 stopGuard）：任一 hook 阻断则返回
  /// 阻断原因（收尾被阻止，原因回填继续跑），全部放行/失败返回 null。
  /// stop hook 不按工具匹配，matcher/pattern 忽略。
  /// 生命周期事件 hooks（taskStart / turnStart / turnEnd）：
  /// fire-and-forget，不阻断任务。
  Future<void> runLifecycleHooks(AgentHookEvent event) async {
    try {
      final config = await _hooks();
      if (config == null) return;
      for (final hook in config.ofEvent(event)) {
        await _runHook(hook,
            eventName: event.name, toolName: event.name, argsJson: '{}');
      }
    } catch (_) {}
  }

  Future<String?> runStopHooks() async {
    final config = await _hooks();
    if (config == null) return null;
    for (final hook in config.ofEvent(AgentHookEvent.stop)) {
      final result = await _runHook(hook,
          eventName: AgentHookEvent.stop.name,
          toolName: 'stop',
          argsJson: '{}');
      if (result.outcome == AgentHookOutcome.block) {
        return result.message.isEmpty
            ? 'hook（${hook.command}）阻止了收尾。'
            : result.message;
      }
    }
    return null;
  }

  /// 在绑定工作区里跑一条 hook 命令（委托 [_execHookCommand]）。
  Future<AgentHookResult> _runHook(
    AgentHook hook, {
    required String eventName,
    required String toolName,
    required String argsJson,
    String? filePath,
    String? toolOutput,
    bool? toolOk,
  }) =>
      _execHookCommand(
        _refOf(),
        hook,
        eventName: eventName,
        toolName: toolName,
        argsJson: argsJson,
        filePath: filePath,
        toolOutput: toolOutput,
        toolOk: toolOk,
        workspaceId: _boundWorkspaceId,
        cwd: _workspaceRoot,
      );
}

/// userPromptSubmit hooks（任务运行器在用户消息进入任务前调用）：
/// 配置来源与执行器一致（[loadAgentHooksConfig]）。任一 hook block →
/// 返回 block 裁决（消息应被拦截）；各 hook 的 additionalContext 合并
/// 返回；无 hooks 配置/无命中且无注入 → null。
Future<AgentHookResult?> runUserPromptSubmitHooks(
  Ref ref, {
  required String workspaceId,
  required String prompt,
}) async {
  final loaded = await loadAgentHooksConfig(ref, workspaceId);
  final config = loaded.config;
  if (config == null) return null;
  final contexts = <String>[];
  for (final hook in config.ofEvent(AgentHookEvent.userPromptSubmit)) {
    final result = await _execHookCommand(
      ref,
      hook,
      eventName: AgentHookEvent.userPromptSubmit.name,
      toolName: '',
      argsJson: '{}',
      prompt: prompt,
      workspaceId: workspaceId.isEmpty ? null : workspaceId,
      cwd: loaded.root,
    );
    if (result.outcome == AgentHookOutcome.block) {
      return AgentHookResult(
        outcome: AgentHookOutcome.block,
        message: result.message.isEmpty
            ? 'hook（${hook.command}）拦截了本条消息。'
            : result.message,
      );
    }
    if (result.additionalContext.isNotEmpty) {
      contexts.add(result.additionalContext);
    }
  }
  if (contexts.isEmpty) return null;
  return AgentHookResult(
    outcome: AgentHookOutcome.proceed,
    additionalContext: contexts.join('\n'),
  );
}

/// 跑一条 hook 命令：现场上下文两路传入——
/// ① stdin JSON（字段命名对齐 Claude Code，见
/// [buildAgentHookStdinJson]）；② 环境变量（AETHER_TOOL /
/// AETHER_ARGS_JSON / AETHER_FILE_PATH / AETHER_PROMPT，post 事件另有
/// AETHER_TOOL_OUTPUT / AETHER_TOOL_OK）。超时/异常按 hook 自身
/// 失败处理（不阻断）。
Future<AgentHookResult> _execHookCommand(
  Ref ref,
  AgentHook hook, {
  required String eventName,
  required String toolName,
  required String argsJson,
  String? filePath,
  String? toolOutput,
  bool? toolOk,
  String? prompt,
  String? workspaceId,
  String? cwd,
}) async {
  try {
    final cappedArgs =
        argsJson.length > 4000 ? argsJson.substring(0, 4000) : argsJson;
    final cappedOutput = toolOutput != null && toolOutput.length > 4000
        ? toolOutput.substring(0, 4000)
        : toolOutput;
    final cappedPrompt = prompt != null && prompt.length > 4000
        ? prompt.substring(0, 4000)
        : prompt;
    final exports = [
      'export AETHER_TOOL=${_shellQuote(toolName)}',
      'export AETHER_ARGS_JSON=${_shellQuote(cappedArgs)}',
      if (filePath != null && filePath.isNotEmpty)
        'export AETHER_FILE_PATH=${_shellQuote(filePath)}',
      if (cappedOutput != null)
        'export AETHER_TOOL_OUTPUT=${_shellQuote(cappedOutput)}',
      if (toolOk != null)
        'export AETHER_TOOL_OK=${toolOk ? 'true' : 'false'}',
      if (cappedPrompt != null)
        'export AETHER_PROMPT=${_shellQuote(cappedPrompt)}',
    ].join('; ');
    var stdinJson = buildAgentHookStdinJson(
      eventName: eventName,
      toolName: toolName,
      argsJson: argsJson,
      filePath: filePath,
      toolOutput: toolOutput,
      toolOk: toolOk,
      prompt: prompt,
      sessionId: workspaceId,
      cwd: cwd,
    );
    // 命令行长度保险：超长时退化为不含 tool_input 原文的精简版。
    if (stdinJson.length > 60000) {
      stdinJson = buildAgentHookStdinJson(
        eventName: eventName,
        toolName: toolName,
        argsJson: '{}',
        filePath: filePath,
        toolOutput: cappedOutput,
        toolOk: toolOk,
        prompt: cappedPrompt,
        sessionId: workspaceId,
        cwd: cwd,
      );
    }
    // stderr 经临时文件 + 标记行回传（终端后端合流，见
    // [kAgentHookStderrMarker]）；末尾子 shell 把 hook 退出码透传回来。
    final result = await runTerminalTool(ref, 'terminal_execute', {
      'command': '__ahs="\${TMPDIR:-/tmp}/.aether_hook_stderr.\$\$"; '
          '$exports; printf %s ${_shellQuote(stdinJson)} | '
          '( ${hook.command} ) 2>"\$__ahs"; __ahc=\$?; '
          "printf '\\n%s\\n' ${_shellQuote(kAgentHookStderrMarker)}; "
          'cat "\$__ahs" 2>/dev/null; rm -f "\$__ahs"; ( exit \$__ahc )',
      'workspace': workspaceId,
      'timeout_ms': hook.timeoutSeconds * 1000,
    });
    return _interpretTerminalResult(result);
  } catch (e) {
    return AgentHookResult(
      outcome: AgentHookOutcome.failed,
      message: 'hook 执行异常：$e',
    );
  }
}

/// terminal_execute 结果（`{success, data: {exitCode, stdout, timedOut…}}`）
/// → hook 退出协议。
AgentHookResult _interpretTerminalResult(McpToolResult result) {
  try {
    final decoded = jsonDecode(result.text);
    if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
      return AgentHookResult(
        outcome: AgentHookOutcome.failed,
        message: result.text,
      );
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      return const AgentHookResult(outcome: AgentHookOutcome.failed);
    }
    if (data['timedOut'] == true || data['canceled'] == true) {
      return const AgentHookResult(
        outcome: AgentHookOutcome.failed,
        message: 'hook 超时/被中断',
      );
    }
    final exitCode = data['exitCode'];
    final stdout = data['stdout'];
    final split = splitAgentHookOutput(stdout is String ? stdout : '');
    return interpretAgentHookExit(
      exitCode is int ? exitCode : 0,
      split.stdout,
      split.stderr,
    );
  } catch (e) {
    return AgentHookResult(
      outcome: AgentHookOutcome.failed,
      message: 'hook 结果解析失败：$e',
    );
  }
}

String _shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";
