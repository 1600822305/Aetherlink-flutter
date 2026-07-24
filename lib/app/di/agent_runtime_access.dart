import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/agent_file_watch_access.dart';
import 'package:aetherlink_flutter/app/di/agent_hooks_access.dart';
import 'package:aetherlink_flutter/app/di/agent_project_skills_access.dart';
import 'package:aetherlink_flutter/app/di/agent_subagent_access.dart';
import 'package:aetherlink_flutter/app/di/dynamic_tool_catalog.dart';
import 'package:aetherlink_flutter/app/di/mcp_servers_access.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/di/remote_mcp_access.dart';
import 'package:aetherlink_flutter/app/di/skills_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_permission_rules.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/context_breakdown.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_approval_registry.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_compaction.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_compaction_prompt.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_microcompact.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_control_tools.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart'
    show kToolAskUser, kToolUpdatePlan;
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
import 'package:aetherlink_flutter/shared/mcp_tools/browser/browser_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tool_catalog.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/workspace_context.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/knowledge/knowledge_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/load_mcp_tools_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/remote_mcp_client.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/remote_mcp_connection_manager.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/mcp_manage_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/skill_manage_tool.dart';
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
    Model? modelOverride,
  }) async {
    final catalog = _catalogFor(
      profile.tools,
      mode: mode,
      enableSubagents: enableSubagents,
    );
    await _addMcpServerTools(
      _refOf(),
      profile,
      mode,
      catalog,
      defer: enableSubagents,
    );
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
      llm: _GatewayAgentLlmClient(
        _refOf,
        profile,
        catalog,
        modelOverride: modelOverride,
      ),
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

/// 上下文占用分解（工作台「上下文」tab，对标 CC /context）：按与
/// 真实请求相同的构建路径重建系统提示 / 工具定义 / 消息重放，
/// 估算各部分 token 占用。事件流变化时自动重算。
@riverpod
Future<AgentContextBreakdown> agentContextBreakdown(
  Ref ref,
  String taskId,
) async {
  final task = ref
      .watch(agentTasksProvider)
      .where((t) => t.id == taskId)
      .firstOrNull;
  if (task == null) {
    return const AgentContextBreakdown(sections: []);
  }
  final events = await ref.watch(agentTaskEventsProvider(taskId).future);
  final profile = ref
          .watch(agentProfilesProvider)
          .where((p) => p.id == task.profileId)
          .firstOrNull ??
      AgentProfile(
        id: task.profileId,
        name: '',
        emoji: '🤖',
        systemPrompt: '',
        tools: AgentToolGroup.values.toSet(),
      );
  final catalog = _catalogFor(profile.tools, mode: task.mode);
  try {
    await _addMcpServerTools(ref, profile, task.mode, catalog);
  } catch (_) {
    // MCP 服务不可用时分解仍可用（少算 MCP 工具定义）。
  }
  // 与真实请求同源：按原始事件流重建已激活延迟组，否则延迟组
  // 激活后分解显示的工具定义与实际发送不符。
  final definitions = catalog.definitionsFor(
    await _activatedDeferredKeys(ref, catalog, events),
  );
  final client = _GatewayAgentLlmClient(() => ref, profile, catalog);
  final system = buildAgentSystemPrompt(
    task: task,
    profile: profile,
    events: events,
    environmentContext: await client._environmentContext(ref, task, definitions),
    projectInstructions: await client._projectInstructions(ref, task),
  );
  return computeContextBreakdown(
    systemPrompt: system,
    toolDefinitions: definitions,
    messages: _replayMessages(events),
    apiContextTokens: task.contextTokens,
  );
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
  'list_files', 'read_file', 'search_files',
  // 知识库：只读子集（kb_manage 有写操作，排除）
  'kb_list', 'kb_search', 'kb_read',
  // 内置浏览器：只读子集（click/input 有副作用，排除）
  'browser_open', 'browser_read', 'browser_snapshot', 'browser_snapshot_dom',
  'browser_wait',
};

/// 档案工具分组 → 模型可见工具定义 + 名称到 [ToolRoute] 的分发表。
/// 控制工具（update_plan/ask_user/finish_task）恒在，由引擎内部处理。
/// Ask/Plan 模式只保留只读工具（见 [_kReadOnlyToolNames]）；
/// Auto 与 Code 同样全能力，差别只在审批门。
DynamicToolCatalog _catalogFor(
  Set<AgentToolGroup> groups, {
  AgentSessionMode mode = AgentSessionMode.code,
  bool enableSubagents = true,
}) {
  final readOnly =
      mode == AgentSessionMode.ask || mode == AgentSessionMode.plan;
  final definitions = <McpToolDefinition>[...kAgentControlToolDefinitions];
  final deferred = <String, List<McpToolDefinition>>{};
  // 计划模式控制工具（引擎内部处理，对标 CC Enter/ExitPlanMode）：
  // 仅顶层任务暴露（子代理不可切模式）；Code/Auto 可请求进入计划模式，
  // Plan 模式提交方案请求批准退出（Ask 模式两者都不暴露）。
  if (enableSubagents) {
    if (mode == AgentSessionMode.code || mode == AgentSessionMode.auto) {
      definitions.add(kEnterPlanModeToolDefinition);
    } else if (mode == AgentSessionMode.plan) {
      definitions.add(kExitPlanModeToolDefinition);
    }
  }
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
    // 内置浏览器组走渐进披露：定义进延迟组（read_skill 读取
    // 「内置浏览器」技能后下一轮注入），路由照常全量。子代理
    // 上下文短、无需渐进披露，直接常驻。Ask/Plan 只读过滤
    // 对延迟组同样生效。
    final browserDefs = <McpToolDefinition>[];
    for (final def in builtinToolsFor(kBrowserServerName)) {
      if (readOnly && !_kReadOnlyToolNames.contains(def.name)) continue;
      browserDefs.add(def);
      routes[def.name] = BuiltinToolRoute(kBrowserServerName, def.name);
    }
    if (enableSubagents) {
      deferred['builtin-browser'] = browserDefs;
    } else {
      definitions.addAll(browserDefs);
    }
  }
  // MCP 自管理：单一 mcp_manage 工具（最小 schema，config 格式与流程
  // 在内置技能「MCP 服务器管理」，模型按需 read_skill）。写操作走
  // HITL 审批；Ask/Plan 只读模式不暴露。
  if (!readOnly) {
    definitions.add(kMcpManageToolDefinition);
    routes[kMcpManageToolName] = const SettingsToolRoute(kMcpManageToolName);
  }
  // 子代理可用时 read_skill 必须同时可用（详细用法在内置技能
  // 「子代理派发」里，系统提示只留一句能力声明，模型按需读取）。
  if (groups.contains(AgentToolGroup.skills) || enableSubagents) {
    definitions.add(kReadSkillToolDefinition);
    routes[kReadSkillToolName] = const SkillReadToolRoute();
  }
  // 技能库自管理：skill_manage（list 免审，写操作走 HITL 审批）。
  // Ask/Plan 只读模式不暴露。
  if (groups.contains(AgentToolGroup.skills) && !readOnly) {
    definitions.add(kSkillManageToolDefinition);
    routes[kSkillManageToolName] = const SettingsToolRoute(
      kSkillManageToolName,
    );
  }
  // 子代理派生入口（引擎内部处理，不进 executor）；子代理自身
  // 不再暴露，避免无限嵌套。定义走渐进披露：read_skill 读取
  // 「子代理派发」技能后下一轮注入。
  if (enableSubagents) {
    deferred['builtin-subagent-dispatch'] = [kSpawnSubagentToolDefinition];
  }
  return DynamicToolCatalog(
    resident: definitions,
    deferred: deferred,
    routes: routes,
  );
}

/// 按原始事件流重建已激活的延迟组（技能绑定组 + 外部 MCP 组）。
/// 技能库 / 服务器配置加载失败时对应侧 fail-open（视为全部激活）：
/// 宁可多发几个定义，不能让已激活的工具在续跑时消失。
Future<Set<String>> _activatedDeferredKeys(
  Ref ref,
  DynamicToolCatalog catalog,
  List<AgentEvent> events,
) async {
  if (catalog.deferred.isEmpty) return const {};
  final activated = <String>{};
  final skillKeys = catalog.deferred.keys
      .where((k) => !k.startsWith(kMcpDeferredKeyPrefix))
      .toSet();
  if (skillKeys.isNotEmpty) {
    try {
      final skills = await ref.read(skillsProvider.future);
      activated.addAll(activatedSkillIdsFromEvents(events, skills));
    } catch (_) {
      activated.addAll(skillKeys);
    }
  }
  final mcpKeys = catalog.deferred.keys
      .where((k) => k.startsWith(kMcpDeferredKeyPrefix))
      .toSet();
  if (mcpKeys.isNotEmpty) {
    try {
      final servers = await ref.read(mcpServersProvider.future);
      activated.addAll(activatedMcpServerKeysFromEvents(events, servers));
    } catch (_) {
      activated.addAll(mcpKeys);
    }
  }
  return activated;
}

/// 档案勾选的外部 MCP 服务器（远程 / stdio）：在线发现工具并并入目录。
/// Ask/Plan 只读模式不注入（外部工具无法静态判定副作用，整组不暴露，
/// 与终端组同策略）；server 连不上静默跳过不阻塞任务；工具名与
/// 内置工具冲突时内置优先（first-wins）。
///
/// [defer] 时（顶层任务）定义进按服务器分组的延迟组（`mcp:<id>`），
/// 常驻侧只加一个 load_mcp_tools 发现入口；装载成功后下一轮注入该
/// 服务器全部定义。子代理上下文短、保持常驻（与浏览器组同策略）。
/// routes 两种情况下都全量（执行 / 审批 / 重放不受激活状态影响）。
Future<void> _addMcpServerTools(
  Ref ref,
  AgentProfile profile,
  AgentSessionMode mode,
  DynamicToolCatalog catalog, {
  bool defer = true,
}) async {
  if (profile.mcpServerIds.isEmpty) return;
  if (mode == AgentSessionMode.ask || mode == AgentSessionMode.plan) return;
  List<McpServer> servers;
  try {
    servers = await ref.read(mcpServersProvider.future);
  } catch (_) {
    return;
  }
  var hasDeferredGroup = false;
  for (final server in servers) {
    if (!server.isActive) continue;
    if (!profile.mcpServerIds.contains(server.id)) continue;
    try {
      final List<RemoteMcpTool> discovered;
      ToolRoute Function(String wireName) routeOf;
      if (RemoteMcpConnectionManager.isRemote(server)) {
        discovered = await ref
            .read(remoteMcpConnectionManagerProvider)
            .listTools(server);
        routeOf = (wireName) => RemoteToolRoute(server, wireName);
      } else if (StdioMcpConnectionManager.isStdio(server)) {
        discovered = await ref
            .read(stdioMcpConnectionManagerProvider)
            .listTools(server);
        routeOf = (wireName) => StdioToolRoute(server, wireName);
      } else {
        continue;
      }
      final defs = <McpToolDefinition>[];
      for (final tool in discovered) {
        final exposed = tool.definition.name;
        if (catalog.routes.containsKey(exposed)) continue;
        defs.add(tool.definition);
        catalog.routes[exposed] = routeOf(tool.toolName);
      }
      if (defs.isEmpty) continue;
      if (defer) {
        final key = mcpDeferredKey(server.id);
        catalog.deferred[key] = defs;
        catalog.deferredMcpLabels[key] = server.name;
        hasDeferredGroup = true;
      } else {
        catalog.resident.addAll(defs);
      }
    } on Object {
      // 连不上 / 进程拉不起：本次运行跳过该 server。
    }
  }
  if (hasDeferredGroup &&
      !catalog.resident.any((d) => d.name == kLoadMcpToolsToolName)) {
    catalog.resident.add(kLoadMcpToolsToolDefinition);
    catalog.routes[kLoadMcpToolsToolName] = const McpToolsLoadToolRoute();
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
  _GatewayAgentLlmClient(
    this._refOf,
    this._profile,
    this._catalog, {
    Model? modelOverride,
  }) : _lockedModel = modelOverride;

  final Ref Function() _refOf;
  final AgentProfile _profile;
  final DynamicToolCatalog _catalog;

  /// 运行内锁定的模型：首轮解析后本次运行（含压缩）不再跟随默认模型
  /// 切换——重放历史里的 tool_call 结构与 provider 绑定，中途换
  /// provider 会整轮报错把任务打成 failed。暂停/续跑是新运行，会重新解析。
  /// 子代理档案指定 model 时经构造参数预锁。
  Model? _lockedModel;

  /// 计划提醒的节流状态：taskId → 上次注入提醒时的轮次。
  final Map<String, int> _planReminderRound = {};

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

    // 渐进披露：扫原始事件流里成功的 read_skill / load_mcp_tools 调用
    // 确定已激活延迟组，本轮 tools = 常驻 + 已激活组。无状态重算天然
    // 覆盖续跑/重启恢复，与 agentContextBreakdown 同源。
    final definitions = _catalog.definitionsFor(
      await _activatedDeferredKeys(ref, _catalog, context.events),
    );

    final system = buildAgentSystemPrompt(
      task: context.task,
      profile: _profile,
      events: context.events,
      environmentContext:
          await _environmentContext(ref, context.task, definitions),
      projectInstructions: await _projectInstructions(ref, context.task),
    );

    final thinkParams = _reasoningParams(ref);
    final messages = _replayMessages(
      context.events,
      microCompactEnabled: context.microCompactEnabled,
      microCompactTriggerChars: context.microCompactTriggerChars,
    );
    // 计划提醒（对标 CC todo_reminder）：久未更新计划时才把当前计划
    // 快照以置尾 system-reminder 注入（只进本轮上下文不落事件流，
    // 不进 system prompt，前缀缓存友好）。
    final planReminder = _planReminderMessage(context);
    if (planReminder != null) messages.add(planReminder);
    // Plan 模式每轮置尾提醒（对标 CC plan_mode attachment）：只进本轮
    // 上下文不落事件流，长任务中防模型"忘了"自己在计划模式。
    if (context.task.mode == AgentSessionMode.plan) {
      messages.add(const LlmMessage(
        role: MessageRole.user,
        content: '<system-reminder>当前仍处于计划模式：只做只读探索与方案设计，'
            '不要修改任何文件或执行写类操作；方案完整后用 exit_plan_mode 提交'
            '全文请求批准。本提醒由系统注入，与用户消息无关，不要回应它。'
            '</system-reminder>',
      ));
    }
    final request = LlmChatRequest(
      model: model,
      messages: messages,
      system: system,
      tools: definitions,
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
    var finishReason = '';
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
          case LlmDone(usage: final usage, finishReason: final reason):
            if (usage != null) {
              totalTokens = usage.totalTokens;
              promptTokens = usage.promptTokens;
            }
            if (reason != null) finishReason = reason;
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
      finishReason: finishReason,
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
    List<AgentEvent> events, {
    String? customInstructions,
  }) async {
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
      system: compactionSummarySystemPrompt(
        customInstructions: customInstructions,
      ),
    );

    final buffer = StringBuffer();
    await for (final chunk in gateway.streamChat(request)) {
      if (chunk is LlmTextDelta) buffer.write(chunk.text);
    }
    // <analysis> 是草稿纸，落库前剥离，只存 <summary> 正文。
    return extractCompactionSummary(buffer.toString());
  }

  /// [2 环境上下文]：平台 + 工作区摘要 + 本轮可用工具清单
  /// （+ spawn_subagent 可用时的自定义子代理档案清单）。
  /// 工作区摘要锚定任务绑定的工作区，且不列其他工作区（绑定即
  /// 隔离，双作用域设计稿 §3.1）；找不到绑定工作区时退回当前工作区。
  Future<String> _environmentContext(
    Ref ref,
    AgentTask task,
    List<McpToolDefinition> definitions,
  ) async {
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
    final toolNames = [for (final d in definitions) d.name].join('、');
    return [
      '平台：${Platform.operatingSystem}',
      if (workspace != null) workspace,
      if (onSharedStorage)
        '注意：工作区位于 Android 共享存储，文件系统不支持符号链接——'
            'npm/pnpm 已通过环境变量默认禁用 bin 链接，无需再传 --no-bin-links；'
            '其它需要 symlink 的操作（如 ln -s）会失败，请改用复制等替代方案。',
      '可用工具：$toolNames',
      ..._deferredMcpSection(),
      ...await _skillsSection(
        ref,
        task.workspaceId.isNotEmpty ? task.workspaceId : _profile.workspaceId,
      ),
      ...await _customSubagentsSection(ref),
    ].join('\n');
  }

  /// 外部 MCP 延迟组清单：只列服务器名 + 工具名（对标 CC 的
  /// available-deferred-tools），完整定义经 load_mcp_tools 装载后
  /// 下一轮注入。
  List<String> _deferredMcpSection() {
    final entries = _catalog.deferred.entries
        .where((e) => e.key.startsWith(kMcpDeferredKeyPrefix))
        .toList();
    if (entries.isEmpty) return const [];
    return [
      '外部 MCP 服务器（工具定义未装载：需要时先调 load_mcp_tools 装载，'
          '下一轮起可直接调用；重复装载无副作用）：',
      for (final e in entries)
        '- ${_catalog.deferredMcpLabels[e.key] ?? e.key}：'
            '${[for (final d in e.value) d.name].join('、')}',
    ];
  }

  /// 已启用技能清单：read_skill 可读的技能名 + 一句话描述，
  /// 模型按需读取正文（决策 29 skills 联动 / 决策 30）。
  Future<List<String>> _skillsSection(Ref ref, String? workspaceId) async {
    if (!_catalog.resident.any((d) => d.name == kReadSkillToolName)) {
      return const [];
    }
    List<Skill> skills = const [];
    try {
      skills = await ref.read(skillsProvider.future);
    } catch (_) {}
    final enabled = skills.where((s) => s.enabled).toList();
    // 项目级技能（绑定工作区的 .aetherlink/.agents/.claude/.cursor
    // skills 目录）：只随该工作区的任务动态加载，不进全局技能库。
    List<Skill> project = const [];
    try {
      project = await ref.read(projectSkillsProvider(workspaceId).future);
    } catch (_) {}
    if (enabled.isEmpty && project.isEmpty) return const [];
    return [
      '可用技能（read_skill 按名称读取正文）：',
      for (final s in enabled)
        '- ${s.name}${s.description.isNotEmpty ? '：${_truncate(s.description)}' : ''}'
            '${_catalog.deferred.containsKey(s.id) ? '（读取本技能后，对应工具将在下一轮可用）' : ''}',
      for (final s in project)
        '- ${s.name}（项目技能）'
            '${s.description.isNotEmpty ? '：${_truncate(s.description)}' : ''}',
    ];
  }

  /// 自定义子代理档案清单（工作区 .aetherlink/agents / .cursor/agents 的
  /// markdown 定义）：spawn_subagent 的 type 可填档案名按需委派。
  Future<List<String>> _customSubagentsSection(Ref ref) async {
    if (!_catalog.hasTool(kToolSpawnSubagent)) {
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
        '- ${p.name}（${p.readonly ? '只读' : '可写'}'
            '${p.model.isNotEmpty ? '·模型:${p.model}' : ''}'
            '${p.memory ? '·持久记忆' : ''}）'
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

  /// 距上次 update_plan 之后的其他工具调用数达到阈值才提醒。
  static const int _kPlanReminderStaleToolCalls = 10;

  /// 两次提醒之间至少间隔的轮次。
  static const int _kPlanReminderCooldownRounds = 10;

  /// 计划提醒（对标 CC todo_reminder 的双阈值节流）：计划非空且有
  /// 未完成条目、距上次 update_plan 已过 [_kPlanReminderStaleToolCalls]
  /// 个工具调用、且距上次提醒已过 [_kPlanReminderCooldownRounds] 轮
  /// 时，注入一条置尾 system-reminder（不落事件流）。
  LlmMessage? _planReminderMessage(AgentLlmContext context) {
    final events = context.events;
    final plan = events.whereType<PlanUpdateEvent>().lastOrNull;
    if (plan == null || plan.items.isEmpty) return null;
    if (plan.items.every(
        (i) => i.status == AgentPlanItemStatus.completed)) {
      return null;
    }
    var toolCallsSince = 0;
    for (final event in events.reversed) {
      if (event is PlanUpdateEvent) break;
      if (event is ToolCallEvent && event.toolName != kToolUpdatePlan) {
        toolCallsSince++;
      }
    }
    if (toolCallsSince < _kPlanReminderStaleToolCalls) return null;
    final lastRound = _planReminderRound[context.task.id];
    if (lastRound != null &&
        context.task.rounds - lastRound < _kPlanReminderCooldownRounds) {
      return null;
    }
    _planReminderRound[context.task.id] = context.task.rounds;
    final lines = [
      for (final item in plan.items)
        '- [${switch (item.status) {
          AgentPlanItemStatus.pending => ' ',
          AgentPlanItemStatus.inProgress => '~',
          AgentPlanItemStatus.completed => 'x',
        }}] ${item.content}',
    ];
    return LlmMessage(
      role: MessageRole.user,
      content: '<system-reminder>你已有一段时间没有更新计划（update_plan）。'
          '当前计划如下：\n${lines.join('\n')}\n'
          '若计划仍适用，完成/开始条目时记得全量重新提交更新状态；'
          '若已过时请重新提交修订后的计划。本提醒由系统注入，'
          '与用户消息无关，不要向用户提及。</system-reminder>',
    );
  }
}

/// 事件流 → LLM 消息重放：先经 [foldCompactedEvents] 把被压缩覆盖的
/// 早期事件换成摘要条目，再展开：用户消息/助手叙述原样；每个工具事件
/// 展开为 assistant tool_call + 结果回填两条；压缩摘要以标记段落进入
/// 用户消息。计划/状态事件不进消息（计划走系统提示置尾）。
List<LlmMessage> _replayMessages(
  List<AgentEvent> events, {
  bool microCompactEnabled = true,
  int microCompactTriggerChars = kMicroCompactTriggerChars,
}) {
  final messages = <LlmMessage>[];
  // 先折叠、再 microcompact（与引擎 _maybeCompact 同款视图）：超阈值时
  // 较旧的可重取工具输出以占位符进上下文，不改事件流本体。
  // 生效值经 AgentLlmContext 来自引擎 budget，两侧视图保持一致。
  // 工具结果总预算在 microcompact 之后兜底（先清可重取旧输出，仍超
  // 才省略其余最旧结果），两侧视图一致。
  final folded = applyToolResultBudget(microCompactEnabled
      ? microCompactEntries(
          foldCompactedEvents(events),
          triggerChars: microCompactTriggerChars,
        )
      : foldCompactedEvents(events));
  // 提问索引建在折叠后的事件上：提问若已被压缩折叠，其回答退化为
  // 普通用户消息，避免回放出没有前置 tool_call 的 tool 结果。
  final questionsById = {
    for (final event in folded.whereType<UserQuestionEvent>())
      event.id: event,
  };
  // 截图淘汰（浏览器设计稿 §17.2/§20.3）：只让最近 N 张截图以图片
  // 进上下文，更旧的重放为文本占位（文件仍在盘上，UI 回看不受影响）。
  final imageEventIds = [
    for (final event in folded)
      if (event is ToolCallEvent && event.imagePath != null) event.id,
  ];
  final recentImageIds = imageEventIds
      .skip(max(0, imageEventIds.length - kReplayScreenshotKeep))
      .toSet();
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
        // 图片结果注入（浏览器设计稿 §14.4）：工具结果 turn 只能发文本，
        // 图片以紧随其后的 user 图片消息进入上下文。
        final image = _toolResultImage(
          event,
          recent: recentImageIds.contains(event.id),
        );
        if (image != null) messages.add(image);
      case CompactionEvent():
        messages.add(
          LlmMessage(
            role: MessageRole.user,
            content: '[上下文已压缩]更早的执行过程已压缩为以下摘要：\n'
                '${event.summary}',
          ),
        );
        // 压缩后文件恢复（升级计划 ⑥）：被覆盖区间里最近读过的
        // 文件快照随摘要注入，模型不必重读。
        for (final f in event.restoredFiles) {
          messages.add(
            LlmMessage(
              role: MessageRole.user,
              content: '[压缩前读过的文件快照] ${f.path}\n${f.content}',
            ),
          );
        }
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

/// 上下文中保留的最近截图张数（浏览器设计稿 §17.2 建议 N=1~2）。
const int kReplayScreenshotKeep = 2;

/// 图片工具结果→紧随工具结果的 user 图片消息：读 [ToolCallEvent.imagePath]
/// 文件转 base64 注入现成多模态管线；非最近截图或文件丢失时降级为
/// 文本占位，不炸重放。
LlmMessage? _toolResultImage(ToolCallEvent event, {required bool recent}) {
  final path = event.imagePath;
  if (path == null) return null;
  if (!recent) {
    return const LlmMessage(
      role: MessageRole.user,
      content: '[较早的截图已从上下文移除，需要时可重新截图]',
    );
  }
  try {
    final bytes = File(path).readAsBytesSync();
    return LlmMessage(
      role: MessageRole.user,
      content: '[上一条 ${event.toolName} 工具结果的截图]',
      images: [
        LlmContentImage(
          mimeType: event.imageMimeType ?? 'image/jpeg',
          base64Data: base64Encode(bytes),
        ),
      ],
    );
  } catch (_) {
    return const LlmMessage(
      role: MessageRole.user,
      content: '[截图文件已丢失]',
    );
  }
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
  })  : _refOf = refOf,
        _boundWorkspaceId = boundWorkspaceId {
    _executor = ChatToolExecutor(
      refOf,
      assistantId: () => '',
      // 每次 forProfile 组装一个执行器 ≈ 一次智能体运行；用实例级会话键
      // 隔离 file-editor 的读取去重 / 陈旧检测状态。
      sessionId: () => 'agent-run-$_runSequence',
    );
  }

  static int _nextRunSequence = 0;
  final int _runSequence = _nextRunSequence++;

  final Map<String, ToolRoute> _routes;

  /// 任务绑定的工作区 ID：终端/文件工具未显式传 `workspace` 时缺省
  /// 锚定它（而不是内置终端/当前工作区），避免智能体越出绑定工作区
  /// 看到/操作其他终端会话。
  final String? _boundWorkspaceId;
  final Ref Function() _refOf;
  late final ChatToolExecutor _executor;

  @override
  bool isConcurrencySafe(AgentToolCallRequest call) {
    final route = _routes[call.name];
    return route != null && toolRouteIsReadOnly(route);
  }

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
        detail: '工具 ${call.name} 不在当前智能体的工具集内；'
            '若为技能绑定的延迟工具，先用 read_skill 读取对应技能',
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
      // 与中断信号赛跑：cancelSignal 只有部分工具（terminal_execute）
      // 主动响应，其余工具会跑到自然结束——暂停/终止/打断在这类工具上
      // 表现为"点了没反应"。这里统一在信号命中时立即返回中断结果，
      // 引擎回到安全点收敛；底层调用继续在后台自然收尾，结果丢弃
      // （与工具超时路径同款语义）。
      // read_skill 在智能体侧要能读到项目级技能（绑定工作区的
      // skills 目录），合并全局技能库后执行；其余路由照常分发。
      final pending = route is SkillReadToolRoute
          ? _readSkillWithProjectSkills(args)
          : _executor.runTool(
              route,
              call.name,
              args,
              cancelSignal: interrupted.future,
            );
      unawaited(pending.then((_) {}, onError: (_) {}));
      final result = await Future.any<McpToolResult?>([
        pending,
        interrupted.future.then((_) => null),
      ]);
      if (result == null) {
        return const AgentToolResult(
          ok: false,
          summary: '已中断 ✗',
          detail: '用户中断了该工具调用，执行结果已丢弃。',
        );
      }
      final spilled = await _spillLargeOutput(call.name, result.text);
      return AgentToolResult(
        ok: !result.isError,
        summary: _resultSummary(result),
        detail: spilled.detail,
        overflowPath: spilled.path,
        imagePath: result.imagePath,
        imageMimeType: result.imageMimeType,
      );
    } on Object catch (e) {
      return AgentToolResult(ok: false, summary: '执行异常 ✗', detail: '$e');
    } finally {
      cancel.removeListener(onCancelSignal);
    }
  }

  /// 合并全局技能库 + 绑定工作区的项目级技能后执行 read_skill，
  /// 任一侧加载失败不影响另一侧。
  Future<McpToolResult> _readSkillWithProjectSkills(
    Map<String, Object?> args,
  ) async {
    final ref = _refOf();
    final skills = <Skill>[];
    // 项目技能排前：同名时绑定工作区的项目技能优先命中。
    try {
      skills.addAll(
        await ref.read(projectSkillsProvider(_boundWorkspaceId).future),
      );
    } catch (_) {}
    try {
      skills.addAll(await ref.read(skillsProvider.future));
    } catch (_) {}
    return executeReadSkill(skills, args);
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
    // hook 可免审放行（高危命令硬约束不可覆盖）/ 强制拒绝 / 照常审批。
    final verdict = await _hookExecutor?.permissionRequestVerdict(call);
    switch (verdict?.outcome) {
      case AgentHookOutcome.block:
        return ApprovalRequirement.forbid;
      case AgentHookOutcome.allow:
        if (_highRiskHardConstraint(call)) {
          return ApprovalRequirement.needsUser;
        }
        return ApprovalRequirement.allow;
      default:
        return ApprovalRequirement.needsUser;
    }
  }

  /// 高危终端命令硬约束（任何 allow 均不可覆盖）。
  bool _highRiskHardConstraint(AgentToolCallRequest call) {
    final route = _routes[call.name];
    if (route is! TerminalToolRoute) return false;
    return terminalCommandIsHighRisk(call.name, _decodeArgs(call.argsJson));
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
    // ask → 强制审批；allow → 免审直通（高危命令硬约束不可覆盖）。
    final hookVerdict = await _hookExecutor?.preToolUseVerdict(call);
    switch (hookVerdict?.outcome) {
      case AgentHookOutcome.block:
        return ApprovalRequirement.allow;
      case AgentHookOutcome.ask:
        return ApprovalRequirement.needsUser;
      case AgentHookOutcome.allow:
        if (route is TerminalToolRoute &&
            terminalCommandIsHighRisk(call.name, args)) {
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
    // 硬约束：高危终端命令（提权/换根、黑名单、递归强删）强制
    // 审批，任何 allow 规则 / auto 模式均不覆盖。
    if (route is TerminalToolRoute &&
        terminalCommandIsHighRisk(call.name, args)) {
      return ApprovalRequirement.needsUser;
    }
    // 外部 MCP 工具（远程 / stdio）：外部代码无法静态判定副作用，
    // auto 模式免审直通；其余模式靠规则（含会话临时层）放行。
    if ((route is RemoteToolRoute || route is StdioToolRoute) &&
        task.mode == AgentSessionMode.auto) {
      return ApprovalRequirement.allow;
    }
    // auto 模式：终端命令除高危外免审直通；文件编辑限任务绑定
    // 工作区 root 内免审。
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
    // 白名单与用户全局规则是启动后异步从库加载的：判定前先等加载
    // 完成，否则重启后立刻续跑的任务会拿到空规则层，永久授权失效。
    await ref.read(toolAuthPolicyProvider.notifier).ensureLoaded();
    await ref.read(agentPermissionRulesProvider.notifier).ensureLoaded();
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
    return ApprovalVerdict.approved(
      editedPlan: decision.editedPlan,
      autoAccept: decision.autoAccept,
    );
  }

  /// auto 模式的免审范围：终端命令除高危（提权/换根、黑名单、
  /// 递归强删）外全部免审；文件编辑限任务绑定工作区 root 内免审；
  /// 其余需审批工具照常询问。
  bool _autoModeBypasses(
    AgentTask task,
    ToolRoute route,
    String toolName,
    Map<String, Object?> args,
    List<Workspace> workspaces,
  ) {
    if (route is TerminalToolRoute) {
      return !terminalCommandIsHighRisk(toolName, args);
    }
    final bound =
        workspaces.where((w) => w.id == task.workspaceId).firstOrNull;
    if (bound == null) return false;
    if (route is FileEditorToolRoute) {
      return fileEditorPathsWithinRoot(args, root: bound.root);
    }
    return false;
  }

  Map<String, Object?> _decodeArgs(String argsJson) => decodeToolArgsJson(argsJson);
}
