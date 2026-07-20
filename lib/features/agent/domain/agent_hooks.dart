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

  List<AgentHook> ofEvent(AgentHookEvent event) =>
      [for (final h in hooks) if (h.event == event) h];
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
  final payload = item[switch (type) {
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
    model: (type == AgentHookType.prompt || type == AgentHookType.agent) &&
            model is String
        ? model.trim()
        : '',
    statusMessage: statusMessage is String ? statusMessage.trim() : '',
    once: item['once'] == true,
    asyncRewake:
        type == AgentHookType.command && item['asyncRewake'] == true,
  );
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
  String? message,
  String? notificationType,
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
    if (message != null && message.isNotEmpty) 'message': message,
    if (notificationType != null && notificationType.isNotEmpty)
      'notification_type': notificationType,
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
/// 可与任意裁决同时出现）。[preventContinuation] 为 stdout JSON
/// `{"continue":false}`（对标 Claude Code）：终止整个任务，
/// [stopReason] 展示给用户；可与任意裁决同时出现。
/// [isAsync] 为首行输出 `{"async":true}` 的 async hook（对标
/// Claude Code）：不参与裁决（按放行处理），余下输出忽略。
/// [updatedArgsJson] 为 stdout JSON `updatedInput`（对标 Claude
/// Code，仅 preToolUse 生效）：非空时工具改用该入参执行（block
/// 裁决下忽略）。[systemMessage]（对标 Claude Code）为展示给
/// 用户的提示（不进模型上下文）。
class AgentHookResult {
  const AgentHookResult({
    required this.outcome,
    this.message = '',
    this.additionalContext = '',
    this.preventContinuation = false,
    this.stopReason = '',
    this.isAsync = false,
    this.updatedArgsJson = '',
    this.systemMessage = '',
  });

  final AgentHookOutcome outcome;
  final String message;
  final String additionalContext;
  final bool preventContinuation;
  final String stopReason;
  final bool isAsync;
  final String updatedArgsJson;
  final String systemMessage;
}

/// 同一事件多条 hooks（并行执行）的裁决聚合：
/// - outcome 优先级 block > ask > allow > proceed（failed 视为 proceed）；
/// - message 取全部 block 的原因拼接（无 block 时取胜出裁决的 message）；
/// - additionalContext / systemMessage 非空项拼接；
/// - updatedArgsJson 取首个非空（多条 hook 同时改写入参不叠加）；
/// - preventContinuation 任一为 true 即 true，stopReason 取首个非空。
AgentHookResult aggregateAgentHookResults(Iterable<AgentHookResult> results) {
  var outcome = AgentHookOutcome.proceed;
  final blockMessages = <String>[];
  final contexts = <String>[];
  final systemMessages = <String>[];
  var updatedArgsJson = '';
  var prevent = false;
  var stopReason = '';
  String winnerMessage = '';
  for (final r in results) {
    if (r.additionalContext.isNotEmpty) contexts.add(r.additionalContext);
    if (r.systemMessage.isNotEmpty) systemMessages.add(r.systemMessage);
    if (updatedArgsJson.isEmpty && r.updatedArgsJson.isNotEmpty) {
      updatedArgsJson = r.updatedArgsJson;
    }
    if (r.preventContinuation) {
      prevent = true;
      if (stopReason.isEmpty && r.stopReason.isNotEmpty) {
        stopReason = r.stopReason;
      }
    }
    switch (r.outcome) {
      case AgentHookOutcome.block:
        if (outcome != AgentHookOutcome.block) {
          outcome = AgentHookOutcome.block;
        }
        if (r.message.isNotEmpty) blockMessages.add(r.message);
      case AgentHookOutcome.ask:
        if (outcome != AgentHookOutcome.block) {
          outcome = AgentHookOutcome.ask;
          winnerMessage = r.message;
        }
      case AgentHookOutcome.allow:
        if (outcome == AgentHookOutcome.proceed) {
          outcome = AgentHookOutcome.allow;
          winnerMessage = r.message;
        }
      case AgentHookOutcome.proceed:
      case AgentHookOutcome.failed:
        break;
    }
  }
  return AgentHookResult(
    outcome: outcome,
    message: outcome == AgentHookOutcome.block
        ? blockMessages.join('\n')
        : winnerMessage,
    additionalContext: contexts.join('\n'),
    preventContinuation: prevent,
    stopReason: stopReason,
    updatedArgsJson: updatedArgsJson,
    systemMessage: systemMessages.join('\n'),
  );
}

/// hooks 运行状态写入任务时间线的通道：以「运行中」文案落一条状态
/// 事件，返回原位覆盖该条文案的更新函数（hooks 跑完后改写为结果）。
typedef AgentHookTimelineSink = Future<void Function(String line)> Function(
  String line,
);

/// asyncRewake 反馈注入任务的通道：后台 hook 阻断（退出码 2）时把
/// 反馈作为排队消息注入，引擎在安全点消费叫醒模型（任务已结束时
/// 留待续跑进上下文）。
typedef AgentHookRewakeSink = Future<void> Function(String feedback);

/// 一批 hooks 的时间线状态行（完成态）。[label] 形如
/// `preToolUse(write)`；异步/失败条数单独标注。
String formatAgentHookStatusLine({
  required String label,
  required AgentHookResult aggregate,
  required int count,
  required int failedCount,
  required int asyncCount,
  required Duration elapsed,
}) {
  final verdict = switch (aggregate.outcome) {
    AgentHookOutcome.block => aggregate.message.isEmpty
        ? '✗ 阻断'
        : '✗ 阻断：${aggregate.message}',
    AgentHookOutcome.ask => '? 强制审批',
    AgentHookOutcome.allow => '✓ 免审放行',
    AgentHookOutcome.proceed || AgentHookOutcome.failed => '✓ 放行',
  };
  final extras = [
    if (aggregate.preventContinuation) '⏹ 要求终止任务',
    if (asyncCount > 0) '$asyncCount 条转后台',
    if (failedCount > 0) '$failedCount 条失败（不阻断）',
  ];
  final seconds = (elapsed.inMilliseconds / 1000).toStringAsFixed(1);
  return '[hook] $label $verdict'
      '${extras.isEmpty ? '' : '（${extras.join('，')}）'}'
      ' · $count 条 · ${seconds}s';
}

/// 退出协议（对标 Claude Code）：
/// - stdout 首行若是 `{"async":true}` → async hook：不参与裁决
///   （按放行处理），余下输出/退出码忽略；
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
  if (_isAsyncFirstLine(stdout)) {
    return const AgentHookResult(
      outcome: AgentHookOutcome.proceed,
      isAsync: true,
    );
  }
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

/// async 协议（对标 Claude Code）：hook 把 `{"async":true}` 作为
/// stdout 第一行输出即转后台——只解析首行，后续输出不影响判定。
bool _isAsyncFirstLine(String stdout) {
  final firstLine = stdout.trimLeft().split('\n').first.trim();
  if (!firstLine.startsWith('{')) return false;
  try {
    final decoded = jsonDecode(firstLine);
    return decoded is Map<String, dynamic> && decoded['async'] == true;
  } catch (_) {
    return false;
  }
}

/// prompt 型 hook 占位符：提示词里的 `$ARGUMENTS` 替换为 hook 输入
/// JSON；没有占位符时把输入追加到提示词末尾（对标 Claude Code）。
String buildAgentPromptHookText(String prompt, String inputJson) =>
    prompt.contains(r'$ARGUMENTS')
        ? prompt.replaceAll(r'$ARGUMENTS', inputJson)
        : '$prompt\n\n$inputJson';

/// prompt 型 hook 的回复协议（对标 Claude Code）：模型输出
/// `{"ok":true}` → 放行；`{"ok":false,"reason":"..."}` → block（原因
/// 回给模型）；非 JSON / 不符合协议 → hook 自身失败（不阻断）。
AgentHookResult interpretAgentPromptHookResponse(String response) {
  final trimmed = response.trim();
  // 容忍模型把 JSON 包在 ```围栏```里。
  final unfenced = trimmed.startsWith('```')
      ? trimmed
          .replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '')
          .replaceFirst(RegExp(r'```\s*$'), '')
          .trim()
      : trimmed;
  try {
    final decoded = jsonDecode(unfenced);
    if (decoded is! Map<String, dynamic> || decoded['ok'] is! bool) {
      return AgentHookResult(
        outcome: AgentHookOutcome.failed,
        message: 'prompt hook 回复不符合协议：$trimmed',
      );
    }
    if (decoded['ok'] == true) {
      return const AgentHookResult(outcome: AgentHookOutcome.proceed);
    }
    final reason = decoded['reason'];
    return AgentHookResult(
      outcome: AgentHookOutcome.block,
      message: reason is String ? reason : '',
    );
  } catch (_) {
    return AgentHookResult(
      outcome: AgentHookOutcome.failed,
      message: 'prompt hook 回复不是 JSON：$trimmed',
    );
  }
}

/// http 型 hook 的响应协议（对标 Claude Code）：非 2xx → hook 自身
/// 失败（不阻断）；2xx → 响应体按 stdout 同款协议解析（首行
/// `{"async":true}` / `{"decision":...}` / `{"continue":false}` /
/// additionalContext，空体默认放行）。
AgentHookResult interpretAgentHttpHookResponse(int statusCode, String body) {
  if (statusCode < 200 || statusCode >= 300) {
    return AgentHookResult(
      outcome: AgentHookOutcome.failed,
      message: 'HTTP $statusCode${body.trim().isEmpty ? '' : '：${body.trim()}'}',
    );
  }
  return interpretAgentHookExit(0, body, '');
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
    final prevent = decoded['continue'] == false;
    final stopReason = decoded['stopReason'];
    final stopReasonStr = prevent && stopReason is String ? stopReason : '';
    final updatedInput = decoded['updatedInput'];
    // block 裁决下 updatedInput 无意义（调用已被拦截），丢弃。
    final updatedArgsJson =
        updatedInput is Map<String, dynamic> && outcome != AgentHookOutcome.block
            ? jsonEncode(updatedInput)
            : '';
    final systemMessage = decoded['systemMessage'];
    final systemMessageStr = systemMessage is String ? systemMessage : '';
    if (outcome == null) {
      if (contextStr.isEmpty &&
          !prevent &&
          updatedArgsJson.isEmpty &&
          systemMessageStr.isEmpty) {
        return null;
      }
      return AgentHookResult(
        outcome: AgentHookOutcome.proceed,
        additionalContext: contextStr,
        preventContinuation: prevent,
        stopReason: stopReasonStr,
        updatedArgsJson: updatedArgsJson,
        systemMessage: systemMessageStr,
      );
    }
    final reason = decoded['reason'];
    return AgentHookResult(
      outcome: outcome,
      message: reason is String ? reason : '',
      additionalContext: contextStr,
      preventContinuation: prevent,
      stopReason: stopReasonStr,
      updatedArgsJson: updatedArgsJson,
      systemMessage: systemMessageStr,
    );
  } catch (_) {
    return null;
  }
}

/// http hook 的 SSRF 防护（对标 Claude Code ssrfGuard）：判定解析出的
/// IP 是否属于 http hook 不应触达的地址段——私网、链路本地/云
/// metadata（169.254.169.254 等）、CGNAT 共享段、未指定地址。
/// loopback（127.0.0.0/8、::1）刻意放行：本机策略服务是 http hook 的
/// 主要使用场景。非法 IP 字面量返回 false（交给真实 DNS 路径处理）。
bool isBlockedAgentHookAddress(String address) {
  final v4 = _parseIPv4(address);
  if (v4 != null) return _isBlockedV4(v4);
  final v6 = _parseIPv6Groups(address);
  if (v6 != null) return _isBlockedV6(v6);
  return false;
}

List<int>? _parseIPv4(String address) {
  final parts = address.split('.');
  if (parts.length != 4) return null;
  final octets = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0 || n > 255) return null;
    octets.add(n);
  }
  return octets;
}

bool _isBlockedV4(List<int> o) {
  final a = o[0], b = o[1];
  // loopback 刻意放行
  if (a == 127) return false;
  // 0.0.0.0/8「本」网络
  if (a == 0) return true;
  // 10.0.0.0/8 私网
  if (a == 10) return true;
  // 169.254.0.0/16 链路本地（云 metadata）
  if (a == 169 && b == 254) return true;
  // 172.16.0.0/12 私网
  if (a == 172 && b >= 16 && b <= 31) return true;
  // 100.64.0.0/10 CGNAT 共享段（部分云 metadata，如阿里云 100.100.100.200）
  if (a == 100 && b >= 64 && b <= 127) return true;
  // 192.168.0.0/16 私网
  if (a == 192 && b == 168) return true;
  return false;
}

/// 把 IPv6 展开为 8 个 16 位组（支持 `::` 压缩与尾部点分 IPv4）；
/// 非法返回 null。
List<int>? _parseIPv6Groups(String address) {
  var addr = address.toLowerCase();
  if (!addr.contains(':')) return null;
  var tail = <int>[];
  if (addr.contains('.')) {
    final lastColon = addr.lastIndexOf(':');
    final v4 = _parseIPv4(addr.substring(lastColon + 1));
    if (v4 == null) return null;
    tail = [(v4[0] << 8) | v4[1], (v4[2] << 8) | v4[3]];
    addr = addr.substring(0, lastColon);
  }
  final dbl = addr.indexOf('::');
  List<String> head, rest;
  if (dbl == -1) {
    head = addr.split(':');
    rest = [];
  } else {
    if (addr.indexOf('::', dbl + 1) != -1) return null;
    final headStr = addr.substring(0, dbl);
    final restStr = addr.substring(dbl + 2);
    head = headStr.isEmpty ? [] : headStr.split(':');
    rest = restStr.isEmpty ? [] : restStr.split(':');
  }
  final target = 8 - tail.length;
  final fill = target - head.length - rest.length;
  if (dbl == -1 && fill != 0) return null;
  if (fill < 0) return null;
  final groups = <int>[];
  for (final h in [...head, ...List.filled(fill, '0'), ...rest]) {
    if (h.isEmpty || h.length > 4) return null;
    final n = int.tryParse(h, radix: 16);
    if (n == null || n < 0 || n > 0xffff) return null;
    groups.add(n);
  }
  groups.addAll(tail);
  return groups.length == 8 ? groups : null;
}

bool _isBlockedV6(List<int> g) {
  // ::1 loopback 刻意放行
  if (g.sublist(0, 7).every((n) => n == 0) && g[7] == 1) return false;
  // :: 未指定地址
  if (g.every((n) => n == 0)) return true;
  // IPv4-mapped（::ffff:a.b.c.d，含十六进制表示）→ 按内嵌 v4 判定，
  // 否则 ::ffff:a9fe:a9fe（=169.254.169.254）可绕过防护。
  if (g.sublist(0, 5).every((n) => n == 0) && g[5] == 0xffff) {
    return _isBlockedV4([g[6] >> 8, g[6] & 0xff, g[7] >> 8, g[7] & 0xff]);
  }
  final first = g[0];
  // fc00::/7 唯一本地地址
  if (first >= 0xfc00 && first <= 0xfdff) return true;
  // fe80::/10 链路本地
  if (first >= 0xfe80 && first <= 0xfebf) return true;
  return false;
}
