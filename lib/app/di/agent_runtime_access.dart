import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/agent_subagent_access.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_approval_registry.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_compaction.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_control_tools.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_subagent.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_system_prompt.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_executor.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/approval_gate.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/domain/subagent_profile.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_confirmation.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_executor.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_cancel_token.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_tool_call.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tool_catalog.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/workspace_context.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/knowledge/knowledge_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/tool_auth_policy.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/skill_read_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/terminal/terminal_tools.dart';

part 'agent_runtime_access.g.dart';

/// 智能体引擎真实依赖的组装 seam（落地顺序 ②③）。
///
/// agent 与 chat 互不 import（架构测试硬约束），但真实 LLM 网关
/// （`LlmGateway` 域端口）与工具路由/执行器都在 chat 侧——所以这两个
/// adapter 组装在 `app/di`（composition root，可依赖任意 feature）：
/// 引擎仍只见 [AgentLlmClient] / [AgentToolExecutor] 两个 agent 侧接口。
@Riverpod(keepAlive: true)
AgentRuntime agentRuntime(Ref ref) => AgentRuntime(() => ref);

/// 每个任务按档案组装一对 LLM 客户端 + 工具执行器。
/// 持 `Ref Function()`（与 ChatToolExecutor 同款做法）：任务可跨
/// provider rebuild 长时间运行，按值捕获的 Ref 会失效。
class AgentRuntime {
  AgentRuntime(this._refOf);

  final Ref Function() _refOf;

  ({AgentLlmClient llm, AgentToolExecutor tools, ApprovalGate approval})
      forProfile(
    AgentProfile profile, {
    AgentSessionMode mode = AgentSessionMode.code,
    bool enableSubagents = true,
  }) {
    final catalog = _catalogFor(
      profile.tools,
      mode: mode,
      enableSubagents: enableSubagents,
    );
    return (
      llm: _GatewayAgentLlmClient(_refOf, profile, catalog.definitions),
      tools: _McpAgentToolExecutor(_refOf, catalog.routes),
      approval: _PolicyApprovalGate(_refOf, catalog.routes),
    );
  }

  /// 当前默认模型的显示名（新建任务写 [AgentTask.modelLabel]）。
  Future<String?> currentModelLabel() async {
    final current = await _refOf().read(appCurrentModelProvider.future);
    return current?.model.name;
  }
}

/// 只读硬约束（Ask/Plan 模式，参考 Roo Code 模式×工具组 /
/// Claude Code plan 模式）：副作用工具从源头不暴露给模型（不占
/// 上下文、不会被尝试调用），幻觉调用时由执行器「不在工具集内」
/// 拒绝。终端命令无法静态判定副作用，整个组不暴露。
const Set<String> _kReadOnlyToolNames = {
  // 文件编辑器：只读子集
  'list_files', 'read_file', 'get_file_info', 'search_files',
  // 知识库：只读子集（kb_manage 有写操作，排除）
  'kb_list', 'kb_search', 'kb_read',
};

/// 档案工具分组 → 模型可见工具定义 + 名称到 [ToolRoute] 的分发表。
/// 控制工具（update_plan/ask_user/finish_task）恒在，由引擎内部处理。
/// Ask/Plan 模式只保留只读工具（见 [_kReadOnlyToolNames]）；
/// Auto 与 Code 同样全能力，差别只在审批门。
({List<McpToolDefinition> definitions, Map<String, ToolRoute> routes})
    _catalogFor(
  Set<AgentToolGroup> groups, {
  AgentSessionMode mode = AgentSessionMode.code,
  bool enableSubagents = true,
}) {
  final readOnly =
      mode == AgentSessionMode.ask || mode == AgentSessionMode.plan;
  final definitions = <McpToolDefinition>[...kAgentControlToolDefinitions];
  final routes = <String, ToolRoute>{};

  void addServer(String server, ToolRoute Function(String name) routeOf) {
    for (final def in builtinToolsFor(server)) {
      if (readOnly && !_kReadOnlyToolNames.contains(def.name)) continue;
      definitions.add(def);
      routes[def.name] = routeOf(def.name);
    }
  }

  if (groups.contains(AgentToolGroup.fileEditor)) {
    addServer(kFileEditorServerName, FileEditorToolRoute.new);
  }
  if (groups.contains(AgentToolGroup.terminal) && !readOnly) {
    addServer(kTerminalServerName, TerminalToolRoute.new);
  }
  if (groups.contains(AgentToolGroup.knowledgeBase)) {
    addServer(kKnowledgeServerName, KnowledgeToolRoute.new);
  }
  if (groups.contains(AgentToolGroup.webSearch)) {
    definitions.add(kBuiltinWebSearchToolDefinition);
    routes[kBuiltinWebSearchToolName] = const WebSearchToolRoute();
  }
  // 子代理可用时 read_skill 必须同时可用（详细用法在内置技能
  // 「子代理派发」里，系统提示只留一句能力声明，模型按需读取）。
  if (groups.contains(AgentToolGroup.skills) || enableSubagents) {
    definitions.add(kReadSkillToolDefinition);
    routes[kReadSkillToolName] = const SkillReadToolRoute();
  }
  // 子代理派生入口（引擎内部处理，不进 executor）；子代理自身
  // 不再暴露，避免无限嵌套。
  if (enableSubagents) {
    definitions.add(kSpawnSubagentToolDefinition);
  }
  return (definitions: definitions, routes: routes);
}

/// 真实 LLM adapter：把 agent 事件流重放为 provider 中立的
/// [LlmMessage] 列表，经 [appLlmGatewayFactory] 流式调用当前默认模型。
class _GatewayAgentLlmClient implements AgentLlmClient {
  _GatewayAgentLlmClient(this._refOf, this._profile, this._definitions);

  final Ref Function() _refOf;
  final AgentProfile _profile;
  final List<McpToolDefinition> _definitions;

  @override
  Future<AgentLlmTurn> completeTurn(
    AgentLlmContext context, {
    void Function(String textSoFar)? onTextDelta,
    void Function(String reasoningSoFar)? onReasoningDelta,
    AgentCancellationToken? cancel,
  }) async {
    final ref = _refOf();
    final current = await ref.read(appCurrentModelProvider.future);
    if (current == null) {
      throw StateError('未配置模型：请先在 设置 → 模型服务 里添加并选中默认模型');
    }
    final model = effectiveModelFor(current);
    final gateway = ref.read(appLlmGatewayFactoryProvider).forModel(model);

    final system = buildAgentSystemPrompt(
      task: context.task,
      profile: _profile,
      events: context.events,
      environmentContext: await _environmentContext(ref),
      projectInstructions: await _projectInstructions(ref),
    );

    final request = LlmChatRequest(
      model: model,
      messages: _replayMessages(context.events),
      system: system,
      tools: _definitions,
    );

    // agent 侧协作取消 → 域层 LlmCancelToken（真正中断底层 HTTP 流）。
    final llmCancel = LlmCancelToken();
    final poller = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (cancel?.stopRequested ?? false) llmCancel.cancel();
    });

    final buffer = StringBuffer();
    final reasoning = StringBuffer();
    final calls = <LlmToolCall>[];
    var totalTokens = 0;
    try {
      await for (final chunk
          in gateway.streamChat(request, cancelToken: llmCancel)) {
        switch (chunk) {
          case LlmTextDelta(:final text):
            buffer.write(text);
            onTextDelta?.call(buffer.toString());
          case LlmReasoningDelta(:final text):
            reasoning.write(text);
            onReasoningDelta?.call(reasoning.toString());
          case LlmToolCallChunk(:final call):
            calls.add(call);
          case LlmDone(usage: final usage):
            if (usage != null) totalTokens = usage.totalTokens;
        }
      }
    } on Object {
      // 用户暂停/终止：取消中断流属预期，保留已产出的部分文本。
      if (llmCancel.isCancelled) {
        return AgentLlmTurn(text: buffer.toString());
      }
      rethrow;
    } finally {
      poller.cancel();
    }

    return AgentLlmTurn(
      text: buffer.toString(),
      tokensUsed: totalTokens,
      toolCalls: [
        for (final call in calls)
          AgentToolCallRequest(
            id: call.id.isEmpty ? call.name : call.id,
            name: call.name,
            argsJson: call.arguments,
            argSummary: _summarizeArgs(call.name, call.arguments),
          ),
      ],
    );
  }

  @override
  Future<String> summarizeForCompaction(
    AgentTask task,
    List<AgentEvent> events,
  ) async {
    final ref = _refOf();
    final current = await ref.read(appCurrentModelProvider.future);
    if (current == null) return '';
    final model = effectiveModelFor(current);
    final gateway = ref.read(appLlmGatewayFactoryProvider).forModel(model);

    final request = LlmChatRequest(
      model: model,
      messages: [
        LlmMessage(
          role: MessageRole.user,
          content: _compactionTranscript(events),
        ),
      ],
      system: '你是上下文压缩器。把下面一段智能体执行过程压缩成简洁摘要，'
          '供后续循环替代原文继续任务。必须保留：用户的目标与约束、已完成的'
          '关键动作及结果、重要文件路径/命令/数据、当前待办与未解决问题。'
          '直接输出摘要正文，不要寒暄。',
    );

    final buffer = StringBuffer();
    await for (final chunk in gateway.streamChat(request)) {
      if (chunk is LlmTextDelta) buffer.write(chunk.text);
    }
    return buffer.toString();
  }

  /// [2 环境上下文]：平台 + 工作区摘要 + 本轮可用工具清单
  /// （+ spawn_subagent 可用时的自定义子代理档案清单）。
  Future<String> _environmentContext(Ref ref) async {
    String? workspace;
    try {
      workspace = await buildWorkspaceContextSection(ref);
    } catch (_) {
      workspace = null;
    }
    final toolNames = [for (final d in _definitions) d.name].join('、');
    return [
      '平台：${Platform.operatingSystem}',
      if (workspace != null) workspace,
      '可用工具：$toolNames',
      ...await _customSubagentsSection(ref),
    ].join('\n');
  }

  /// 自定义子代理档案清单（工作区 .aetherlink/agents / .cursor/agents 的
  /// markdown 定义）：spawn_subagent 的 type 可填档案名按需委派。
  Future<List<String>> _customSubagentsSection(Ref ref) async {
    if (!_definitions.any((d) => d.name == kToolSpawnSubagent)) {
      return const [];
    }
    List<AgentSubagentProfile> profiles;
    try {
      profiles = await loadCustomSubagentProfiles(ref, _profile.workspaceId);
    } catch (_) {
      return const [];
    }
    if (profiles.isEmpty) return const [];
    return [
      '自定义子代理档案（spawn_subagent 的 type 可填档案名）：',
      for (final p in profiles)
        '- ${p.name}（${p.readonly ? '只读' : '可写'}）'
            '${p.description.isNotEmpty ? '：${p.description}' : ''}',
    ];
  }

  /// [5 项目指令]：档案绑定工作区（缺省取当前工作区）根目录的 AGENTS.md。
  Future<String?> _projectInstructions(Ref ref) async {
    try {
      final workspaces = await loadWorkspaces(ref);
      if (workspaces.isEmpty) return null;
      final bound = workspaces
          .where((w) => w.id == _profile.workspaceId)
          .firstOrNull;
      final workspace =
          bound ?? ref.read(currentWorkspaceProvider) ?? workspaces.first;
      final backend = ref.read(workspaceBackendProvider(workspace));
      final root = workspace.root.endsWith('/')
          ? workspace.root.substring(0, workspace.root.length - 1)
          : workspace.root;
      return await backend.readFile('$root/AGENTS.md');
    } catch (_) {
      return null; // 不存在或后端不可用：跳过该层。
    }
  }
}

/// 事件流 → LLM 消息重放：先经 [foldCompactedEvents] 把被压缩覆盖的
/// 早期事件换成摘要条目，再展开：用户消息/助手叙述原样；每个工具事件
/// 展开为 assistant tool_call + 结果回填两条；压缩摘要以标记段落进入
/// 用户消息。计划/状态事件不进消息（计划走系统提示置尾）。
List<LlmMessage> _replayMessages(List<AgentEvent> events) {
  final messages = <LlmMessage>[];
  for (final event in foldCompactedEvents(events)) {
    switch (event) {
      case UserMessageEvent():
        messages.add(
          LlmMessage(role: MessageRole.user, content: event.text),
        );
      case AssistantTextEvent():
        if (event.text.isNotEmpty) {
          messages.add(
            LlmMessage(role: MessageRole.assistant, content: event.text),
          );
        }
      case ToolCallEvent():
        messages.add(
          LlmMessage(
            role: MessageRole.assistant,
            content: '',
            toolCalls: [
              LlmToolCall(
                id: event.id,
                name: event.toolName,
                arguments: event.argsDetail ?? '{}',
              ),
            ],
          ),
        );
        messages.add(
          LlmMessage(
            role: MessageRole.user,
            content: _toolResultText(event),
            toolCallId: event.id,
            toolName: event.toolName,
          ),
        );
      case CompactionEvent():
        messages.add(
          LlmMessage(
            role: MessageRole.user,
            content: '[上下文已压缩]更早的执行过程已压缩为以下摘要：\n'
                '${event.summary}',
          ),
        );
      case ReasoningEvent() ||
            PlanUpdateEvent() ||
            CheckpointEvent() ||
            StatusChangeEvent():
        break;
    }
  }
  return messages;
}

/// 压缩输入的纯文本转录（单条详情截断，控制摘要调用成本）。
String _compactionTranscript(List<AgentEvent> events) {
  String clip(String text, [int max = 2000]) =>
      text.length > max ? '${text.substring(0, max)}…(已截断)' : text;
  final lines = <String>[];
  for (final event in events) {
    switch (event) {
      case UserMessageEvent():
        lines.add('[用户] ${clip(event.text)}');
      case AssistantTextEvent():
        if (event.text.isNotEmpty) lines.add('[助手] ${clip(event.text)}');
      case ToolCallEvent():
        lines.add('[工具 ${event.toolName}] 参数：'
            '${clip(event.argsDetail ?? event.argSummary, 500)}\n'
            '结果：${clip(event.resultDetail ?? event.resultSummary)}');
      case CompactionEvent():
        lines.add('[早期摘要] ${clip(event.summary)}');
      case ReasoningEvent() ||
            PlanUpdateEvent() ||
            CheckpointEvent() ||
            StatusChangeEvent():
        break;
    }
  }
  return lines.join('\n\n');
}

String _toolResultText(ToolCallEvent event) => switch (event.state) {
      AgentToolCallState.success =>
        event.resultDetail ?? event.resultSummary,
      AgentToolCallState.failure =>
        '工具执行失败：${event.resultDetail ?? event.resultSummary}',
      AgentToolCallState.denied => '调用被拒绝：${event.resultSummary}',
      AgentToolCallState.running ||
      AgentToolCallState.waitingApproval =>
        '（工具执行被中断，无结果）',
    };

/// 工具行的单行关键参数（UI 稿 §4.1）：取 path/command/query 一类
/// 最有辨识度的字段，截断到 60 字符。
String _summarizeArgs(String name, String argsJson) {
  try {
    final decoded = jsonDecode(argsJson);
    if (decoded is Map<String, dynamic>) {
      for (final key in const [
        'path',
        'command',
        'query',
        'question',
        'name',
      ]) {
        final value = decoded[key];
        if (value is String && value.isNotEmpty) return _truncate(value);
      }
      final first = decoded.values.firstOrNull;
      if (first is String && first.isNotEmpty) return _truncate(first);
    }
  } catch (_) {}
  return name;
}

String _truncate(String value) =>
    value.length > 60 ? '${value.substring(0, 60)}…' : value;

/// 真实工具执行器：按 [ToolRoute] 分发到既有 shared handler
/// （文件编辑/终端/知识库/网络搜索/技能），工具失败转为结果回填而非抛错。
class _McpAgentToolExecutor implements AgentToolExecutor {
  _McpAgentToolExecutor(Ref Function() refOf, this._routes)
      : _executor = ChatToolExecutor(refOf, assistantId: () => '');

  final Map<String, ToolRoute> _routes;
  final ChatToolExecutor _executor;

  @override
  Future<AgentToolResult> execute(
    AgentToolCallRequest call,
    AgentCancellationToken cancel,
  ) async {
    final route = _routes[call.name];
    if (route == null) {
      return AgentToolResult(
        ok: false,
        summary: '未知工具 ✗',
        detail: '工具 ${call.name} 不在当前智能体的工具集内',
      );
    }

    Map<String, Object?> args;
    try {
      final decoded = jsonDecode(call.argsJson);
      args = decoded is Map<String, dynamic>
          ? decoded
          : const <String, Object?>{};
    } catch (e) {
      return AgentToolResult(
        ok: false,
        summary: '参数解析失败 ✗',
        detail: '工具参数不是合法 JSON：$e',
      );
    }

    // 协作取消 → runTool 的 cancelSignal（terminal_execute 可被中途打断）。
    final interrupted = Completer<void>();
    final poller = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (interrupted.isCompleted) return;
      if (cancel.stopRequested || cancel.consumeToolInterrupt()) {
        interrupted.complete();
      }
    });
    try {
      final result = await _executor.runTool(
        route,
        call.name,
        args,
        cancelSignal: interrupted.future,
      );
      final spilled = await _spillLargeOutput(call.name, result.text);
      return AgentToolResult(
        ok: !result.isError,
        summary: _resultSummary(result),
        detail: spilled.detail,
        overflowPath: spilled.path,
      );
    } on Object catch (e) {
      return AgentToolResult(ok: false, summary: '执行异常 ✗', detail: '$e');
    } finally {
      poller.cancel();
    }
  }

  /// 大输出截断落盘（循环设计稿 §5.2）：超阈值时头尾保留、砍中间，
  /// 全文写应用文档目录 agent_tool_outputs/，回填文本附落盘路径
  /// 提示模型用 read_file 按行范围回读；上下文/事件库只存截断版。
  Future<({String detail, String? path})> _spillLargeOutput(
    String toolName,
    String text,
  ) async {
    const limit = 8000, head = 4000, tail = 2000;
    if (text.length <= limit) return (detail: text, path: null);

    String? path;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/agent_tool_outputs');
      await dir.create(recursive: true);
      final safeName = toolName.replaceAll(RegExp(r'[^\w-]'), '_');
      path =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$safeName.txt';
      await File(path).writeAsString(text);
    } catch (_) {
      path = null;
    }

    final omitted = text.length - head - tail;
    final note = path != null
        ? '\n\n…[输出过长已截断：中间省略 $omitted 字符。'
            '全文共 ${text.length} 字符已保存到 $path，'
            '需要时用 read_file 指定 start_line/end_line 分段回读]…\n\n'
        : '\n\n…[输出过长已截断：中间省略 $omitted 字符]…\n\n';
    return (
      detail: text.substring(0, head) + note + text.substring(text.length - tail),
      path: path,
    );
  }

  String _resultSummary(McpToolResult result) {
    final firstLine = result.text.trim().split('\n').first;
    final head =
        firstLine.length > 40 ? '${firstLine.substring(0, 40)}…' : firstLine;
    return result.isError ? '失败 ✗ $head' : head;
  }
}

/// 真实审批门（三层策略，初稿 §七）：
/// ① 工具风险分级——只读直通（`toolNeedsConfirmation`，终端命令按
///    root 内风险评级）；② 运行级宽限——本任务内用户点过「此工具不再
///    询问」；③ 持久白名单——工具授权白名单命中免审。
/// 越出工作区 root 的终端命令为硬约束：宽限/白名单均不可覆盖。
/// 挂起走 [agentApprovalRegistryProvider]，无超时（用户可能锁屏离场）；
/// 任务被暂停/终止时挂起按拒绝回填，循环在下一个安全点收敛。
class _PolicyApprovalGate implements ApprovalGate {
  _PolicyApprovalGate(this._refOf, this._routes);

  final Ref Function() _refOf;
  final Map<String, ToolRoute> _routes;

  @override
  Future<ApprovalRequirement> evaluate(
    AgentToolCallRequest call,
    AgentTask task,
  ) async {
    final route = _routes[call.name];
    if (route == null) return ApprovalRequirement.allow; // 未知工具由执行器兜底
    final args = _decodeArgs(call.argsJson);
    final ref = _refOf();
    List<Workspace> workspaces;
    try {
      workspaces = await loadWorkspaces(ref);
    } catch (_) {
      workspaces = const [];
    }
    if (!toolNeedsConfirmation(route, call.name, args,
        workspaces: workspaces)) {
      return ApprovalRequirement.allow;
    }
    if (toolAutoApprovedByPolicy(
      ref.read(toolAuthPolicyProvider),
      route,
      call.name,
      args,
      workspaces: workspaces,
    )) {
      return ApprovalRequirement.allow;
    }
    // auto 模式：任务绑定工作区内的写/执行免审批直通；未绑定工作区
    // 或调用越出绑定 root 时不免审（硬约束，与白名单同级）。
    if (task.mode == AgentSessionMode.auto &&
        _autoModeBypasses(task, route, call.name, args, workspaces)) {
      return ApprovalRequirement.allow;
    }
    // 运行级宽限；越界命令不受宽限覆盖（硬约束）。
    final escapesRoot = route is TerminalToolRoute &&
        terminalCommandEscapesRoot(call.name, args, workspaces: workspaces);
    if (!escapesRoot &&
        ref
            .read(agentApprovalRegistryProvider.notifier)
            .hasTaskGrace(task.id, call.name)) {
      return ApprovalRequirement.allow;
    }
    return ApprovalRequirement.needsUser;
  }

  @override
  Future<ApprovalVerdict> waitForVerdict(
    AgentToolCallRequest call,
    AgentTask task,
    AgentCancellationToken cancel,
  ) async {
    final registry = _refOf().read(agentApprovalRegistryProvider.notifier);
    final future = registry.request(task.id, call);
    // 挂起期间任务被暂停/终止 → 按拒绝回填，循环在安全点收敛。
    final poller = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (cancel.stopRequested) {
        registry.respond(
          task.id,
          const AgentApprovalDecision(approved: false, reason: '任务已暂停/终止'),
        );
      }
    });
    final AgentApprovalDecision decision;
    try {
      decision = await future;
    } finally {
      poller.cancel();
    }
    if (decision.approved &&
        decision.scope == AgentApprovalScope.whitelist) {
      final route = _routes[call.name];
      final server = switch (route) {
        FileEditorToolRoute() => kFileEditorServerName,
        TerminalToolRoute() => kTerminalServerName,
        _ => null,
      };
      if (server != null) {
        _refOf()
            .read(toolAuthPolicyProvider.notifier)
            .setTool(server, call.name, autoApprove: true);
      }
    }
    return decision.approved
        ? const ApprovalVerdict.approved()
        : ApprovalVerdict.denied(decision.reason);
  }

  /// auto 模式的免审范围：只覆盖文件编辑与终端两组工作区工具，且所有
  /// 路径/命令必须落在任务绑定工作区 root 内；其余需审批工具照常询问。
  bool _autoModeBypasses(
    AgentTask task,
    ToolRoute route,
    String toolName,
    Map<String, Object?> args,
    List<Workspace> workspaces,
  ) {
    final bound =
        workspaces.where((w) => w.id == task.workspaceId).firstOrNull;
    if (bound == null) return false;
    if (route is FileEditorToolRoute) {
      return fileEditorPathsWithinRoot(args, root: bound.root);
    }
    if (route is TerminalToolRoute) {
      return terminalCommandStaysInBoundRoot(
        toolName,
        args,
        boundWorkspace: bound,
        workspaces: workspaces,
      );
    }
    return false;
  }

  Map<String, Object?> _decodeArgs(String argsJson) {
    try {
      final decoded = jsonDecode(argsJson);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return const <String, Object?>{};
  }
}
