// 智能体 Hooks（Hooks 重构 H1，纯 Dart 可单测）。
//
// 对标 Claude Code 的配置式 shell hooks：工作区根目录
// `.aetherlink/hooks.json` 声明「事件 → 匹配器 → 命令」，命令在
// 工作区终端里执行，exit code 决定放行/阻断。本文件只放配置解析、
// 匹配和退出协议的纯逻辑；执行与引擎接线在 H2/H3。

import 'dart:convert';

import 'package:aetherlink_flutter/features/agent/domain/permission_rule.dart';

/// Hook 事件（生命周期对标 LiveAgent：agent_start / turn_start /
/// tool_execution_start / tool_execution_end / turn_end / agent_end）。
enum AgentHookEvent {
  /// 任务启动/续跑时（不阻断，只观测/准备环境）。
  taskStart,

  /// 用户消息进入任务前：可 block（拦截并给原因）或输出
  /// additionalContext 注入上下文。
  userPromptSubmit,

  /// 每轮开始（LLM 调用前，不阻断）。
  turnStart,

  /// 工具执行前：可阻断本次调用（阻断信息作为工具失败结果回给模型）。
  preToolUse,

  /// 工具成功执行后：可把反馈追加进工具结果（如格式化/编译报错）。
  postToolUse,

  /// 工具执行失败后：可把反馈追加进失败结果（如失败原因分析/补救提示）。
  postToolUseFailure,

  /// 每轮结束（本轮工具全部执行完，不阻断）。
  turnEnd,

  /// 任务将要完成前：可阻止收尾并把原因作为新输入续跑（收尾校验）。
  stop,
}

/// 一条 hook 配置。[matcher] 匹配权限域（工具名 / `mcp:<server>/<tool>`），
/// [pattern] 匹配调用 pattern（终端子命令 / 文件路径），两者语义与
/// 权限规则一致（复用 [permissionWildcardMatch]，`*` 通配）。
class AgentHook {
  const AgentHook({
    required this.event,
    this.matcher = '*',
    this.pattern = '*',
    required this.command,
    this.timeoutSeconds = kAgentHookDefaultTimeoutSeconds,
  });

  final AgentHookEvent event;
  final String matcher;
  final String pattern;
  final String command;
  final int timeoutSeconds;

  @override
  String toString() =>
      'AgentHook(${event.name}, $matcher, $pattern, $command)';
}

const int kAgentHookDefaultTimeoutSeconds = 30;

/// hooks.json 顶层结构：事件名 → hook 列表。
class AgentHooksConfig {
  const AgentHooksConfig({this.hooks = const []});

  final List<AgentHook> hooks;

  bool get isEmpty => hooks.isEmpty;

  List<AgentHook> ofEvent(AgentHookEvent event) =>
      [for (final h in hooks) if (h.event == event) h];
}

/// 解析 hooks.json（`{"preToolUse":[{...}],"postToolUse":[...],"stop":[...]}`）。
/// 坏 JSON / 非对象返回 null；缺 command 或字段类型不对的条目丢弃；
/// stop hook 忽略 matcher/pattern（收尾校验与具体工具无关）。
AgentHooksConfig? decodeAgentHooksConfig(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  final hooks = <AgentHook>[];
  for (final event in AgentHookEvent.values) {
    final list = decoded[event.name];
    if (list is! List) continue;
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final command = item['command'];
      if (command is! String || command.trim().isEmpty) continue;
      final matcher = item['matcher'];
      final pattern = item['pattern'];
      final timeout = item['timeout'];
      hooks.add(AgentHook(
        event: event,
        matcher: matcher is String && matcher.isNotEmpty ? matcher : '*',
        pattern: pattern is String && pattern.isNotEmpty ? pattern : '*',
        command: command,
        timeoutSeconds: timeout is int && timeout > 0
            ? timeout
            : kAgentHookDefaultTimeoutSeconds,
      ));
    }
  }
  return AgentHooksConfig(hooks: hooks);
}

/// 组装 hook 命令的 stdin JSON（字段命名对齐 Claude Code 输入协议：
/// `hook_event_name` / `tool_name` / `tool_input` / `tool_response`）。
/// [argsJson] 可解析时以 JSON 对象嵌入 `tool_input`，否则按原文字符串。
String buildAgentHookStdinJson({
  required String eventName,
  required String toolName,
  required String argsJson,
  String? filePath,
  String? toolOutput,
  bool? toolOk,
  String? prompt,
  String? sessionId,
  String? cwd,
}) {
  Object? toolInput;
  try {
    toolInput = jsonDecode(argsJson);
  } catch (_) {
    toolInput = argsJson;
  }
  return jsonEncode({
    'hook_event_name': eventName,
    if (toolName.isNotEmpty) 'tool_name': toolName,
    if (toolName.isNotEmpty) 'tool_input': toolInput,
    if (prompt != null) 'prompt': prompt,
    if (filePath != null && filePath.isNotEmpty) 'file_path': filePath,
    if (toolOutput != null) 'tool_response': toolOutput,
    if (toolOk != null) 'tool_ok': toolOk,
    if (sessionId != null) 'session_id': sessionId,
    if (cwd != null) 'cwd': cwd,
  });
}

/// 一次工具调用命中的 hooks：matcher 命中权限域，且任一调用 pattern
/// 命中 hook 的 pattern。[patterns] 为空按 `*` 处理（非终端/文件工具）。
List<AgentHook> hooksForToolCall(
  AgentHooksConfig config,
  AgentHookEvent event,
  String permission,
  List<String> patterns,
) {
  final effective = patterns.isEmpty ? const ['*'] : patterns;
  return [
    for (final hook in config.ofEvent(event))
      if (permissionWildcardMatch(permission, hook.matcher) &&
          effective.any((p) => permissionWildcardMatch(p, hook.pattern)))
        hook,
  ];
}

/// hook 命令包装层回传 stderr 用的分隔标记（终端后端 stdout/stderr
/// 合流，包装命令把 stderr 重定向到临时文件，命令结束后紧跟标记行
/// 回放，由 [splitAgentHookOutput] 拆回两路）。
const String kAgentHookStderrMarker = '<<<AETHER_HOOK_STDERR>>>';

/// 拆分 hook 终端合流输出：标记行前为 stdout，标记行后为 stderr；
/// 无标记时全部视为 stdout。
({String stdout, String stderr}) splitAgentHookOutput(String combined) {
  final idx = combined.indexOf(kAgentHookStderrMarker);
  if (idx < 0) return (stdout: combined, stderr: '');
  return (
    stdout: combined.substring(0, idx).trimRight(),
    stderr: combined
        .substring(idx + kAgentHookStderrMarker.length)
        .trim(),
  );
}

/// hook 命令执行结果的裁决。
enum AgentHookOutcome {
  /// 放行（exit 0 且无裁决输出）：不干预审批门。
  proceed,

  /// 阻断：preToolUse 拦截调用 / postToolUse 回填反馈 / stop 阻止收尾。
  block,

  /// 免审放行（仅 preToolUse）：跳过审批门直接执行（对标 CC
  /// permissionDecision: allow；越 root 硬约束不可覆盖）。
  allow,

  /// 强制审批（仅 preToolUse）：即使规则/auto 本已放行也弹审批。
  ask,

  /// hook 自身失败（超时 / 其他 exit code）：只记日志，不阻断。
  failed,
}

/// hook 裁决 + 回给模型的信息。[additionalContext] 为 hook 要注入
/// 对话/工具结果的额外上下文（stdout JSON `additionalContext` 字段，
/// 可与任意裁决同时出现）。
class AgentHookResult {
  const AgentHookResult({
    required this.outcome,
    this.message = '',
    this.additionalContext = '',
  });

  final AgentHookOutcome outcome;
  final String message;
  final String additionalContext;
}

/// 退出协议（对标 Claude Code）：
/// - exit 2 → block，stderr（为空则 stdout）作为回给模型的原因；
/// - exit 0 → 默认放行；stdout 若是 `{"decision":...}` JSON 则按裁决：
///   `"block"|"deny"` → block，`"allow"|"approve"` → allow（免审），
///   `"ask"` → ask（强制审批）；
/// - 其他 exit code → hook 自身失败，不阻断。
AgentHookResult interpretAgentHookExit(
  int exitCode,
  String stdout,
  String stderr,
) {
  if (exitCode == 2) {
    final reason = stderr.trim().isNotEmpty ? stderr.trim() : stdout.trim();
    return AgentHookResult(outcome: AgentHookOutcome.block, message: reason);
  }
  if (exitCode != 0) {
    return AgentHookResult(
      outcome: AgentHookOutcome.failed,
      message: stderr.trim().isNotEmpty ? stderr.trim() : 'exit $exitCode',
    );
  }
  final decision = _decodeDecision(stdout);
  if (decision != null) return decision;
  return const AgentHookResult(outcome: AgentHookOutcome.proceed);
}

AgentHookResult? _decodeDecision(String stdout) {
  final trimmed = stdout.trim();
  if (!trimmed.startsWith('{')) return null;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, dynamic>) return null;
    final decision = decoded['decision'];
    final outcome = switch (decision) {
      'block' || 'deny' => AgentHookOutcome.block,
      'allow' || 'approve' => AgentHookOutcome.allow,
      'ask' => AgentHookOutcome.ask,
      _ => null,
    };
    final context = decoded['additionalContext'];
    final contextStr = context is String ? context : '';
    if (outcome == null) {
      if (contextStr.isEmpty) return null;
      return AgentHookResult(
        outcome: AgentHookOutcome.proceed,
        additionalContext: contextStr,
      );
    }
    final reason = decoded['reason'];
    return AgentHookResult(
      outcome: outcome,
      message: reason is String ? reason : '',
      additionalContext: contextStr,
    );
  } catch (_) {
    return null;
  }
}
