// Hook 执行协议的纯逻辑（对标 Claude Code）：stdin JSON 组装、
// 终端合流输出拆分、退出码/回复/HTTP 响应的裁决解析与聚合。

import 'dart:convert';

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
  String? fileEvent,
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
    if (fileEvent != null && fileEvent.isNotEmpty) 'event': fileEvent,
    if (filePath != null && filePath.isNotEmpty) 'file_path': filePath,
    if (toolOutput != null) 'tool_response': toolOutput,
    if (toolOk != null) 'tool_ok': toolOk,
    if (sessionId != null) 'session_id': sessionId,
    if (cwd != null) 'cwd': cwd,
  });
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
    stderr: combined.substring(idx + kAgentHookStderrMarker.length).trim(),
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
/// 裁决下忽略）。[updatedToolOutput] 为 stdout JSON
/// `updatedMCPToolOutput`（对标 Claude Code，仅 postToolUse 生效）：
/// 非空时回给模型的工具输出改用该内容（block 裁决下忽略）。
/// [systemMessage]（对标 Claude Code）为展示给
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
    this.updatedToolOutput = '',
    this.systemMessage = '',
  });

  final AgentHookOutcome outcome;
  final String message;
  final String additionalContext;
  final bool preventContinuation;
  final String stopReason;
  final bool isAsync;
  final String updatedArgsJson;
  final String updatedToolOutput;
  final String systemMessage;
}

/// 同一事件多条 hooks（并行执行）的裁决聚合：
/// - outcome 优先级 block > ask > allow > proceed（failed 视为 proceed）；
/// - message 取全部 block 的原因拼接（无 block 时取胜出裁决的 message）；
/// - additionalContext / systemMessage 非空项拼接；
/// - updatedArgsJson / updatedToolOutput 取首个非空（多条 hook 同时改写不叠加）；
/// - preventContinuation 任一为 true 即 true，stopReason 取首个非空。
AgentHookResult aggregateAgentHookResults(Iterable<AgentHookResult> results) {
  var outcome = AgentHookOutcome.proceed;
  final blockMessages = <String>[];
  final contexts = <String>[];
  final systemMessages = <String>[];
  var updatedArgsJson = '';
  var updatedToolOutput = '';
  var prevent = false;
  var stopReason = '';
  String winnerMessage = '';
  for (final r in results) {
    if (r.additionalContext.isNotEmpty) contexts.add(r.additionalContext);
    if (r.systemMessage.isNotEmpty) systemMessages.add(r.systemMessage);
    if (updatedArgsJson.isEmpty && r.updatedArgsJson.isNotEmpty) {
      updatedArgsJson = r.updatedArgsJson;
    }
    if (updatedToolOutput.isEmpty && r.updatedToolOutput.isNotEmpty) {
      updatedToolOutput = r.updatedToolOutput;
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
    updatedToolOutput: updatedToolOutput,
    systemMessage: systemMessages.join('\n'),
  );
}

/// hooks 运行状态写入任务时间线的通道：以「运行中」文案落一条状态
/// 事件，返回原位覆盖该条文案的更新函数（hooks 跑完后改写为结果）。
typedef AgentHookTimelineSink =
    Future<void Function(String line)> Function(String line);

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
    AgentHookOutcome.block =>
      aggregate.message.isEmpty ? '✗ 阻断' : '✗ 阻断：${aggregate.message}',
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
      message:
          'HTTP $statusCode${body.trim().isEmpty ? '' : '：${body.trim()}'}',
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
        updatedInput is Map<String, dynamic> &&
            outcome != AgentHookOutcome.block
        ? jsonEncode(updatedInput)
        : '';
    // updatedMCPToolOutput（对标 CC，仅 postToolUse 生效）：字符串直接用，
    // 其他 JSON 值序列化后用；block 裁决下无意义（结果已被反馈替代），丢弃。
    final updatedOutput = decoded['updatedMCPToolOutput'];
    final updatedToolOutput =
        updatedOutput == null || outcome == AgentHookOutcome.block
        ? ''
        : updatedOutput is String
        ? updatedOutput
        : jsonEncode(updatedOutput);
    final systemMessage = decoded['systemMessage'];
    final systemMessageStr = systemMessage is String ? systemMessage : '';
    if (outcome == null) {
      if (contextStr.isEmpty &&
          !prevent &&
          updatedArgsJson.isEmpty &&
          updatedToolOutput.isEmpty &&
          systemMessageStr.isEmpty) {
        return null;
      }
      return AgentHookResult(
        outcome: AgentHookOutcome.proceed,
        additionalContext: contextStr,
        preventContinuation: prevent,
        stopReason: stopReasonStr,
        updatedArgsJson: updatedArgsJson,
        updatedToolOutput: updatedToolOutput,
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
      updatedToolOutput: updatedToolOutput,
      systemMessage: systemMessageStr,
    );
  } catch (_) {
    return null;
  }
}
