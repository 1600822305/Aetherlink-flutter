import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_control_tools.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_system_prompt.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_executor.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
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
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tool_catalog.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/workspace_context.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/knowledge/knowledge_tools.dart';
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

  ({AgentLlmClient llm, AgentToolExecutor tools}) forProfile(
    AgentProfile profile,
  ) {
    final catalog = _catalogFor(profile.tools);
    return (
      llm: _GatewayAgentLlmClient(_refOf, profile, catalog.definitions),
      tools: _McpAgentToolExecutor(_refOf, catalog.routes),
    );
  }

  /// 当前默认模型的显示名（新建任务写 [AgentTask.modelLabel]）。
  Future<String?> currentModelLabel() async {
    final current = await _refOf().read(appCurrentModelProvider.future);
    return current?.model.name;
  }
}

/// 档案工具分组 → 模型可见工具定义 + 名称到 [ToolRoute] 的分发表。
/// 控制工具（update_plan/ask_user/finish_task）恒在，由引擎内部处理。
({List<McpToolDefinition> definitions, Map<String, ToolRoute> routes})
    _catalogFor(Set<AgentToolGroup> groups) {
  final definitions = <McpToolDefinition>[...kAgentControlToolDefinitions];
  final routes = <String, ToolRoute>{};

  void addServer(String server, ToolRoute Function(String name) routeOf) {
    for (final def in builtinToolsFor(server)) {
      definitions.add(def);
      routes[def.name] = routeOf(def.name);
    }
  }

  if (groups.contains(AgentToolGroup.fileEditor)) {
    addServer(kFileEditorServerName, FileEditorToolRoute.new);
  }
  if (groups.contains(AgentToolGroup.terminal)) {
    addServer(kTerminalServerName, TerminalToolRoute.new);
  }
  if (groups.contains(AgentToolGroup.knowledgeBase)) {
    addServer(kKnowledgeServerName, KnowledgeToolRoute.new);
  }
  if (groups.contains(AgentToolGroup.webSearch)) {
    definitions.add(kBuiltinWebSearchToolDefinition);
    routes[kBuiltinWebSearchToolName] = const WebSearchToolRoute();
  }
  if (groups.contains(AgentToolGroup.skills)) {
    definitions.add(kReadSkillToolDefinition);
    routes[kReadSkillToolName] = const SkillReadToolRoute();
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

  /// [2 环境上下文]：平台 + 工作区摘要 + 本轮可用工具清单。
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
    ].join('\n');
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

/// 事件流 → LLM 消息重放：用户消息/助手叙述原样；每个工具事件展开为
/// assistant tool_call + 结果回填两条。计划/状态/压缩事件不进消息
/// （计划走系统提示置尾，压缩属阶段⑤）。
List<LlmMessage> _replayMessages(List<AgentEvent> events) {
  final messages = <LlmMessage>[];
  for (final event in events) {
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
      case ReasoningEvent() ||
            PlanUpdateEvent() ||
            CompactionEvent() ||
            StatusChangeEvent():
        break;
    }
  }
  return messages;
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
      return AgentToolResult(
        ok: !result.isError,
        summary: _resultSummary(result),
        detail: result.text,
      );
    } on Object catch (e) {
      return AgentToolResult(ok: false, summary: '执行异常 ✗', detail: '$e');
    } finally {
      poller.cancel();
    }
  }

  String _resultSummary(McpToolResult result) {
    final firstLine = result.text.trim().split('\n').first;
    final head =
        firstLine.length > 40 ? '${firstLine.substring(0, 40)}…' : firstLine;
    return result.isError ? '失败 ✗ $head' : head;
  }
}
