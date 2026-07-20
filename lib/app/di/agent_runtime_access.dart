import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/agent_file_watch_access.dart';
import 'package:aetherlink_flutter/app/di/agent_hooks_access.dart';
import 'package:aetherlink_flutter/app/di/agent_subagent_access.dart';
import 'package:aetherlink_flutter/app/di/mcp_servers_access.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/di/remote_mcp_access.dart';
import 'package:aetherlink_flutter/app/di/skills_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_permission_rules.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_approval_registry.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_compaction.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_control_tools.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart' show kToolAskUser;
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_subagent.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_system_prompt.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_executor.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/approval_gate.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_hooks.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/domain/permission_request.dart';
import 'package:aetherlink_flutter/features/agent/domain/permission_rule.dart';
import 'package:aetherlink_flutter/features/agent/domain/shell_command_patterns.dart';
import 'package:aetherlink_flutter/features/agent/domain/subagent_profile.dart';
import 'package:aetherlink_flutter/features/chat/application/parameter_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_confirmation.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_executor.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_cancel_token.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_content_image.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_tool_call.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tool_catalog.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/workspace_context.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/knowledge/knowledge_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/remote_mcp_connection_manager.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/tool_auth_policy.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/skill_read_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/stdio/stdio_mcp_connection_manager.dart';
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

  Future<
      ({
        AgentLlmClient llm,
        AgentToolExecutor tools,
        ApprovalGate approval,
        Future<String?> Function() stopGuard,
        Future<String?> Function() subagentStopGuard,
        String? Function() hookStopSignal,
        Future<void> Function(AgentHookEvent event) lifecycleHooks,
        Future<void> Function(String message, {String notificationType})
            notificationHooks,
        Future<void> Function(AgentHookEvent event, {String summary})
            compactionHooks,
        AgentWorkspaceFileWatcher fileWatcher,
        void Function(AgentHookTimelineSink? sink) setHookTimeline,
        void Function(AgentHookRewakeSink? sink) setHookRewake,
      })> forProfile(
    AgentProfile profile, {
    AgentSessionMode mode = AgentSessionMode.code,
    bool enableSubagents = true,
    String? boundWorkspaceId,
  }) async {
    final catalog = _catalogFor(
      profile.tools,
      mode: mode,
      enableSubagents: enableSubagents,
    );
    await _addMcpServerTools(_refOf(), profile, mode, catalog);
    final hooked = HookedAgentToolExecutor(
      _refOf,
      _McpAgentToolExecutor(
        _refOf,
        catalog.routes,
        boundWorkspaceId: boundWorkspaceId,
      ),
      catalog.routes,
      boundWorkspaceId: boundWorkspaceId,
    );
    return (
      llm: _GatewayAgentLlmClient(_refOf, profile, catalog.definitions),
      tools: hooked,
      approval: _PolicyApprovalGate(_refOf, catalog.routes, hooks: hooked),
      stopGuard: hooked.runStopHooks,
      subagentStopGuard: hooked.runSubagentStopHooks,
      hookStopSignal: hooked.takeHookStopSignal,
      lifecycleHooks: hooked.runLifecycleHooks,
      notificationHooks: hooked.runNotificationHooks,
      compactionHooks: hooked.runCompactionHooks,
      fileWatcher: AgentWorkspaceFileWatcher(
        _refOf,
        hasHooks: hooked.hasFileChangedHooks,
        runHooks: hooked.runFileChangedHooks,
        boundWorkspaceId: boundWorkspaceId,
      ),
      setHookTimeline: (AgentHookTimelineSink? sink) => hooked.timeline = sink,
      setHookRewake: (AgentHookRewakeSink? sink) => hooked.rewake = sink,
    );
  }

  /// 当前默认模型的显示名（新建任务写 [AgentTask.modelLabel]）。
  Future<String?> currentModelLabel() async {
    final current = await _refOf().read(appCurrentModelProvider.future);
    return current?.model.name;
  }
}

/// Hooks 设置页「试跑」入口：用示例上下文单独执行一条 hook。
/// command 型需要 workspaceId（跑在该工作区的终端里）。
typedef AgentHookTryRun = Future<AgentHookResult> Function(
  AgentHook hook, {
  String? workspaceId,
});

@Riverpod(keepAlive: true)
AgentHookTryRun agentHookTryRun(Ref ref) =>
    (AgentHook hook, {String? workspaceId}) =>
        tryRunAgentHook(ref, hook, workspaceId: workspaceId);

/// 某工作区 hooks.json 原文（Hooks 设置页审阅/信任用）；工作区不存在
/// 或无文件返回 null。
@riverpod
Future<String?> workspaceHooksFile(Ref ref, String workspaceId) async {
  List<Workspace> workspaces;
  try {
    workspaces = await loadWorkspaces(ref);
  } catch (_) {
    return null;
  }
  final bound = workspaces.where((w) => w.id == workspaceId).firstOrNull;
  if (bound == null) return null;
  return readWorkspaceConfigFile(ref, bound, '.aetherlink/hooks.json');
}

/// 只读硬约束（Ask/Plan 模式，参考 Roo Code 模式×工具组 /
/// Claude Code plan 模式）：副作用工具从源头不暴露给模型（不占
/// 上下文、不会被尝试调用），幻觉调用时由执行器「不在工具集内」
/// 拒绝。终端命令无法静态判定副作用，整个组不暴露。
const Set<String> _kReadOnlyToolNames = {
  // 文件编辑器：只读子集
  'list_files', 'read_file', 'get_file_info', 'search_files',
  'get_diagnostics',
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

/// 档案勾选的外部 MCP 服务器（远程 / stdio）：在线发现工具并并入目录。
/// Ask/Plan 只读模式不注入（外部工具无法静态判定副作用，整组不暴露，
/// 与终端组同策略）；server 连不上静默跳过不阻塞任务；工具名与
/// 内置工具冲突时内置优先（first-wins）。
Future<void> _addMcpServerTools(
  Ref ref,
  AgentProfile profile,
  AgentSessionMode mode,
  ({List<McpToolDefinition> definitions, Map<String, ToolRoute> routes})
      catalog,
) async {
  if (profile.mcpServerIds.isEmpty) return;
  if (mode == AgentSessionMode.ask || mode == AgentSessionMode.plan) return;
  List<McpServer> servers;
  try {
    servers = await ref.read(mcpServersProvider.future);
  } catch (_) {
    return;
  }
  for (final server in servers) {
    if (!server.isActive) continue;
    if (!profile.mcpServerIds.contains(server.id)) continue;
    try {
      if (RemoteMcpConnectionManager.isRemote(server)) {
        final discovered = await ref
            .read(remoteMcpConnectionManagerProvider)
            .listTools(server);
        for (final tool in discovered) {
          final exposed = tool.definition.name;
          if (catalog.routes.containsKey(exposed)) continue;
          catalog.definitions.add(tool.definition);
          catalog.routes[exposed] = RemoteToolRoute(server, tool.toolName);
        }
      } else if (StdioMcpConnectionManager.isStdio(server)) {
        final discovered = await ref
            .read(stdioMcpConnectionManagerProvider)
            .listTools(server);
        for (final tool in discovered) {
          final exposed = tool.definition.name;
          if (catalog.routes.containsKey(exposed)) continue;
          catalog.definitions.add(tool.definition);
          catalog.routes[exposed] = StdioToolRoute(server, tool.toolName);
        }
      }
    } on Object {
      // 连不上 / 进程拉不起：本次运行跳过该 server。
    }
  }
}

/// 全局思考强度参数（与聊天共用 参数设置 里的档位）：仅取启用中的
/// reasoningEffort / thinkingBudget / includeThoughts，未启用为 null。
({String? effort, int? budget, bool? includeThoughts}) _reasoningParams(
  Ref ref,
) {
  final ps = ref.read(parameterSettingsControllerProvider);
  String? effort;
  if (ps.isParameterEnabled('reasoningEffort')) {
    final v = ps.getParameterValue('reasoningEffort');
    if (v is String) effort = v;
  }
  int? budget;
  if (ps.isParameterEnabled('thinkingBudget')) {
    final v = ps.getParameterValue('thinkingBudget');
    if (v is int) budget = v;
    if (v is num) budget = v.toInt();
  }
  bool? includeThoughts;
  if (ps.isParameterEnabled('includeThoughts')) {
    final v = ps.getParameterValue('includeThoughts');
    if (v is bool) includeThoughts = v;
  }
  return (effort: effort, budget: budget, includeThoughts: includeThoughts);
}

/// 真实 LLM adapter：把 agent 事件流重放为 provider 中立的
/// [LlmMessage] 列表，经 [appLlmGatewayFactory] 流式调用当前默认模型。
class _GatewayAgentLlmClient implements AgentLlmClient {
  _GatewayAgentLlmClient(this._refOf, this._profile, this._definitions);

  final Ref Function() _refOf;
  final AgentProfile _profile;
  final List<McpToolDefinition> _definitions;

  /// 运行内锁定的模型：首轮解析后本次运行（含压缩）不再跟随默认模型
  /// 切换——重放历史里的 tool_call 结构与 provider 绑定，中途换
  /// provider 会整轮报错把任务打成 failed。暂停/续跑是新运行，会重新解析。
  Model? _lockedModel;

  Future<Model> _resolveModel(Ref ref) async {
    final locked = _lockedModel;
    if (locked != null) return locked;
    final current = await ref.read(appCurrentModelProvider.future);
    if (current == null) {
      throw StateError('未配置模型：请先在 设置 → 模型服务 里添加并选中默认模型');
    }
    return _lockedModel = effectiveModelFor(current);
  }

  @override
  Future<AgentLlmTurn> completeTurn(
    AgentLlmContext context, {
    void Function(String textSoFar)? onTextDelta,
    void Function(String reasoningSoFar)? onReasoningDelta,
    Future<void> Function(
      String streamKey,
      String? toolName,
      String argsTextSoFar,
    )? onToolCallDelta,
    Future<void> Function(AgentToolCallRequest call, String? streamKey)?
        onToolCall,
    AgentCancellationToken? cancel,
  }) async {
    final ref = _refOf();
    final model = await _resolveModel(ref);
    final gateway = ref.read(appLlmGatewayFactoryProvider).forModel(model);

    final system = buildAgentSystemPrompt(
      task: context.task,
      profile: _profile,
      events: context.events,
      environmentContext: await _environmentContext(ref, context.task),
      projectInstructions: await _projectInstructions(ref, context.task),
    );

    final thinkParams = _reasoningParams(ref);
    final request = LlmChatRequest(
      model: model,
      messages: _replayMessages(context.events),
      system: system,
      tools: _definitions,
      reasoningEffort: thinkParams.effort,
      thinkingBudget: thinkParams.budget,
      includeThoughts: thinkParams.includeThoughts,
    );

    // agent 侧协作取消 → 域层 LlmCancelToken（真正中断底层 HTTP 流）。
    // 「立即打断并发送」在 LLM 流阶段也要生效：中断流后引擎在
    // 安全点消费打断标记并注入排队消息。
    final llmCancel = LlmCancelToken();
    void onCancelSignal() {
      if (cancel == null) return;
      if (cancel.stopRequested || cancel.toolInterruptRequested) {
        llmCancel.cancel();
      }
    }

    cancel?.addListener(onCancelSignal);
    onCancelSignal();

    final buffer = StringBuffer();
    final reasoning = StringBuffer();
    final calls = <LlmToolCall>[];
    // 流式工具参数 delta 的 key → 该调用的 id/name，用于把最终
    // LlmToolCallChunk 对回到同一个流 key（复用同一条事件）。
    final deltaKeys = <String, ({String? id, String? name})>{};
    var totalTokens = 0;
    var promptTokens = 0;
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
          case LlmToolCallDelta(:final key, :final id, :final name, :final argsTextSoFar):
            deltaKeys[key] = (id: id, name: name);
            if (onToolCallDelta != null) {
              await onToolCallDelta(key, name, argsTextSoFar);
            }
          case LlmToolCallChunk(:final call):
            calls.add(call);
            if (onToolCall != null) {
              String? streamKey;
              for (final entry in deltaKeys.entries) {
                final matchesId =
                    call.id.isNotEmpty && entry.value.id == call.id;
                final matchesName = entry.value.id == null &&
                    entry.value.name == call.name;
                if (matchesId || matchesName) {
                  streamKey = entry.key;
                  break;
                }
              }
              // 兜底：id/name 都对不上但只剩一个流 key（个别网关 id 在
              // delta 与最终块间不一致），仍复用该预建事件，避免出现
              // 一条永远停在部分参数的孤儿事件 + 一条重复事件。
              streamKey ??= deltaKeys.length == 1 ? deltaKeys.keys.first : null;
              if (streamKey != null) deltaKeys.remove(streamKey);
              await onToolCall(
                AgentToolCallRequest(
                  id: call.id.isEmpty ? call.name : call.id,
                  name: call.name,
                  argsJson: call.arguments,
                  argSummary: _summarizeArgs(call.name, call.arguments),
                ),
                streamKey,
              );
            }
          case LlmDone(usage: final usage):
            if (usage != null) {
              totalTokens = usage.totalTokens;
              promptTokens = usage.promptTokens;
            }
        }
      }
    } on Object {
      // 用户暂停/终止：取消中断流属预期，保留已产出的部分文本。
      if (llmCancel.isCancelled) {
        return AgentLlmTurn(text: buffer.toString());
      }
      rethrow;
    } finally {
      cancel?.removeListener(onCancelSignal);
    }

    return AgentLlmTurn(
      text: buffer.toString(),
      tokensUsed: totalTokens,
      // 上下文占用取输入侧 promptTokens（totalTokens 含本轮输出，
      // 作为占用展示会高估）；网关未回 usage 时退回 totalTokens。
      contextTokens: promptTokens > 0 ? promptTokens : totalTokens,
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
    // 模型未配置等失败向上抛：引擎会追加一次可见状态事件提示原因，
    // 而不是每轮静默失败导致上下文持续膨胀。
    final model = await _resolveModel(ref);
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
  /// 工作区摘要锚定任务绑定的工作区，且不列其他工作区（绑定即
  /// 隔离，双作用域设计稿 §3.1）；找不到绑定工作区时退回当前工作区。
  Future<String> _environmentContext(Ref ref, AgentTask task) async {
    String? workspace;
    var onSharedStorage = false;
    try {
      final bound = (await loadWorkspaces(ref))
          .where((w) => w.id == task.workspaceId)
          .firstOrNull;
      onSharedStorage = bound != null &&
          (bound.root.startsWith('/storage/emulated/') ||
              bound.root.startsWith('/sdcard'));
      workspace = await buildWorkspaceContextSection(
        ref,
        workspace: bound,
        listOthers: bound == null,
        repoMap: true,
      );
    } catch (_) {
      workspace = null;
    }
    final toolNames = [for (final d in _definitions) d.name].join('、');
    return [
      '平台：${Platform.operatingSystem}',
      if (workspace != null) workspace,
      if (onSharedStorage)
        '注意：工作区位于 Android 共享存储，文件系统不支持符号链接——'
            'npm/pnpm 已通过环境变量默认禁用 bin 链接，无需再传 --no-bin-links；'
            '其它需要 symlink 的操作（如 ln -s）会失败，请改用复制等替代方案。',
      '可用工具：$toolNames',
      ...await _skillsSection(ref),
      ...await _customSubagentsSection(ref),
    ].join('\n');
  }

  /// 已启用技能清单：read_skill 可读的技能名 + 一句话描述，
  /// 模型按需读取正文（决策 29 skills 联动 / 决策 30）。
  Future<List<String>> _skillsSection(Ref ref) async {
    if (!_definitions.any((d) => d.name == kReadSkillToolName)) {
      return const [];
    }
    List<Skill> skills;
    try {
      skills = await ref.read(skillsProvider.future);
    } catch (_) {
      return const [];
    }
    final enabled = skills.where((s) => s.enabled).toList();
    if (enabled.isEmpty) return const [];
    return [
      '可用技能（read_skill 按名称读取正文）：',
      for (final s in enabled)
        '- ${s.name}${s.description.isNotEmpty ? '：${_truncate(s.description)}' : ''}',
    ];
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

  /// [5 项目指令]：任务绑定工作区（缺省取档案绑定/当前工作区）
  /// 根目录的 AGENTS.md。
  Future<String?> _projectInstructions(Ref ref, AgentTask task) async {
    try {
      final workspaces = await loadWorkspaces(ref);
      if (workspaces.isEmpty) return null;
      final bound = workspaces
              .where((w) => w.id == task.workspaceId)
              .firstOrNull ??
          workspaces
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
  final folded = foldCompactedEvents(events);
  // 提问索引建在折叠后的事件上：提问若已被压缩折叠，其回答退化为
  // 普通用户消息，避免回放出没有前置 tool_call 的 tool 结果。
  final questionsById = {
    for (final event in folded.whereType<UserQuestionEvent>())
      event.id: event,
  };
  for (final event in folded) {
    switch (event) {
      case UserMessageEvent():
        final question = questionsById[event.replyToQuestionId];
        if (question?.toolCallId != null) {
          messages.add(
            LlmMessage(
              role: MessageRole.user,
              content: event.text,
              toolCallId: question!.toolCallId,
              toolName: kToolAskUser,
            ),
          );
        } else {
          messages.add(
            LlmMessage(
              role: MessageRole.user,
              content: _userMessageContent(event),
              images: _userMessageImages(event),
            ),
          );
        }
      case UserQuestionEvent():
        if (event.toolCallId != null) {
          messages.add(
            LlmMessage(
              role: MessageRole.assistant,
              content: '',
              toolCalls: [
                LlmToolCall(
                  id: event.toolCallId!,
                  name: kToolAskUser,
                  arguments: event.argsJson ??
                      jsonEncode({
                        'question': event.question,
                        'follow_up': event.suggestions,
                      }),
                ),
              ],
            ),
          );
        } else {
          messages.add(
            LlmMessage(
              role: MessageRole.assistant,
              content: _questionText(event),
            ),
          );
        }
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

/// 用户消息正文：文本类附件（文件片段/引用）以标记段落拼在
/// 正文之后，模型无需再发一轮读文件工具。
String _userMessageContent(UserMessageEvent event) {
  final parts = [event.text];
  for (final a in event.attachments) {
    final text = a.text;
    if (text == null || text.isEmpty) continue;
    parts.add('[附件 ${a.name}]\n$text');
  }
  return parts.join('\n\n');
}

List<LlmContentImage>? _userMessageImages(UserMessageEvent event) {
  final images = [
    for (final a in event.attachments)
      if (a.kind == AgentAttachmentKind.image && a.base64Data != null)
        LlmContentImage(
          mimeType: a.mimeType ?? 'image/jpeg',
          base64Data: a.base64Data!,
        ),
  ];
  return images.isEmpty ? null : images;
}

/// 压缩输入的纯文本转录（单条详情截断，控制摘要调用成本）。
String _compactionTranscript(List<AgentEvent> events) {
  String clip(String text, [int max = 2000]) =>
      text.length > max ? '${text.substring(0, max)}…(已截断)' : text;
  final lines = <String>[];
  for (final event in events) {
    switch (event) {
      case UserMessageEvent():
        lines.add(
          event.replyToQuestionId == null
              ? '[用户] ${clip(event.text)}'
              : '[用户回答] ${clip(event.text)}',
        );
      case UserQuestionEvent():
        lines.add('[助手提问] ${clip(_questionText(event))}');
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

/// ask_user 提问的文本形态（重放/压缩共用）：问题 + 建议答案。
String _questionText(UserQuestionEvent event) => [
      event.question,
      if (event.suggestions.isNotEmpty)
        '建议：${event.suggestions.join(' / ')}',
    ].join('\n');

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
  _McpAgentToolExecutor(
    Ref Function() refOf,
    this._routes, {
    String? boundWorkspaceId,
  })  : _boundWorkspaceId = boundWorkspaceId,
        _executor = ChatToolExecutor(refOf, assistantId: () => '');

  final Map<String, ToolRoute> _routes;

  /// 任务绑定的工作区 ID：终端/文件工具未显式传 `workspace` 时缺省
  /// 锚定它（而不是内置终端/当前工作区），避免智能体越出绑定工作区
  /// 看到/操作其他终端会话。
  final String? _boundWorkspaceId;
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
    if (_boundWorkspaceId != null &&
        (route is TerminalToolRoute || route is FileEditorToolRoute) &&
        (args['workspace'] == null ||
            args['workspace'].toString().trim().isEmpty)) {
      args = {...args, 'workspace': _boundWorkspaceId};
    }

    // 协作取消 → runTool 的 cancelSignal（terminal_execute 可被中途打断）。
    // 打断标记不在这里消费——由引擎在安全点单点消费（P1：分散消费会
    // 导致同轮后续工具误中断/事件卡 running）。
    final interrupted = Completer<void>();
    void onCancelSignal() {
      if (interrupted.isCompleted) return;
      if (cancel.stopRequested || cancel.toolInterruptRequested) {
        interrupted.complete();
      }
    }

    cancel.addListener(onCancelSignal);
    onCancelSignal();
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
      cancel.removeListener(onCancelSignal);
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
      // 文件名附随机后缀：并行子代理/父任务同毫秒调同名工具时
      // 不互相覆盖，一方删任务清理也不会误删另一方仍引用的文件。
      final suffix = Random().nextInt(0xffffff).toRadixString(16);
      path =
          '${dir.path}/${DateTime.now().microsecondsSinceEpoch}'
          '_${safeName}_$suffix.txt';
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

/// 真实审批门（审批重构 PR2：统一规则引擎）：
/// ① 工具风险分级——只读直通（`toolNeedsConfirmation`，终端命令按
///    root 内风险评级）；② 规则引擎——旧工具授权白名单（换算层）、
///    用户全局规则、会话临时规则低→高拼接，任一 pattern 命中 deny
///    即策略禁止，全部 allow 免审；③ auto 模式——绑定工作区内直通。
/// 越出工作区 root 的终端命令为硬约束：任何 allow 规则/auto 均不可覆盖。
/// 挂起走 [agentApprovalRegistryProvider]，无超时（用户可能锁屏离场）；
/// 任务被暂停/终止时挂起按拒绝回填，循环在下一个安全点收敛。
class _PolicyApprovalGate implements ApprovalGate {
  _PolicyApprovalGate(this._refOf, this._routes, {HookedAgentToolExecutor? hooks})
      : _hookExecutor = hooks;

  final Ref Function() _refOf;
  final Map<String, ToolRoute> _routes;
  final HookedAgentToolExecutor? _hookExecutor;

  @override
  Future<ApprovalRequirement> evaluate(
    AgentToolCallRequest call,
    AgentTask task,
  ) async {
    final base = await _evaluateBase(call, task);
    if (base != ApprovalRequirement.needsUser) return base;
    // permissionRequest hooks（对标 CC）：仅在即将弹审批时触发，
    // hook 可免审放行（越 root 硬约束不可覆盖）/ 强制拒绝 / 照常审批。
    final verdict = await _hookExecutor?.permissionRequestVerdict(call);
    switch (verdict?.outcome) {
      case AgentHookOutcome.block:
        return ApprovalRequirement.forbid;
      case AgentHookOutcome.allow:
        if (await _escapesRootHardConstraint(call, task)) {
          return ApprovalRequirement.needsUser;
        }
        return ApprovalRequirement.allow;
      default:
        return ApprovalRequirement.needsUser;
    }
  }

  /// 越出工作区 root 的终端命令硬约束（任何 allow 均不可覆盖）。
  Future<bool> _escapesRootHardConstraint(
    AgentToolCallRequest call,
    AgentTask task,
  ) async {
    final route = _routes[call.name];
    if (route is! TerminalToolRoute) return false;
    var args = _decodeArgs(call.argsJson);
    if (args['workspace'] == null ||
        args['workspace'].toString().trim().isEmpty) {
      args = {...args, 'workspace': task.workspaceId};
    }
    List<Workspace> workspaces;
    try {
      workspaces = await loadWorkspaces(_refOf());
    } catch (_) {
      workspaces = const [];
    }
    return terminalCommandEscapesRoot(call.name, args, workspaces: workspaces);
  }

  Future<ApprovalRequirement> _evaluateBase(
    AgentToolCallRequest call,
    AgentTask task,
  ) async {
    final route = _routes[call.name];
    if (route == null) return ApprovalRequirement.allow; // 未知工具由执行器兜底
    var args = _decodeArgs(call.argsJson);
    // 与执行器一致：缺省 workspace 参数按任务绑定工作区评估（执行时
    // 也会注入同一缺省，审批与实际执行目标不错位）。
    if ((route is TerminalToolRoute || route is FileEditorToolRoute) &&
        (args['workspace'] == null ||
            args['workspace'].toString().trim().isEmpty)) {
      args = {...args, 'workspace': task.workspaceId};
    }
    final ref = _refOf();
    List<Workspace> workspaces;
    try {
      workspaces = await loadWorkspaces(ref);
    } catch (_) {
      workspaces = const [];
    }
    // preToolUse hook 裁决（一次调用只跑一遍，结果缓存给执行器复用）：
    // block → 直接放行到执行器由其拦截（避免先弹审批再被拦）；
    // ask → 强制审批；allow → 免审直通（越 root 硬约束不可覆盖）。
    final hookVerdict = await _hookExecutor?.preToolUseVerdict(call);
    switch (hookVerdict?.outcome) {
      case AgentHookOutcome.block:
        return ApprovalRequirement.allow;
      case AgentHookOutcome.ask:
        return ApprovalRequirement.needsUser;
      case AgentHookOutcome.allow:
        if (route is TerminalToolRoute &&
            terminalCommandEscapesRoot(call.name, args,
                workspaces: workspaces)) {
          return ApprovalRequirement.needsUser;
        }
        return ApprovalRequirement.allow;
      default:
        break;
    }

    if (!toolNeedsConfirmation(route, call.name, args,
        workspaces: workspaces)) {
      return ApprovalRequirement.allow;
    }

    final decision = evaluatePermissionRequest(
      permissionOfToolRoute(route, call.name),
      patternsOfToolCall(route, call.name, args),
      await _ruleLayers(ref, task, workspaces),
    );
    if (decision.action == PermissionAction.deny) {
      return ApprovalRequirement.forbid;
    }
    // 硬约束：越出工作区 root 的终端命令强制审批，任何 allow
    // 规则 / auto 模式均不覆盖（双作用域设计稿 §4.1）。
    if (route is TerminalToolRoute &&
        terminalCommandEscapesRoot(call.name, args, workspaces: workspaces)) {
      return ApprovalRequirement.needsUser;
    }
    // 外部 MCP 工具（远程 / stdio）：外部代码无法静态判定副作用，
    // auto 模式免审直通；其余模式靠规则（含会话临时层）放行。
    if ((route is RemoteToolRoute || route is StdioToolRoute) &&
        task.mode == AgentSessionMode.auto) {
      return ApprovalRequirement.allow;
    }
    // auto 模式：任务绑定工作区内的写/执行免审批直通；未绑定工作区
    // 或调用越出绑定 root 时不免审。
    if (task.mode == AgentSessionMode.auto &&
        _autoModeBypasses(task, route, call.name, args, workspaces)) {
      return ApprovalRequirement.allow;
    }
    if (decision.action == PermissionAction.allow) {
      return ApprovalRequirement.allow;
    }
    return ApprovalRequirement.needsUser;
  }

  /// 规则层低→高：旧工具授权白名单（换算为整工具 allow，保留存量
  /// 授权）→ 用户全局规则 → 工作区规则文件 → 会话临时规则
  /// （审批卡「本任务允许」）。
  Future<List<List<PermissionRule>>> _ruleLayers(
    Ref ref,
    AgentTask task,
    List<Workspace> workspaces,
  ) async {
    final whitelist = ref.read(toolAuthPolicyProvider).autoApproved;
    return [
      [
        for (final key in whitelist)
          PermissionRule(
            permission: key.split('::').last,
            action: PermissionAction.allow,
            layer: PermissionRuleLayer.userGlobal,
          ),
      ],
      ref.read(agentPermissionRulesProvider),
      await _workspaceRules(ref, task, workspaces),
      ref.read(agentApprovalRegistryProvider.notifier).sessionRules(task.id),
    ];
  }

  /// 任务绑定工作区根目录下 `.aetherlink/permissions.json` 里的项目级
  /// 规则（与用户全局规则同格式，可随仓库提交共享）。每个工作区
  /// 每次任务运行只读一次（门实例级缓存）；文件不存在或解析失败
  /// 视为无规则。
  Future<List<PermissionRule>> _workspaceRules(
    Ref ref,
    AgentTask task,
    List<Workspace> workspaces,
  ) async {
    final bound =
        workspaces.where((w) => w.id == task.workspaceId).firstOrNull;
    if (bound == null) return const [];
    final cached = _workspaceRulesCache[bound.id];
    if (cached != null) return cached;
    final rules = decodeAgentPermissionRules(
          await readWorkspaceConfigFile(
              ref, bound, '.aetherlink/permissions.json'),
          layer: PermissionRuleLayer.workspace,
        ) ??
        const <PermissionRule>[];
    _workspaceRulesCache[bound.id] = rules;
    return rules;
  }

  final Map<String, List<PermissionRule>> _workspaceRulesCache = {};

  @override
  Future<ApprovalVerdict> waitForVerdict(
    AgentToolCallRequest call,
    AgentTask task,
    AgentCancellationToken cancel,
  ) async {
    final registry = _refOf().read(agentApprovalRegistryProvider.notifier);
    final route = _routes[call.name];
    final args = _decodeArgs(call.argsJson);
    final command = route is TerminalToolRoute
        ? terminalCommandText(call.name, args)
        : null;
    final future = registry.request(
      task.id,
      call,
      permission:
          route == null ? call.name : permissionOfToolRoute(route, call.name),
      alwaysPatterns: command == null ? const [] : terminalAlwaysPatterns(command),
    );
    // 挂起期间任务被暂停/终止 → 按拒绝回填，循环在安全点收敛。
    void onCancelSignal() {
      if (cancel.stopRequested) {
        registry.respond(
          task.id,
          const AgentApprovalDecision(approved: false, reason: '任务已暂停/终止'),
        );
      }
    }

    cancel.addListener(onCancelSignal);
    onCancelSignal();
    final AgentApprovalDecision decision;
    try {
      decision = await future;
    } finally {
      cancel.removeListener(onCancelSignal);
    }
    if (decision.approved &&
        decision.scope == AgentApprovalScope.whitelist) {
      final server = switch (route) {
        FileEditorToolRoute() => kFileEditorServerName,
        TerminalToolRoute() => kTerminalServerName,
        _ => null,
      };
      if (server != null) {
        _refOf()
            .read(toolAuthPolicyProvider.notifier)
            .setTool(server, call.name, autoApprove: true);
      } else if (route != null) {
        // 旧白名单只覆盖文件/终端两组内置工具；MCP 等其余工具的
        // 永久放行落成用户全局 allow 规则，效果等价。
        _refOf().read(agentPermissionRulesProvider.notifier).add(PermissionRule(
              permission: permissionOfToolRoute(route, call.name),
              action: PermissionAction.allow,
              layer: PermissionRuleLayer.userGlobal,
            ));
      }
    }
    if (!decision.approved) {
      // permissionDenied hooks（对标 CC，观测型）：用户拒绝审批后
      // fire-and-forget，不阻断任务继续。
      final hooks = _hookExecutor;
      if (hooks != null) {
        unawaited(
            hooks.runPermissionDeniedHooks(call, reason: decision.reason));
      }
      return ApprovalVerdict.denied(decision.reason);
    }
    return const ApprovalVerdict.approved();
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

  Map<String, Object?> _decodeArgs(String argsJson) => decodeToolArgsJson(argsJson);
}
