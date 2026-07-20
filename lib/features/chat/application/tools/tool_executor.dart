import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/mcp_servers_access.dart';
import 'package:aetherlink_flutter/app/di/remote_mcp_access.dart';
import 'package:aetherlink_flutter/app/di/memory_access.dart';
import 'package:aetherlink_flutter/app/di/skills_access.dart';
import 'package:aetherlink_flutter/core/error/failure.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/features/chat/application/web_search_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/shared/domain/api_key_config.dart';
import 'package:aetherlink_flutter/shared/domain/api_key_manager.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tool_catalog.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/knowledge/knowledge_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/remote_mcp_connection_manager.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/settings_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/skill_read_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/terminal/terminal_tools.dart';
import 'package:aetherlink_flutter/shared/services/web_search_service.dart';

/// Executes one tool call along its [ToolRoute]: built-ins run in-process,
/// remote tools are dispatched to their server through
/// [RemoteMcpConnectionManager]. Owned by the chat controller; both fields are
/// getter callbacks: the active assistant changes as the user switches topics,
/// and the controller's [Ref] object is replaced on every provider rebuild
/// (Riverpod 3 invalidates the previous build's Ref), so a Ref captured at
/// construction would throw once the controller rebuilds mid-turn.
class ChatToolExecutor {
  const ChatToolExecutor(
    this._refOf, {
    required String Function() assistantId,
    String Function()? sessionId,
  })  : _assistantId = assistantId,
        _sessionId = sessionId;

  final Ref Function() _refOf;
  final String Function() _assistantId;

  /// 会话键（聊天话题 / 智能体任务 ID），用于 file-editor 的读取去重与
  /// 陈旧检测状态隔离；未提供时共享空串兜底会话。
  final String Function()? _sessionId;

  Ref get _ref => _refOf();

  String get _sessionKey => _sessionId?.call() ?? '';

  /// Executes one tool call along its [route]: a built-in runs in-process via
  /// [runBuiltinTool]; a remote tool is dispatched to its server through
  /// [RemoteMcpConnectionManager]. A remote failure becomes an error result (fed
  /// back to the model) rather than aborting the whole turn. [exposedName] is the
  /// model-facing name, used only for messages.
  /// [onOutput]（命令类工具）每到一块 stdout/stderr 即回调，供 UI 实时展示。
  Future<McpToolResult> runTool(
    ToolRoute route,
    String exposedName,
    Map<String, Object?> args, {
    Future<void>? cancelSignal,
    void Function(String chunk)? onOutput,
  }) async {
    switch (route) {
      case SettingsToolRoute():
        return await runSettingsTool(_ref, route.toolName, args);
      case FileEditorToolRoute():
        return await runFileEditorTool(
          _ref,
          route.toolName,
          args,
          sessionKey: _sessionKey,
        );
      case BuiltinToolRoute(:final serverName, :final env):
        return await runBuiltinTool(
              serverName,
              route.toolName,
              args,
              env: env,
            ) ??
            McpToolResult('工具 $exposedName 无法在本地执行', isError: true);
      case RemoteToolRoute(:final server):
        try {
          return await _ref
              .read(remoteMcpConnectionManagerProvider)
              .callTool(server, route.toolName, args);
        } on Object catch (error) {
          return McpToolResult(
            '工具 $exposedName 调用失败: ${_errorMessage(error)}',
            isError: true,
          );
        }
      case StdioToolRoute(:final server):
        try {
          return await _ref
              .read(stdioMcpConnectionManagerProvider)
              .callTool(server, route.toolName, args);
        } on Object catch (error) {
          return McpToolResult(
            '工具 $exposedName 调用失败: ${_errorMessage(error)}',
            isError: true,
          );
        }
      case SkillReadToolRoute():
        final skills = await _ref.read(skillsProvider.future);
        return executeReadSkill(skills, args);
      case BridgeToolRoute():
        return _runBridgeTool(args);
      case WebSearchToolRoute():
        return _runWebSearch(args);
      case MemorySearchToolRoute():
        return _runMemorySearch(args);
      case KnowledgeToolRoute():
        return await runKnowledgeTool(_ref, route.toolName, args);
      case TerminalToolRoute():
        return await runTerminalTool(
          _ref,
          route.toolName,
          args,
          cancelSignal: cancelSignal,
          onOutput: onOutput,
        );
    }
  }

  /// Executes one `mcp_bridge` call — the port of `executeBridgeToolCall`.
  /// Dispatches by `action`: list every configured server, list one server's
  /// tools, or call a tool on a server (built-in run in-process, remote over a
  /// live connection). Errors become error results fed back to the model.
  Future<McpToolResult> _runBridgeTool(Map<String, Object?> args) async {
    final action = args['action'] as String?;
    final server = args['server'] as String?;
    final tool = args['tool'] as String?;
    final toolArgs =
        (args['arguments'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    try {
      switch (action) {
        case 'list_servers':
          return _bridgeListServers();
        case 'list_tools':
          return _bridgeListTools(server);
        case 'call':
          return _bridgeCallTool(server, tool, toolArgs);
        default:
          return McpToolResult(
            '未知操作: $action。支持的操作: list_servers, list_tools, call',
            isError: true,
          );
      }
    } on Object catch (error) {
      return McpToolResult(
        'Bridge 执行失败: ${_errorMessage(error)}',
        isError: true,
      );
    }
  }

  Future<McpToolResult> _bridgeListServers() async {
    final servers = await _ref.read(mcpServersProvider.future);
    if (servers.isEmpty) {
      return const McpToolResult('当前没有配置任何 MCP 服务器。请在设置中添加 MCP 服务器。');
    }
    final summary = servers
        .map(
          (s) =>
              '- ${s.name} [${s.isActive ? '✅ 已启用' : '⬚ 未启用'}] ${s.description ?? ''}',
        )
        .join('\n');
    final detail = const JsonEncoder.withIndent('  ').convert([
      for (final s in servers)
        {
          'name': s.name,
          'id': s.id,
          'type': s.type.name,
          'isActive': s.isActive,
          'description': s.description ?? '',
        },
    ]);
    return McpToolResult(
      '可用的 MCP 服务器（${servers.length} 个）：\n$summary\n\n'
      '提示：使用 list_tools 查看具体服务器的工具列表，使用 call 调用工具。\n'
      '注意：仅已启用（✅）的服务器可以调用，未启用的服务器需先在设置中手动启用。\n\n'
      '详细数据：\n$detail',
    );
  }

  Future<McpToolResult> _bridgeListTools(String? serverName) async {
    if (serverName == null || serverName.isEmpty) {
      return const McpToolResult(
        'list_tools 需要提供 server 参数（服务器名称）',
        isError: true,
      );
    }
    final servers = await _ref.read(mcpServersProvider.future);
    final server = _findServerByName(servers, serverName);
    if (server == null) {
      final available = servers.map((s) => s.name).join(', ');
      return McpToolResult(
        '未找到服务器: "$serverName"。可用的服务器: ${available.isEmpty ? '无' : available}',
        isError: true,
      );
    }
    if (!server.isActive) {
      return McpToolResult(
        '服务器 "${server.name}" 未启用，请先在设置中启用该服务器',
        isError: true,
      );
    }
    try {
      final tools = await _bridgeServerTools(server);
      if (tools.isEmpty) {
        return McpToolResult('服务器 "${server.name}" 没有提供任何工具。');
      }
      final summary = tools
          .map(
            (t) =>
                '- ${t.name}: ${t.description.isEmpty ? '无描述' : t.description}',
          )
          .join('\n');
      final detail = const JsonEncoder.withIndent('  ').convert([
        for (final t in tools)
          {
            'name': t.name,
            'description': t.description,
            'parameters': t.inputSchema,
          },
      ]);
      return McpToolResult(
        '服务器 "${server.name}" 提供 ${tools.length} 个工具：\n$summary\n\n详细参数：\n$detail',
      );
    } on Object catch (error) {
      return McpToolResult(
        '获取服务器 "${server.name}" 的工具列表失败: ${_errorMessage(error)}',
        isError: true,
      );
    }
  }

  Future<McpToolResult> _bridgeCallTool(
    String? serverName,
    String? toolName,
    Map<String, Object?> toolArgs,
  ) async {
    if (serverName == null || serverName.isEmpty) {
      return const McpToolResult('call 需要提供 server 参数（服务器名称）', isError: true);
    }
    if (toolName == null || toolName.isEmpty) {
      return const McpToolResult('call 需要提供 tool 参数（工具名称）', isError: true);
    }
    final servers = await _ref.read(mcpServersProvider.future);
    final server = _findServerByName(servers, serverName);
    if (server == null) {
      final available = servers.map((s) => s.name).join(', ');
      return McpToolResult(
        '未找到服务器: "$serverName"。可用的服务器: ${available.isEmpty ? '无' : available}',
        isError: true,
      );
    }
    if (!server.isActive) {
      return McpToolResult(
        '服务器 "${server.name}" 未启用，请先在设置中启用该服务器',
        isError: true,
      );
    }
    if (kRefDependentBuiltins.contains(server.name)) {
      if (server.name == kFileEditorServerName) {
        return await runFileEditorTool(
          _ref,
          toolName,
          toolArgs,
          sessionKey: _sessionKey,
        );
      }
      if (server.name == kKnowledgeServerName) {
        return await runKnowledgeTool(_ref, toolName, toolArgs);
      }
      if (server.name == kTerminalServerName) {
        return await runTerminalTool(_ref, toolName, toolArgs);
      }
      return await runSettingsTool(_ref, toolName, toolArgs);
    }
    if (kLocallyRunnableBuiltins.contains(server.name)) {
      return await runBuiltinTool(
            server.name,
            toolName,
            toolArgs,
            env: server.env,
          ) ??
          McpToolResult('工具 $toolName 无法在本地执行', isError: true);
    }
    return _ref
        .read(remoteMcpConnectionManagerProvider)
        .callTool(server, toolName, toolArgs);
  }

  /// The tools a server exposes for the bridge: built-ins use the static
  /// catalogue (minus `disabledTools`); remote servers are discovered live.
  /// For remote servers the original wire names are returned (not the
  /// function-call-safe exposed names) so `_bridgeCallTool` can pass them
  /// directly to the server.
  Future<List<McpToolDefinition>> _bridgeServerTools(McpServer server) async {
    if (kBuiltinMcpTools.containsKey(server.name)) {
      final disabled = server.disabledTools?.toSet() ?? const <String>{};
      return builtinToolsFor(
        server.name,
      ).where((t) => !disabled.contains(t.name)).toList();
    }
    if (RemoteMcpConnectionManager.isRemote(server)) {
      final discovered = await _ref
          .read(remoteMcpConnectionManagerProvider)
          .listTools(server);
      // Use original wire names (toolName) — not the function-call-safe
      // definition.name — so the bridge can dispatch them directly to the
      // server without a reverse mapping.
      return [
        for (final t in discovered)
          McpToolDefinition(
            name: t.toolName,
            description: t.definition.description,
            inputSchema: t.definition.inputSchema,
          ),
      ];
    }
    return const <McpToolDefinition>[];
  }

  /// Finds a server by name — exact → case-insensitive → substring, the port of
  /// the bridge's `findServerByName`.
  McpServer? _findServerByName(List<McpServer> servers, String name) {
    final lower = name.toLowerCase();
    return servers.where((s) => s.name == name).firstOrNull ??
        servers.where((s) => s.name.toLowerCase() == lower).firstOrNull ??
        servers.where((s) => s.name.toLowerCase().contains(lower)).firstOrNull;
  }

  /// Executes a `builtin_web_search` call by dispatching to the active search
  /// provider via [WebSearchService]. Reads persisted [WebSearchSettings] for
  /// provider config and defaults; per-call args can override maxResults etc.
  Future<McpToolResult> _runWebSearch(Map<String, Object?> args) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return const McpToolResult('搜索关键词不能为空', isError: true);
    }
    final ws = _ref.read(webSearchSettingsControllerProvider);

    // Find the active provider config
    final config = ws.providers
        .where((p) => p.id == ws.activeProviderId && p.isEnabled)
        .firstOrNull;
    if (config == null) {
      return McpToolResult(
        '未找到活跃的搜索提供商 (${ws.activeProviderId})，请在设置中添加并启用一个搜索提供商',
        isError: true,
      );
    }

    final maxResults = (args['maxResults'] as int?) ?? ws.maxResults;
    final language = (args['language'] as String?) ?? ws.language;
    final categories = (args['categories'] as String?) ?? ws.categories;

    Future<McpToolResult> searchWith(SearchProviderConfig c) =>
        WebSearchService.search(
          config: c,
          query: query,
          maxResults: maxResults,
          timeout: ws.timeout,
          language: language,
          categories: categories,
        );

    // Multi-key load balancing + failover, mirroring the chat request layer
    // (`ChatController._streamInto`): with a pool each attempt strategy-selects
    // a usable key via [ApiKeyManager], a failed attempt fails over to the next
    // key, and per-key usage/status is persisted so the 多 Key 管理 stats
    // reflect real traffic. With no pool (or 单 Key 模式) this collapses to a
    // single attempt on the provider's own key.
    final keyPool = config.apiKeys;
    final keyConfig = config.keyManagement;
    final useKeyPool = keyPool.isNotEmpty && (keyConfig?.enabled ?? true);
    if (!useKeyPool) return searchWith(config);

    final keyManager = ApiKeyManager.instance;
    final keyStrategy = keyConfig?.strategy ?? 'round_robin';
    final workingKeys = List<ApiKeyConfig>.of(keyPool);
    final failedKeyIds = <String>{};
    final keyUpdates = <String, ApiKeyConfig>{};

    void persistKeyUpdates() {
      if (keyUpdates.isEmpty) return;
      _ref
          .read(webSearchSettingsControllerProvider.notifier)
          .mergeProviderApiKeys(config.id, keyUpdates.values.toList());
    }

    void recordKeyOutcome(int index, {required bool success, String? error}) {
      final updated = keyManager.updateKeyStatus(
        workingKeys[index],
        success: success,
        config: keyConfig,
        error: error,
      );
      workingKeys[index] = updated;
      keyUpdates[updated.id] = updated;
    }

    McpToolResult? lastResult;
    final hasSingleKeyFallback = config.apiKey.trim().isNotEmpty;
    // Every pool key gets at most one try per search, plus one trailing slot
    // for the single-key fallback when the whole pool is unusable.
    final maxAttempts = workingKeys.length + 1;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final selected = keyManager.selectApiKey(
        workingKeys,
        keyStrategy,
        excludeIds: failedKeyIds,
        config: keyConfig,
      );
      if (selected == null) {
        // Pool exhausted — fall back to the provider's single key once.
        if (hasSingleKeyFallback) lastResult = await searchWith(config);
        break;
      }
      final index = workingKeys.indexWhere((k) => k.id == selected.id);
      final result = await searchWith(config.copyWith(apiKey: selected.key));
      recordKeyOutcome(
        index,
        success: !result.isError,
        error: result.isError ? result.text : null,
      );
      if (!result.isError) {
        persistKeyUpdates();
        return result;
      }
      lastResult = result;
      failedKeyIds.add(selected.id);
    }
    persistKeyUpdates();
    return lastResult ??
        const McpToolResult(
          '没有可用的搜索 API Key（全部被禁用或处于冷却中）',
          isError: true,
        );
  }

  /// Executes one `search_memory` call: retrieves the user's long-term memories
  /// most relevant to `query` (across global + this assistant's private bucket)
  /// via the memory seam. Best-effort — the seam returns a notice string rather
  /// than throwing when memory is off or nothing matches.
  Future<McpToolResult> _runMemorySearch(Map<String, Object?> args) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return const McpToolResult('检索关键词不能为空', isError: true);
    }
    final limit = (args['limit'] as num?)?.toInt();
    final text = await searchChatMemories(
      _ref,
      assistantId: _assistantId(),
      query: query,
      limit: limit,
    );
    return McpToolResult(text);
  }

  String _errorMessage(Object error) {
    if (error is Failure) return error.message;
    return error.toString();
  }
}
