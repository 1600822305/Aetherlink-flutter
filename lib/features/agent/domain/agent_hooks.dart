// 智能体 Hooks（Hooks 重构 H1，纯 Dart 可单测）。
//
// 对标 Claude Code 的配置式 shell hooks：工作区根目录
// `.aetherlink/hooks.json` 声明「事件 → 匹配器 → 命令」，命令在
// 工作区终端里执行，exit code 决定放行/阻断。本文件只放配置解析、
// 匹配和退出协议的纯逻辑；执行与引擎接线在 H2/H3。

import 'dart:convert';

import 'package:aetherlink_flutter/features/agent/domain/permission_rule.dart';

/// Hook 事件。
enum AgentHookEvent {
  /// 任务启动/续跑时（不阻断，只观测/准备环境）。
  taskStart,

  /// 工具执行前：可阻断本次调用（阻断信息作为工具失败结果回给模型）。
  preToolUse,

  /// 工具成功执行后：可把反馈追加进工具结果（如格式化/编译报错）。
  postToolUse,

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

/// hook 命令执行结果的裁决。
enum AgentHookOutcome {
  /// 放行（exit 0 且无阻断输出）。
  proceed,

  /// 阻断：preToolUse 拦截调用 / postToolUse 回填反馈 / stop 阻止收尾。
  block,

  /// hook 自身失败（超时 / 其他 exit code）：只记日志，不阻断。
  failed,
}

/// hook 裁决 + 回给模型的信息。
class AgentHookResult {
  const AgentHookResult({required this.outcome, this.message = ''});

  final AgentHookOutcome outcome;
  final String message;
}

/// 退出协议（对标 Claude Code）：
/// - exit 2 → block，stderr（为空则 stdout）作为回给模型的原因；
/// - exit 0 → 默认放行；stdout 若是 `{"decision":"block"|"deny",
///   "reason":...}` JSON 也算 block；
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
    if (decision != 'block' && decision != 'deny') return null;
    final reason = decoded['reason'];
    return AgentHookResult(
      outcome: AgentHookOutcome.block,
      message: reason is String ? reason : '',
    );
  } catch (_) {
    return null;
  }
}
