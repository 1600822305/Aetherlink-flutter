// 智能体 Hooks 执行层（Hooks H2/H3，阶段 5.5 自 agent_runtime_access 拆出）。
//
// 纯逻辑（事件/配置解析/退出协议/stdin JSON/stderr 拆分）在
// `features/agent/domain/agent_hooks.dart`；本文件放需要跨 feature
// 组装的执行与接线：配置加载（手动 hooks + 已信任的工作区
// hooks.json）、hook 命令经 terminal_execute 执行、工具执行器装饰层、
// userPromptSubmit hooks。因依赖 chat 侧工具路由（agent 与 chat 互不
// import 的架构硬约束），与 DI 同层放在 `app/di`。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/di/network_proxy_access.dart';
import 'package:aetherlink_flutter/core/network/dio_client.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_hooks_settings.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_hooks_trust.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_manual_hooks.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_executor.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_hooks.dart';
import 'package:aetherlink_flutter/features/agent/domain/permission_request.dart';
import 'package:aetherlink_flutter/features/agent/domain/shell_command_patterns.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_tool_call.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
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

  /// 任一 hook 输出 `{"continue":false}` 后的待处理终止信号
  /// （stopReason，无则默认文案）；引擎在安全点经
  /// [takeHookStopSignal] 消费并终止整个任务。
  String? _stopSignal;

  /// hooks 运行状态写入任务时间线的通道（任务运行器在引擎启动时
  /// 注入，携带 taskId）；null = 静默执行。
  AgentHookTimelineSink? timeline;

  /// asyncRewake 反馈注入任务的通道（任务运行器注入，把反馈作为
  /// 排队消息落库，引擎安全点消费）；null = 不支持叫醒，
  /// asyncRewake hooks 退化为同步执行。
  AgentHookRewakeSink? rewake;

  /// once hooks 的已执行集（对标 CC 的 once：运行一次后移除）：
  /// 本执行器实例 = 一次任务运行，命中后同一 hook 不再触发。
  final Set<String> _onceDone = {};

  /// 取并清除 hook 的任务终止信号（continue:false）。
  String? takeHookStopSignal() {
    final signal = _stopSignal;
    _stopSignal = null;
    return signal;
  }

  void _recordStopSignal(AgentHookResult result) {
    if (!result.preventContinuation) return;
    _stopSignal ??= result.stopReason.isNotEmpty
        ? result.stopReason
        : 'hook 要求终止任务（continue:false）';
  }

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

    final results = await _runHooksParallel(
      hooksForToolCall(
          config, AgentHookEvent.preToolUse, permission, patterns),
      (hook) => _runHook(hook,
          eventName: AgentHookEvent.preToolUse.name,
          toolName: call.name,
          argsJson: call.argsJson,
          filePath: filePath),
      emptyBlockMessage: (hook) => 'hook（${hook.payload}）拦截了本次调用。',
      label: '${AgentHookEvent.preToolUse.name}(${call.name})',
    );
    final verdict = aggregateAgentHookResults(results);
    _recordStopSignal(verdict);
    _preVerdicts[key] = verdict;
    return verdict;
  }

  /// permissionRequest hooks 的聚合裁决（审批门在挂起审批前调用，
  /// 仅本要弹审批时触发）：allow → 免审直通（越 root 硬约束不可
  /// 覆盖）；block → 强制拒绝（按策略禁止处理）；其余照常审批。
  /// 无 hooks 配置或无命中时返回 null。
  Future<AgentHookResult?> permissionRequestVerdict(
    AgentToolCallRequest call,
  ) async {
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

    final hooks = hooksForToolCall(
        config, AgentHookEvent.permissionRequest, permission, patterns);
    if (hooks.isEmpty) return null;
    final results = await _runHooksParallel(
      hooks,
      (hook) => _runHook(hook,
          eventName: AgentHookEvent.permissionRequest.name,
          toolName: call.name,
          argsJson: call.argsJson,
          filePath: filePath),
      emptyBlockMessage: (hook) => 'hook（${hook.payload}）拒绝了本次审批请求。',
      label: '${AgentHookEvent.permissionRequest.name}(${call.name})',
    );
    final verdict = aggregateAgentHookResults(results);
    _recordStopSignal(verdict);
    return verdict;
  }

  /// permissionDenied hooks（观测型，用户拒绝审批后 fire-and-forget）：
  /// 拒绝原因经 `tool_response` 传入，不影响任务继续。
  Future<void> runPermissionDeniedHooks(
    AgentToolCallRequest call, {
    String reason = '',
  }) async {
    try {
      final config = await _hooks();
      if (config == null || config.isEmpty) return;
      final route = _routes[call.name];
      final args = decodeToolArgsJson(call.argsJson);
      final permission =
          route == null ? call.name : permissionOfToolRoute(route, call.name);
      final patterns = route == null
          ? const <String>['*']
          : patternsOfToolCall(route, call.name, args);
      final path = args['path'];
      final filePath = path is String && path.isNotEmpty ? path : null;
      final hooks = hooksForToolCall(
          config, AgentHookEvent.permissionDenied, permission, patterns);
      if (hooks.isEmpty) return;
      final results = await _runHooksParallel(
        hooks,
        (hook) => _runHook(hook,
            eventName: AgentHookEvent.permissionDenied.name,
            toolName: call.name,
            argsJson: call.argsJson,
            filePath: filePath,
            toolOutput: reason.isEmpty ? null : reason),
        label: '${AgentHookEvent.permissionDenied.name}(${call.name})',
      );
      _recordStopSignal(aggregateAgentHookResults(results));
    } catch (_) {}
  }

  /// notification hooks（观测型，对标 CC Notification）：需要用户
  /// 注意时（审批挂起 / ask_user 等待）fire-and-forget；matcher 匹配
  /// 通知类型（approval / question），pattern 忽略；消息经 stdin JSON
  /// `message` / `notification_type` 传入。
  Future<void> runNotificationHooks(
    String message, {
    String notificationType = '',
  }) async {
    try {
      final config = await _hooks();
      if (config == null || config.isEmpty) return;
      final hooks = hooksForToolCall(
        config,
        AgentHookEvent.notification,
        notificationType.isEmpty ? '*' : notificationType,
        const [],
      );
      if (hooks.isEmpty) return;
      final results = await _runHooksParallel(
        hooks,
        (hook) => _runHook(hook,
            eventName: AgentHookEvent.notification.name,
            toolName: '',
            argsJson: '{}',
            message: message,
            notificationType: notificationType),
        label: '${AgentHookEvent.notification.name}'
            '${notificationType.isEmpty ? '' : '($notificationType)'}',
      );
      _recordStopSignal(aggregateAgentHookResults(results));
    } catch (_) {}
  }

  /// preCompact / postCompact hooks（观测型，对标 CC PreCompact /
  /// PostCompact）：上下文压缩前后 fire-and-forget；matcher 匹配触发
  /// 方式（目前仅 auto），pattern 忽略；压缩摘要（postCompact）经
  /// stdin JSON `tool_response` 传入。
  Future<void> runCompactionHooks(
    AgentHookEvent event, {
    String summary = '',
  }) async {
    try {
      final config = await _hooks();
      if (config == null || config.isEmpty) return;
      final hooks = hooksForToolCall(config, event, 'auto', const []);
      if (hooks.isEmpty) return;
      final results = await _runHooksParallel(
        hooks,
        (hook) => _runHook(hook,
            eventName: event.name,
            toolName: '',
            argsJson: '{}',
            toolOutput: summary.isEmpty ? null : summary),
        label: event.name,
      );
      _recordStopSignal(aggregateAgentHookResults(results));
    } catch (_) {}
  }

  /// 是否配有 fileChanged hooks（含 disableAllHooks 短路）：文件
  /// watcher 启动前探询，无配置时不订阅后端 watch 流。
  Future<bool> hasFileChangedHooks() async {
    try {
      final config = await _hooks();
      return config != null &&
          config.ofEvent(AgentHookEvent.fileChanged).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// fileChanged hooks（观测型，对标 CC FileChanged）：工作区文件
  /// 变更去抖后 fire-and-forget；matcher 匹配变更类型
  /// （created/modified/deleted/moved），pattern 匹配文件路径；路径
  /// 经 `file_path`、变更类型经 `event` 传入。
  Future<void> runFileChangedHooks(String path, String changeKind) async {
    try {
      final config = await _hooks();
      if (config == null || config.isEmpty) return;
      final hooks = hooksForToolCall(
          config, AgentHookEvent.fileChanged, changeKind, [path]);
      if (hooks.isEmpty) return;
      final results = await _runHooksParallel(
        hooks,
        (hook) => _runHook(hook,
            eventName: AgentHookEvent.fileChanged.name,
            toolName: '',
            argsJson: '{}',
            filePath: path,
            fileEvent: changeKind),
        label: '${AgentHookEvent.fileChanged.name}($changeKind)',
      );
      _recordStopSignal(aggregateAgentHookResults(results));
    } catch (_) {}
  }

  /// 同事件命中的多条 hooks 并行执行（对标 Claude Code）：同命令
  /// 去重，裁决由 [aggregateAgentHookResults] 聚合；可选把空原因的
  /// block 补上含 hook 命令的默认文案。[label] 非空且接了时间线
  /// 通道时，落一条「运行中」状态事件并在完成后原位改写为结果。
  Future<List<AgentHookResult>> _runHooksParallel(
    List<AgentHook> hooks,
    Future<AgentHookResult> Function(AgentHook hook) run, {
    String Function(AgentHook hook)? emptyBlockMessage,
    String? label,
  }) async {
    final seen = <String>{};
    final unique = <AgentHook>[];
    final rewakeSink = rewake;
    for (final h in hooks) {
      final key = '${h.type.name}\u0000${h.payload}';
      if (!seen.add(key)) continue;
      // once（对标 CC）：本次任务内只触发一次。
      if (h.once && !_onceDone.add(key)) continue;
      // asyncRewake（对标 CC）：直接转后台不参与本批裁决，
      // 后台跑完若阻断把反馈排队注入任务叫醒模型。
      if (h.asyncRewake && rewakeSink != null) {
        unawaited(_runRewakeHook(h, run, rewakeSink, label: label));
        continue;
      }
      unique.add(h);
    }
    void Function(String line)? updateStatus;
    final sink = timeline;
    if (label != null && sink != null && unique.isNotEmpty) {
      final status = unique
          .map((h) => h.statusMessage)
          .firstWhere((s) => s.isNotEmpty, orElse: () => '');
      try {
        updateStatus = await sink(
            '[hook] $label 运行中 · ${unique.length} 条'
            '${status.isEmpty ? '' : ' · $status'}');
      } catch (_) {}
    }
    final sw = Stopwatch()..start();
    final results = await Future.wait([
      for (final hook in unique)
        () async {
          final result = await run(hook);
          if (emptyBlockMessage != null &&
              result.outcome == AgentHookOutcome.block &&
              result.message.isEmpty) {
            return AgentHookResult(
              outcome: AgentHookOutcome.block,
              message: emptyBlockMessage(hook),
              additionalContext: result.additionalContext,
              preventContinuation: result.preventContinuation,
              stopReason: result.stopReason,
            );
          }
          return result;
        }(),
    ]);
    final aggregate = aggregateAgentHookResults(results);
    if (updateStatus != null && label != null) {
      updateStatus(formatAgentHookStatusLine(
        label: label,
        aggregate: aggregate,
        count: unique.length,
        failedCount: results
            .where((r) => r.outcome == AgentHookOutcome.failed)
            .length,
        asyncCount: results.where((r) => r.isAsync).length,
        elapsed: sw.elapsed,
      ));
    }
    // systemMessage（对标 CC）：hook 给用户的提示，单独落一条时间线
    // 状态行（不进模型上下文）。
    if (aggregate.systemMessage.isNotEmpty && sink != null) {
      try {
        await sink('[hook] 💬 ${aggregate.systemMessage}');
      } catch (_) {}
    }
    return results;
  }

  /// 跑一条 asyncRewake hook（后台）：时间线落「转后台」状态行，
  /// 跑完原位改写为结果；阻断（退出码 2）时把反馈经 [rewake]
  /// 排队注入任务；也消费 continue:false 终止信号。
  Future<void> _runRewakeHook(
    AgentHook hook,
    Future<AgentHookResult> Function(AgentHook hook) run,
    AgentHookRewakeSink rewakeSink, {
    String? label,
  }) async {
    final tag = label ?? hook.event.name;
    void Function(String line)? updateStatus;
    final sink = timeline;
    if (sink != null) {
      try {
        updateStatus = await sink(
            '[hook] $tag 转后台（rewake）· ${hook.statusMessage.isNotEmpty ? hook.statusMessage : hook.payload}');
      } catch (_) {}
    }
    final sw = Stopwatch()..start();
    AgentHookResult result;
    try {
      result = await run(hook);
    } catch (e) {
      result = AgentHookResult(
        outcome: AgentHookOutcome.failed,
        message: 'hook 执行异常：$e',
      );
    }
    _recordStopSignal(result);
    final seconds = (sw.elapsedMilliseconds / 1000).toStringAsFixed(1);
    if (result.outcome == AgentHookOutcome.block) {
      final feedback = result.message.isNotEmpty
          ? result.message
          : 'hook（${hook.payload}）报告了问题（无输出）。';
      updateStatus?.call(
          '[hook] $tag 后台阻断 ✗ 反馈已注入任务（${seconds}s）');
      try {
        await rewakeSink('[后台 hook 反馈] $tag（${hook.payload}）：\n$feedback');
      } catch (_) {}
    } else {
      updateStatus?.call(
          '[hook] $tag 后台完成 · ${result.outcome == AgentHookOutcome.failed ? '失败' : '放行'}（${seconds}s）');
    }
  }

  /// hooks 配置（任务运行内只读一次），见 [loadAgentHooksConfig]。
  /// disableAllHooks 全局开关（对标 CC）打开时返回 null 短路所有
  /// 事件；本可命中 hooks 时落一条时间线提示，避免用户以为
  /// hooks 生效了。
  Future<AgentHooksConfig?> _hooks() async {
    if (_configLoaded) return _config;
    _configLoaded = true;
    if (_boundWorkspaceId == null) return null;
    final loaded = await loadAgentHooksConfig(_refOf(), _boundWorkspaceId);
    _workspaceRoot = loaded.root;
    if (_refOf().read(agentDisableAllHooksProvider)) {
      final sink = timeline;
      if (loaded.config != null && sink != null) {
        try {
          await sink('[hook] 已被全局开关停用（本次任务内所有 hooks 不执行）');
        } catch (_) {}
      }
      _config = null;
      return null;
    }
    _config = loaded.config;
    return _config;
  }

  @override
  bool isConcurrencySafe(AgentToolCallRequest call) {
    // 配置未加载完（首次调用前）或存在任何 hooks 时保持串行：hook 命令
    // 跑在工作区终端会话里，跨调用并发的交错行为未定义。
    if (!_configLoaded) {
      unawaited(_hooks());
      return false;
    }
    final config = _config;
    if (config != null && !config.isEmpty) return false;
    return _inner.isConcurrencySafe(call);
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

    // updatedInput（对标 CC）：preToolUse hook 改写入参后放行，工具
    // 改用新入参执行；改写事实落时间线告知用户。
    var effectiveCall = call;
    if (preVerdict != null && preVerdict.updatedArgsJson.isNotEmpty) {
      effectiveCall = AgentToolCallRequest(
        id: call.id,
        name: call.name,
        argsJson: preVerdict.updatedArgsJson,
        argSummary: call.argSummary,
      );
      final sink = timeline;
      if (sink != null) {
        try {
          await sink('[hook] preToolUse(${call.name}) 改写了工具入参');
        } catch (_) {}
      }
    }

    final toolResult = await _inner.execute(effectiveCall, cancel);
    final postEvent = toolResult.ok
        ? AgentHookEvent.postToolUse
        : AgentHookEvent.postToolUseFailure;

    final results = await _runHooksParallel(
      hooksForToolCall(config, postEvent, permission, patterns),
      (hook) => _runHook(hook,
          eventName: postEvent.name,
          toolName: call.name,
          argsJson: effectiveCall.argsJson,
          filePath: filePath,
          toolOutput: toolResult.detail ?? toolResult.summary,
          toolOk: toolResult.ok),
      emptyBlockMessage: (hook) => 'hook（${hook.payload}）报告了问题（无输出）。',
      label: '${postEvent.name}(${call.name})',
    );
    final post = aggregateAgentHookResults(results);
    _recordStopSignal(post);
    // updatedMCPToolOutput（对标 CC）：postToolUse hook 改写回给模型的
    // 工具输出（与 updatedInput 对称）；仅成功结果（postToolUse）生效
    // （CC 的 PostToolUseFailure 协议无此字段）；block 裁决下不改写
    // （结果已被反馈替代）；改写事实落时间线告知用户。
    var effectiveResult = toolResult;
    if (postEvent == AgentHookEvent.postToolUse &&
        post.outcome != AgentHookOutcome.block &&
        post.updatedToolOutput.isNotEmpty) {
      effectiveResult = AgentToolResult(
        ok: toolResult.ok,
        summary: toolResult.summary,
        detail: post.updatedToolOutput,
      );
      final sink = timeline;
      if (sink != null) {
        try {
          await sink('[hook] ${postEvent.name}(${call.name}) 改写了工具输出');
        } catch (_) {}
      }
    }
    final feedback = post.outcome == AgentHookOutcome.block ? post.message : '';
    final contexts = <String>[
      if (preVerdict != null && preVerdict.additionalContext.isNotEmpty)
        preVerdict.additionalContext,
      if (post.additionalContext.isNotEmpty) post.additionalContext,
    ];
    if (feedback.isEmpty && contexts.isEmpty) return effectiveResult;
    final sections = [
      if (feedback.isNotEmpty) '[${postEvent.name} hook 反馈]\n$feedback',
      if (contexts.isNotEmpty)
        '[hook additionalContext]\n${contexts.join('\n')}',
    ];
    return AgentToolResult(
      ok: effectiveResult.ok,
      summary: effectiveResult.summary,
      detail: '${effectiveResult.detail ?? ''}\n\n${sections.join('\n\n')}',
      overflowPath: effectiveResult.overflowPath,
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
      final results = await _runHooksParallel(
        config.ofEvent(event),
        (hook) => _runHook(hook,
            eventName: event.name, toolName: event.name, argsJson: '{}'),
        label: event.name,
      );
      _recordStopSignal(aggregateAgentHookResults(results));
    } catch (_) {}
  }

  Future<String?> runStopHooks() => _runFinalizeHooks(AgentHookEvent.stop);

  /// 子智能体收尾前跑 subagentStop hooks（子引擎 stopGuard），语义同
  /// [runStopHooks]。
  Future<String?> runSubagentStopHooks() =>
      _runFinalizeHooks(AgentHookEvent.subagentStop);

  Future<String?> _runFinalizeHooks(AgentHookEvent event) async {
    final config = await _hooks();
    if (config == null) return null;
    final results = await _runHooksParallel(
      config.ofEvent(event),
      (hook) => _runHook(hook,
          eventName: event.name, toolName: event.name, argsJson: '{}'),
      emptyBlockMessage: (hook) => 'hook（${hook.payload}）阻止了收尾。',
      label: event.name,
    );
    final aggregate = aggregateAgentHookResults(results);
    if (aggregate.outcome == AgentHookOutcome.block) return aggregate.message;
    return null;
  }

  /// 跑一条 hook（按类型分派，委托 [_execAgentHook]）。
  Future<AgentHookResult> _runHook(
    AgentHook hook, {
    required String eventName,
    required String toolName,
    required String argsJson,
    String? filePath,
    String? toolOutput,
    bool? toolOk,
    String? message,
    String? notificationType,
    String? fileEvent,
  }) =>
      _execAgentHook(
        _refOf(),
        hook,
        eventName: eventName,
        toolName: toolName,
        argsJson: argsJson,
        filePath: filePath,
        toolOutput: toolOutput,
        toolOk: toolOk,
        message: message,
        notificationType: notificationType,
        fileEvent: fileEvent,
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
  // disableAllHooks 全局开关：打开时 userPromptSubmit 同样短路。
  if (ref.read(agentDisableAllHooksProvider)) return null;
  final loaded = await loadAgentHooksConfig(ref, workspaceId);
  final config = loaded.config;
  if (config == null) return null;
  final seen = <String>{};
  final unique = [
    for (final h in config.ofEvent(AgentHookEvent.userPromptSubmit))
      if (seen.add('${h.type.name}\u0000${h.payload}')) h,
  ];
  final results = await Future.wait([
    for (final hook in unique)
      () async {
        final result = await _execAgentHook(
          ref,
          hook,
          eventName: AgentHookEvent.userPromptSubmit.name,
          toolName: '',
          argsJson: '{}',
          prompt: prompt,
          workspaceId: workspaceId.isEmpty ? null : workspaceId,
          cwd: loaded.root,
        );
        if (result.outcome == AgentHookOutcome.block &&
            result.message.isEmpty) {
          return AgentHookResult(
            outcome: AgentHookOutcome.block,
            message: 'hook（${hook.payload}）拦截了本条消息。',
            additionalContext: result.additionalContext,
            preventContinuation: result.preventContinuation,
            stopReason: result.stopReason,
          );
        }
        return result;
      }(),
  ]);
  final aggregate = aggregateAgentHookResults(results);
  if (aggregate.outcome == AgentHookOutcome.proceed &&
      aggregate.additionalContext.isEmpty &&
      !aggregate.preventContinuation) {
    return null;
  }
  return aggregate;
}

/// 设置页「试跑」：用示例上下文单独执行一条 hook，返回裁决结果。
/// 工具事件用示例工具调用上下文；userPromptSubmit 用示例消息；
/// command 型需要 [workspaceId]（跑在该工作区的终端里）。
Future<AgentHookResult> tryRunAgentHook(
  Ref ref,
  AgentHook hook, {
  String? workspaceId,
}) {
  final toolEvent = hook.event == AgentHookEvent.preToolUse ||
      hook.event == AgentHookEvent.postToolUse ||
      hook.event == AgentHookEvent.postToolUseFailure ||
      hook.event == AgentHookEvent.permissionRequest ||
      hook.event == AgentHookEvent.permissionDenied;
  return _execAgentHook(
    ref,
    hook,
    eventName: hook.event.name,
    toolName: toolEvent ? 'terminal_execute' : '',
    argsJson: toolEvent ? '{"command":"echo hook 试跑示例"}' : '{}',
    toolOutput: hook.event == AgentHookEvent.postToolUse ||
            hook.event == AgentHookEvent.postToolUseFailure
        ? 'hook 试跑示例输出'
        : null,
    toolOk: hook.event == AgentHookEvent.postToolUse
        ? true
        : hook.event == AgentHookEvent.postToolUseFailure
            ? false
            : null,
    prompt: hook.event == AgentHookEvent.userPromptSubmit ? 'hook 试跑示例消息' : null,
    message: hook.event == AgentHookEvent.notification ? 'hook 试跑示例通知' : null,
    notificationType:
        hook.event == AgentHookEvent.notification ? 'approval' : null,
    filePath:
        hook.event == AgentHookEvent.fileChanged ? '试跑示例/文件.dart' : null,
    fileEvent: hook.event == AgentHookEvent.fileChanged ? 'modified' : null,
    workspaceId: workspaceId,
  );
}

/// 跑一条 hook：按类型分派——command 型走工作区终端
/// （[_execHookCommand]），prompt 型走一次 LLM 裁决
/// （[_execPromptHook]），http 型 POST 到回调 URL（[_execHttpHook]）。
Future<AgentHookResult> _execAgentHook(
  Ref ref,
  AgentHook hook, {
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
  String? workspaceId,
  String? cwd,
}) {
  switch (hook.type) {
    case AgentHookType.command:
      return _execHookCommand(
        ref,
        hook,
        eventName: eventName,
        toolName: toolName,
        argsJson: argsJson,
        filePath: filePath,
        toolOutput: toolOutput,
        toolOk: toolOk,
        prompt: prompt,
        message: message,
        notificationType: notificationType,
        fileEvent: fileEvent,
        workspaceId: workspaceId,
        cwd: cwd,
      );
    case AgentHookType.prompt:
    case AgentHookType.http:
    case AgentHookType.agent:
      final stdinJson = buildAgentHookStdinJson(
        eventName: eventName,
        toolName: toolName,
        argsJson: argsJson,
        filePath: filePath,
        toolOutput: toolOutput != null && toolOutput.length > 4000
            ? toolOutput.substring(0, 4000)
            : toolOutput,
        toolOk: toolOk,
        prompt: prompt,
        message: message,
        notificationType: notificationType,
        fileEvent: fileEvent,
        sessionId: workspaceId,
        cwd: cwd,
      );
      return switch (hook.type) {
        AgentHookType.prompt => _execPromptHook(ref, hook, stdinJson),
        AgentHookType.http => _execHttpHook(ref, hook, stdinJson),
        _ => _execAgentVerifierHook(ref, hook, stdinJson,
            workspaceId: workspaceId),
      };
  }
}

/// 解析 prompt / agent 型 hook 的裁决模型：配了 [AgentHook.model]
/// 时按模型 id 在全部供应商里查找，未配/找不到回退当前默认模型。
CurrentModel? _resolveHookModel(List<ModelProvider> providers, String modelId) {
  if (modelId.isNotEmpty) {
    for (final provider in providers) {
      for (final model in provider.models) {
        if (model.id == modelId) {
          return CurrentModel(provider: provider, model: model);
        }
      }
    }
  }
  return findCurrentModel(providers);
}

/// prompt 型 hook 的系统提示词：要求模型只回协议 JSON。
const String _kPromptHookSystem =
    '你是一个 hook 裁决器：根据用户给出的条件与 hook 输入判断条件是否满足。'
    '只输出一行 JSON，不要任何其他文字：满足时输出 {"ok":true}，'
    '不满足时输出 {"ok":false,"reason":"简短原因"}。';

/// 跑一条 prompt 型 hook：把 hook 输入 JSON 替换进提示词的
/// `$ARGUMENTS` 占位符，用当前默认模型做一次非交互裁决，回复
/// 协议见 [interpretAgentPromptHookResponse]。未配模型/超时/异常
/// 按 hook 自身失败处理（不阻断）。
Future<AgentHookResult> _execPromptHook(
  Ref ref,
  AgentHook hook,
  String stdinJson,
) async {
  try {
    final providers = await ref.read(appModelProvidersProvider.future);
    final current = _resolveHookModel(providers, hook.model);
    if (current == null) {
      return const AgentHookResult(
        outcome: AgentHookOutcome.failed,
        message: 'prompt hook 失败：未配置默认模型',
      );
    }
    final effective = effectiveModelFor(current);
    final request = LlmChatRequest(
      model: effective,
      system: _kPromptHookSystem,
      messages: [
        LlmMessage(
          role: MessageRole.user,
          content: buildAgentPromptHookText(hook.prompt, stdinJson),
        ),
      ],
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );
    final gateway = ref.read(appLlmGatewayFactoryProvider).forModel(effective);
    final buffer = StringBuffer();
    await () async {
      await for (final chunk in gateway.streamChat(request)) {
        if (chunk is LlmTextDelta) buffer.write(chunk.text);
      }
    }()
        .timeout(Duration(seconds: hook.timeoutSeconds));
    return interpretAgentPromptHookResponse(buffer.toString());
  } on TimeoutException {
    return const AgentHookResult(
      outcome: AgentHookOutcome.failed,
      message: 'prompt hook 超时',
    );
  } catch (e) {
    return AgentHookResult(
      outcome: AgentHookOutcome.failed,
      message: 'prompt hook 执行异常：$e',
    );
  }
}

/// agent 型 hook 的系统提示词：多轮带工具的校验器，结果必须经
/// submit_result 工具交回。
const String _kAgentVerifierSystem =
    '你是一个 hook 校验智能体：根据用户给出的校验条件与 hook 输入，'
    '用可用工具检查工作区后判断条件是否满足。尽量用最少的步骤、'
    '直接高效地验证。完成后必须调用 submit_result 工具交回结果：'
    '条件满足时 ok=true，不满足时 ok=false 并在 reason 里给简短原因。';

const int _kAgentVerifierMaxTurns = 10;

/// 跑一条 agent 型 hook（对标 Claude Code execAgentHook）：多轮
/// 函数调用循环的小智能体校验器——工具只有工作区终端
/// （run_command，绑定工作区时）与 submit_result（结构化交回
/// {"ok":...} 裁决，协议同 prompt 型）。超过轮数上限/超时/异常
/// 按 hook 自身失败处理（不阻断）。
Future<AgentHookResult> _execAgentVerifierHook(
  Ref ref,
  AgentHook hook,
  String stdinJson, {
  String? workspaceId,
}) async {
  try {
    final providers = await ref.read(appModelProvidersProvider.future);
    final current = _resolveHookModel(providers, hook.model);
    if (current == null) {
      return const AgentHookResult(
        outcome: AgentHookOutcome.failed,
        message: 'agent hook 失败：未配置默认模型',
      );
    }
    final effective = effectiveModelFor(current);
    final gateway = ref.read(appLlmGatewayFactoryProvider).forModel(effective);
    final tools = <McpToolDefinition>[
      if (workspaceId != null && workspaceId.isNotEmpty)
        const McpToolDefinition(
          name: 'run_command',
          description: '在任务绑定的工作区终端里执行一条 shell 命令，'
              '返回退出码与输出（用于检查文件/跑测试/搜索）。',
          inputSchema: {
            'type': 'object',
            'properties': {
              'command': {'type': 'string', 'description': 'shell 命令'},
            },
            'required': ['command'],
          },
        ),
      const McpToolDefinition(
        name: 'submit_result',
        description: '交回校验结果（必须调用，且只调一次）。',
        inputSchema: {
          'type': 'object',
          'properties': {
            'ok': {'type': 'boolean', 'description': '条件是否满足'},
            'reason': {'type': 'string', 'description': '不满足时的简短原因'},
          },
          'required': ['ok'],
        },
      ),
    ];
    final messages = <LlmMessage>[
      LlmMessage(
        role: MessageRole.user,
        content: buildAgentPromptHookText(hook.prompt, stdinJson),
      ),
    ];
    return await () async {
      for (var turn = 0; turn < _kAgentVerifierMaxTurns; turn++) {
        final request = LlmChatRequest(
          model: effective,
          system: _kAgentVerifierSystem,
          messages: messages,
          tools: tools,
          extraHeaders: effective.providerExtraHeaders,
          extraBody: effective.providerExtraBody,
        );
        final text = StringBuffer();
        final calls = <LlmToolCall>[];
        await for (final chunk in gateway.streamChat(request)) {
          if (chunk is LlmTextDelta) text.write(chunk.text);
          if (chunk is LlmToolCallChunk) calls.add(chunk.call);
        }
        if (calls.isEmpty) {
          // 未走工具直接回文本：容忍按 prompt 型同款协议解析。
          return interpretAgentPromptHookResponse(text.toString());
        }
        messages.add(LlmMessage(
          role: MessageRole.assistant,
          content: text.toString(),
          toolCalls: calls,
        ));
        for (final call in calls) {
          if (call.name == 'submit_result') {
            return interpretAgentPromptHookResponse(call.arguments);
          }
          String resultText;
          if (call.name == 'run_command') {
            final args = decodeToolArgsJson(call.arguments);
            final command = args['command'];
            if (command is String && command.trim().isNotEmpty) {
              final result = await runTerminalTool(ref, 'terminal_execute', {
                'command': command,
                'workspace': workspaceId,
              });
              resultText = result.text.length > 8000
                  ? result.text.substring(0, 8000)
                  : result.text;
            } else {
              resultText = '参数错误：缺 command';
            }
          } else {
            resultText = '未知工具：${call.name}';
          }
          messages.add(LlmMessage(
            role: MessageRole.user,
            content: resultText,
            toolCallId: call.id,
            toolName: call.name,
          ));
        }
      }
      return const AgentHookResult(
        outcome: AgentHookOutcome.failed,
        message: 'agent hook 超过轮数上限未交回结果',
      );
    }()
        .timeout(Duration(seconds: hook.timeoutSeconds));
  } on TimeoutException {
    return const AgentHookResult(
      outcome: AgentHookOutcome.failed,
      message: 'agent hook 超时',
    );
  } catch (e) {
    return AgentHookResult(
      outcome: AgentHookOutcome.failed,
      message: 'agent hook 执行异常：$e',
    );
  }
}

/// 跑一条 http 型 hook：把 hook 输入 JSON POST 到配置的 URL
/// （Content-Type: application/json，可附自定义 headers），响应协议见
/// [interpretAgentHttpHookResponse]。网络错误/超时按 hook 自身失败
/// 处理（不阻断）。发请求前先过 SSRF 防护（[_ssrfCheck]）：目标
/// 解析到私网/云 metadata 地址段时拒绝执行。
Future<AgentHookResult> _execHttpHook(
  Ref ref,
  AgentHook hook,
  String stdinJson,
) async {
  try {
    final ssrfError = await _ssrfCheck(hook.url);
    if (ssrfError != null) {
      return AgentHookResult(
        outcome: AgentHookOutcome.failed,
        message: ssrfError,
      );
    }
    final dio = buildLlmDio(proxy: ref.read(appNetworkProxyConfigProvider));
    final timeout = Duration(seconds: hook.timeoutSeconds);
    final response = await dio
        .post<String>(
          hook.url,
          data: stdinJson,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              ...hook.headers,
            },
            responseType: ResponseType.plain,
            sendTimeout: timeout,
            receiveTimeout: timeout,
            validateStatus: (_) => true,
          ),
        )
        .timeout(timeout);
    return interpretAgentHttpHookResponse(
      response.statusCode ?? 0,
      response.data ?? '',
    );
  } on TimeoutException {
    return const AgentHookResult(
      outcome: AgentHookOutcome.failed,
      message: 'http hook 超时',
    );
  } catch (e) {
    return AgentHookResult(
      outcome: AgentHookOutcome.failed,
      message: 'http hook 执行异常：$e',
    );
  }
}

/// http hook 的 SSRF 防护（对标 Claude Code ssrfGuard）：先解析
/// 目标主机（IP 字面量直接判，域名过 DNS），任一解析结果命中私网/
/// 链路本地/云 metadata 地址段（[isBlockedAgentHookAddress]，
/// loopback 放行）即拒绝；返回错误文案，null = 放行。DNS 失败
/// 不拦截（交给真实请求报网络错）。局限：检查与实际请求是两次
/// 独立解析，极端 DNS rebinding 场景下可能绕过（CC 同款设计在
/// lookup 钩子里做，我们的 dio 链路不暴露该钩子）。
Future<String?> _ssrfCheck(String url) async {
  final uri = Uri.tryParse(url);
  final host = uri?.host ?? '';
  if (host.isEmpty) return null;
  // Uri.host 对 IPv6 字面量已去方括号
  if (isBlockedAgentHookAddress(host)) {
    return 'http hook 目标地址 $host 属于私网/保留地址段，已拒绝（SSRF 防护）';
  }
  if (_parseAsIpLiteral(host)) return null;
  try {
    final addresses = await InternetAddress.lookup(host)
        .timeout(const Duration(seconds: 10));
    for (final addr in addresses) {
      if (isBlockedAgentHookAddress(addr.address)) {
        return 'http hook 目标 $host 解析到私网/保留地址 '
            '${addr.address}，已拒绝（SSRF 防护）';
      }
    }
  } catch (_) {
    // DNS 失败不在这里拦截，后续真实请求会报网络错误
  }
  return null;
}

bool _parseAsIpLiteral(String host) =>
    InternetAddress.tryParse(host) != null;

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
  String? message,
  String? notificationType,
  String? fileEvent,
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
      if (message != null && message.isNotEmpty)
        'export AETHER_MESSAGE=${_shellQuote(message)}',
      if (notificationType != null && notificationType.isNotEmpty)
        'export AETHER_NOTIFICATION_TYPE=${_shellQuote(notificationType)}',
      if (fileEvent != null && fileEvent.isNotEmpty)
        'export AETHER_FILE_EVENT=${_shellQuote(fileEvent)}',
    ].join('; ');
    var stdinJson = buildAgentHookStdinJson(
      eventName: eventName,
      toolName: toolName,
      argsJson: argsJson,
      filePath: filePath,
      toolOutput: toolOutput,
      toolOk: toolOk,
      prompt: prompt,
      message: message,
      notificationType: notificationType,
      fileEvent: fileEvent,
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
        message: message,
        notificationType: notificationType,
        fileEvent: fileEvent,
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
