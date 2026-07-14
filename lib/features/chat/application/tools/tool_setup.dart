import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/mcp_servers_access.dart';
import 'package:aetherlink_flutter/app/di/remote_mcp_access.dart';
import 'package:aetherlink_flutter/app/di/memory_access.dart';
import 'package:aetherlink_flutter/features/chat/application/input_modes_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/mcp_tools_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tool_catalog.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/workspace_context.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/knowledge/knowledge_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/mcp_bridge_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/remote_mcp_connection_manager.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/stdio/stdio_mcp_connection_manager.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/skill_read_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/terminal/terminal_tools.dart';

/// Assembles the [McpSetup] for the current turn — the port of the web
/// `fetchMcpTools(toolsEnabled, hasSkills)`. Three switches drive it
/// ([McpToolsController]): the 工具 总开关, 桥梁模式, and the 技能 独立开关.
///
/// `read_skill` is injected (and only it) whenever 技能开关 is on AND the
/// assistant has bound, enabled skills — independent of the 工具 总开关 and 桥梁
/// 模式, exactly like the web. With the 工具 总开关 on: 桥梁模式 replaces every
/// server's tools with the single `mcp_bridge` tool; otherwise built-in
/// (locally-runnable) + remote (discovered live) server tools are injected as
/// before, each minus its `disabledTools`. A remote server that is unreachable
/// degrades gracefully — it simply contributes no tools this turn.
///
/// When the 网络搜索 session mode is active ([InputMode.webSearch]), the
/// `builtin_web_search` tool is always injected — independent of the MCP 工具
/// 总开关 — so the model can request web searches even if MCP tools are off.
///
/// [loadBoundSkills] resolves the current assistant's bound, enabled skills;
/// it is a callback so this builder stays independent of the controller's
/// repository access.
Future<McpSetup> buildMcpSetup(
  Ref ref, {
  required Future<List<Skill>> Function() loadBoundSkills,
}) async {
  // Ensure persisted toggles have been loaded from DB before reading — fixes
  // a cold-start race where the default (enabled=false) was used for the
  // first message sent before _hydrate() completed.
  await ref.read(mcpToolsControllerProvider.notifier).hydrated;
  final toolsState = ref.read(mcpToolsControllerProvider);

  final boundSkills = await loadBoundSkills();
  final injectReadSkill = toolsState.skillsEnabled && boundSkills.isNotEmpty;

  final tools = <McpToolDefinition>[];
  final routes = <String, ToolRoute>{};

  void addReadSkill() {
    if (!injectReadSkill) return;
    tools.add(kReadSkillToolDefinition);
    routes[kReadSkillToolName] = const SkillReadToolRoute();
  }

  // 工具 总开关 off: only read_skill and web search may ride along.
  if (!toolsState.enabled) {
    addReadSkill();
    _maybeInjectWebSearch(ref, tools, routes);
    _maybeInjectMemorySearch(ref, tools, routes);
    if (tools.isEmpty) return const McpSetup.disabled();
    return McpSetup(mode: toolsState.mode, tools: tools, routes: routes);
  }

  // 桥梁模式: 1 个 mcp_bridge 工具替代注入全部服务器工具。
  if (toolsState.bridgeMode) {
    tools.add(kMcpBridgeToolDefinition);
    routes[kMcpBridgeToolName] = const BridgeToolRoute();
    addReadSkill();
    _maybeInjectWebSearch(ref, tools, routes);
    _maybeInjectMemorySearch(ref, tools, routes);
    return McpSetup(mode: toolsState.mode, tools: tools, routes: routes);
  }

  final servers = await ref.read(mcpServersProvider.future);
  for (final server in servers) {
    if (!server.isActive) continue;

    // Ref-dependent built-ins (@aether/settings, @aether/file-editor,
    // @aether/knowledge): run in-process with Riverpod [Ref] access to app
    // state.
    if (kRefDependentBuiltins.contains(server.name)) {
      final disabled = server.disabledTools?.toSet() ?? const <String>{};
      for (final tool in builtinToolsFor(server.name)) {
        if (disabled.contains(tool.name)) continue;
        if (routes.containsKey(tool.name)) continue;
        tools.add(tool);
        routes[tool.name] = _routeForRefDependentBuiltin(
          server.name,
          tool.name,
        );
      }
      continue;
    }

    // Built-in (locally-runnable) servers: static catalogue, run in-process.
    if (kLocallyRunnableBuiltins.contains(server.name)) {
      final disabled = server.disabledTools?.toSet() ?? const <String>{};
      for (final tool in builtinToolsFor(server.name)) {
        if (disabled.contains(tool.name)) continue;
        if (routes.containsKey(tool.name)) continue;
        tools.add(tool);
        routes[tool.name] = BuiltinToolRoute(
          server.name,
          tool.name,
          env: server.env,
        );
      }
      continue;
    }

    // Remote (sse / streamableHttp) servers: discover tools live; the manager
    // already filters out `disabledTools` and prefixes names for collision
    // safety. First-wins on duplicate exposed names.
    if (RemoteMcpConnectionManager.isRemote(server)) {
      try {
        final discovered = await ref
            .read(remoteMcpConnectionManagerProvider)
            .listTools(server);
        for (final tool in discovered) {
          final exposed = tool.definition.name;
          if (routes.containsKey(exposed)) continue;
          tools.add(tool.definition);
          routes[exposed] = RemoteToolRoute(server, tool.toolName);
        }
      } on Object {
        // Unreachable / failing server: skip it for this turn.
      }
      continue;
    }

    // stdio servers (workspace-spawned child processes): same live discovery
    // shape as remote, dispatched through the stdio connection manager.
    if (StdioMcpConnectionManager.isStdio(server)) {
      try {
        final discovered = await ref
            .read(stdioMcpConnectionManagerProvider)
            .listTools(server);
        for (final tool in discovered) {
          final exposed = tool.definition.name;
          if (routes.containsKey(exposed)) continue;
          tools.add(tool.definition);
          routes[exposed] = StdioToolRoute(server, tool.toolName);
        }
      } on Object {
        // Process failed to start / crashed: skip it for this turn.
      }
    }
  }

  addReadSkill();
  _maybeInjectWebSearch(ref, tools, routes);
  _maybeInjectMemorySearch(ref, tools, routes);

  // 文件工具在列时把当前工作区上下文直接送进系统提示，模型开局即知可用
  // 工作区（编号/ID/名称），无需专门的列表工具。
  String? workspaceContext;
  if (routes.values.any((r) => r is FileEditorToolRoute)) {
    workspaceContext = await buildWorkspaceContextSection(ref);
  }
  return McpSetup(
    mode: toolsState.mode,
    tools: tools,
    routes: routes,
    workspaceContext: workspaceContext,
  );
}

/// Picks the in-process route for a ref-dependent built-in tool by server.
ToolRoute _routeForRefDependentBuiltin(String serverName, String toolName) {
  if (serverName == kFileEditorServerName) {
    return FileEditorToolRoute(toolName);
  }
  if (serverName == kKnowledgeServerName) {
    return KnowledgeToolRoute(toolName);
  }
  if (serverName == kTerminalServerName) {
    return TerminalToolRoute(toolName);
  }
  return SettingsToolRoute(toolName);
}

/// Injects the `builtin_web_search` tool when [InputMode.webSearch] is active.
/// Uses the existing SearXNG builtin server's `searxng_search` under the hood.
void _maybeInjectWebSearch(
  Ref ref,
  List<McpToolDefinition> tools,
  Map<String, ToolRoute> routes,
) {
  if (ref.read(inputModeControllerProvider) != InputMode.webSearch) return;
  // Avoid duplicating if SearXNG tools are already injected via MCP 总开关.
  if (routes.containsKey(kBuiltinWebSearchToolName)) return;
  tools.add(kBuiltinWebSearchToolDefinition);
  routes[kBuiltinWebSearchToolName] = const WebSearchToolRoute();
}

/// Injects the `search_memory` tool when 记忆 is on and its 注入方式 is `tool`
/// (the model fetches memories on demand instead of having them dumped into
/// the prompt) — independent of the MCP 工具 总开关, mirroring web search.
void _maybeInjectMemorySearch(
  Ref ref,
  List<McpToolDefinition> tools,
  Map<String, ToolRoute> routes,
) {
  if (!shouldExposeMemorySearchTool(ref)) return;
  if (routes.containsKey(kSearchMemoryToolName)) return;
  tools.add(kSearchMemoryToolDefinition);
  routes[kSearchMemoryToolName] = const MemorySearchToolRoute();
}
