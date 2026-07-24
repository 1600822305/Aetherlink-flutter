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

  /// 审批弹窗弹出前（对标 Claude Code PermissionRequest）：可
  /// allow（免审放行，越 root 硬约束不可覆盖）/ block（强制拒绝，
  /// 按策略禁止处理）/ ask（照常审批）。仅在本要弹审批时触发。
  permissionRequest,

  /// 审批被拒绝后（对标 Claude Code PermissionDenied，观测型不阻断）；
  /// 拒绝原因经 `tool_response` 传入。
  permissionDenied,

  /// 需要用户注意的时刻（对标 Claude Code Notification，观测型
  /// 不阻断）：审批挂起 / ask_user 等待时触发，可接外部通知。
  /// matcher 匹配通知类型（approval / question），pattern 忽略；
  /// 消息经 `message` / `notification_type` 传入。
  notification,

  /// 每轮结束（本轮工具全部执行完，不阻断）。
  turnEnd,

  /// 任务将要完成前：可阻止收尾并把原因作为新输入续跑（收尾校验）。
  stop,

  /// 子智能体启动时（不阻断，只观测）。
  subagentStart,

  /// 子智能体将要收尾前：可阻止收尾并把原因作为新输入续跑
  /// （对标 Claude Code 的 SubagentStop）。
  subagentStop,

  /// 主任务正常结束后（不阻断，只观测）。
  taskEnd,

  /// 上下文压缩前（对标 Claude Code PreCompact，观测型不阻断）；
  /// matcher 匹配触发方式（目前仅 auto），pattern 忽略。
  preCompact,

  /// 上下文压缩后（对标 Claude Code PostCompact，观测型不阻断）；
  /// 压缩摘要经 `tool_response` 传入；matcher 匹配触发方式（目前仅
  /// auto），pattern 忽略。
  postCompact,

  /// 工作区文件变更时（对标 Claude Code FileChanged，观测型不阻断）：
  /// 后端 watch 流 + 去抖后触发；matcher 匹配变更类型
  /// （created/modified/deleted/moved），pattern 匹配文件路径；
  /// 路径经 `file_path`、变更类型经 `event` 传入。
  fileChanged,
}

/// hook 类型（对标 Claude Code 的 command / prompt / http / agent）。
enum AgentHookType {
  /// shell 命令：跑在任务绑定工作区的终端里，退出协议见
  /// [interpretAgentHookExit]。
  command,

  /// LLM 裁决器：用一次模型调用评估提示词条件，回复协议见
  /// [interpretAgentPromptHookResponse]。
  prompt,

  /// HTTP 回调：把 hook 输入 JSON POST 到 URL，响应协议见
  /// [interpretAgentHttpHookResponse]。
  http,

  /// 智能体校验器：多轮带工具（工作区终端）的小智能体验证
  /// 提示词条件，通过 submit_result 工具交回 {"ok":...} 裁决。
  agent,
}

/// 一条 hook 配置。[matcher] 匹配权限域（工具名 / `mcp:<server>/<tool>`），
/// [pattern] 匹配调用 pattern（终端子命令 / 文件路径），两者语义与
/// 权限规则一致（复用 [permissionWildcardMatch]，`*` 通配）。
/// 按 [type] 取对应载体：command 型用 [command]，prompt / agent 型用
/// [prompt]，http 型用 [url]（+可选 [headers]）。通用可选字段
/// （对标 Claude Code）：[model] 为 prompt / agent 型指定裁决模型
/// （空 = 当前默认模型）；[statusMessage] 为运行中的自定义时间线
/// 文案；[once] 为真时本次任务内只触发一次；[asyncRewake]（command 型）
/// 为真时 hook 直接转后台不阻塞主链，后台跑完若阻断（退出码 2）
/// 把反馈排队注入任务叫醒模型。
class AgentHook {
  const AgentHook({
    required this.event,
    this.type = AgentHookType.command,
    this.matcher = '*',
    this.pattern = '*',
    this.command = '',
    this.prompt = '',
    this.url = '',
    this.headers = const {},
    this.timeoutSeconds = kAgentHookDefaultTimeoutSeconds,
    this.model = '',
    this.statusMessage = '',
    this.once = false,
    this.asyncRewake = false,
  });

  final AgentHookEvent event;
  final AgentHookType type;
  final String matcher;
  final String pattern;
  final String command;
  final String prompt;
  final String url;
  final Map<String, String> headers;
  final int timeoutSeconds;
  final String model;
  final String statusMessage;
  final bool once;
  final bool asyncRewake;

  /// 类型对应的载体（去重键 / 展示用）。
  String get payload => switch (type) {
    AgentHookType.command => command,
    AgentHookType.prompt || AgentHookType.agent => prompt,
    AgentHookType.http => url,
  };

  @override
  String toString() =>
      'AgentHook(${event.name}, ${type.name}, $matcher, $pattern, $payload)';
}

const int kAgentHookDefaultTimeoutSeconds = 30;

/// hooks.json 顶层结构：事件名 → hook 列表。
class AgentHooksConfig {
  const AgentHooksConfig({this.hooks = const []});

  final List<AgentHook> hooks;

  bool get isEmpty => hooks.isEmpty;

  List<AgentHook> ofEvent(AgentHookEvent event) => [
    for (final h in hooks)
      if (h.event == event) h,
  ];
}

/// 解析 hooks.json（`{"preToolUse":[{...}],"postToolUse":[...],"stop":[...]}`）。
/// 每条 hook 用 `type` 字段区分类型（对标 Claude Code 的区分联合）：
/// - `{"type":"command","command":"..."}`
/// - `{"type":"prompt","prompt":"..."}`（`$ARGUMENTS` 占位 hook 输入 JSON）
/// - `{"type":"http","url":"...","headers":{...}}`
/// - `{"type":"agent","prompt":"..."}`（多轮带工具的智能体校验器）
/// 通用可选字段：`model`（prompt/agent 型）、`statusMessage`、`once`、
/// `asyncRewake`（command 型）。
/// 坏 JSON / 非对象返回 null；缺 type、type 未知或缺对应载体的条目
/// 丢弃；stop hook 忽略 matcher/pattern（收尾校验与具体工具无关）。
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
      final hook = decodeAgentHookEntry(event, item);
      if (hook != null) hooks.add(hook);
    }
  }
  return AgentHooksConfig(hooks: hooks);
}

/// 解析单条 hook 配置（hooks.json 与手动 hooks 存储共用）：按
/// `type` 区分联合取对应载体，非法条目返回 null。
AgentHook? decodeAgentHookEntry(
  AgentHookEvent event,
  Map<String, dynamic> item,
) {
  final typeName = item['type'];
  AgentHookType? type;
  for (final t in AgentHookType.values) {
    if (t.name == typeName) type = t;
  }
  if (type == null) return null;
  final payload =
      item[switch (type) {
        AgentHookType.command => 'command',
        AgentHookType.prompt || AgentHookType.agent => 'prompt',
        AgentHookType.http => 'url',
      }];
  if (payload is! String || payload.trim().isEmpty) return null;
  final rawHeaders = item['headers'];
  final headers = <String, String>{
    if (type == AgentHookType.http && rawHeaders is Map<String, dynamic>)
      for (final e in rawHeaders.entries)
        if (e.value is String) e.key: e.value as String,
  };
  final matcher = item['matcher'];
  final pattern = item['pattern'];
  final timeout = item['timeout'];
  final model = item['model'];
  final statusMessage = item['statusMessage'];
  return AgentHook(
    event: event,
    type: type,
    matcher: matcher is String && matcher.isNotEmpty ? matcher : '*',
    pattern: pattern is String && pattern.isNotEmpty ? pattern : '*',
    command: type == AgentHookType.command ? payload : '',
    prompt: type == AgentHookType.prompt || type == AgentHookType.agent
        ? payload
        : '',
    url: type == AgentHookType.http ? payload : '',
    headers: headers,
    timeoutSeconds: timeout is int && timeout > 0
        ? timeout
        : kAgentHookDefaultTimeoutSeconds,
    model:
        (type == AgentHookType.prompt || type == AgentHookType.agent) &&
            model is String
        ? model.trim()
        : '',
    statusMessage: statusMessage is String ? statusMessage.trim() : '',
    once: item['once'] == true,
    asyncRewake: type == AgentHookType.command && item['asyncRewake'] == true,
  );
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
