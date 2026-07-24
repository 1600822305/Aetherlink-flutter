import 'package:aetherlink_flutter/app/di/memory_access.dart';
import 'package:aetherlink_flutter/features/chat/application/mcp_tools_controller.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/load_mcp_tools_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/mcp_bridge_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/skill_read_tool.dart';

/// The MCP tool context assembled for one chat turn: the resolved [mode], the
/// [tools] to expose (启用 built-ins + 启用 remote servers' discovered tools) and
/// the [routes] map that dispatches each exposed tool name back to its source —
/// a locally-runnable built-in ([BuiltinToolRoute]) or a remote server
/// ([RemoteToolRoute]). [tools] is empty when MCP 工具 is off or no eligible
/// server is active, in which case the turn streams plain text exactly as before.
class McpSetup {
  const McpSetup({
    required this.mode,
    required this.tools,
    required this.routes,
    this.workspaceContext,
  });

  const McpSetup.disabled()
    : mode = McpMode.function,
      tools = const <McpToolDefinition>[],
      routes = const <String, ToolRoute>{},
      workspaceContext = null;

  final McpMode mode;
  final List<McpToolDefinition> tools;
  final Map<String, ToolRoute> routes;

  /// The `[工作区上下文]` system-prompt section, present when the
  /// file-editor tools ride this turn and a workspace is opened.
  final String? workspaceContext;

  bool get hasTools => tools.isNotEmpty;

  /// Expose tools via the model's native function-calling API (`tools` field).
  bool get useFunctionTools => hasTools && mode == McpMode.function;

  /// Describe tools in the system prompt and parse XML `<tool_use>` locally.
  bool get usePromptInjection => hasTools && mode == McpMode.prompt;
}

/// How an exposed tool name dispatches back to its source. [toolName] is the
/// original (un-prefixed) wire name; the map key it is stored under is the
/// model-facing exposed name (identical for built-ins, function-call-safe for
/// remote — see `buildFunctionCallToolName`).
sealed class ToolRoute {
  const ToolRoute(this.toolName);

  final String toolName;
}

/// A settings assistant tool, run in-process with [Ref] access.
class SettingsToolRoute extends ToolRoute {
  const SettingsToolRoute(super.toolName);
}

/// A `@aether/file-editor` workspace tool, run in-process with [Ref] access.
class FileEditorToolRoute extends ToolRoute {
  const FileEditorToolRoute(super.toolName);
}

/// A `@aether/knowledge` tool (kb_list/kb_search/kb_read/kb_manage), run
/// in-process with [Ref] access. Write ops (kb_manage) go through HITL.
class KnowledgeToolRoute extends ToolRoute {
  const KnowledgeToolRoute(super.toolName);
}

/// A `@aether/terminal` tool (terminal_execute / terminal_session_*), run
/// in-process with [Ref] access. Command execution goes through HITL.
class TerminalToolRoute extends ToolRoute {
  const TerminalToolRoute(super.toolName);
}

/// A tool run in-process by [runBuiltinTool] (calculator / time / searxng).
class BuiltinToolRoute extends ToolRoute {
  const BuiltinToolRoute(this.serverName, super.toolName, {this.env});

  final String serverName;
  final Map<String, String>? env;
}

/// The synthetic `read_skill` tool, run in-process against the skills store.
class SkillReadToolRoute extends ToolRoute {
  const SkillReadToolRoute() : super(kReadSkillToolName);
}

/// The synthetic `load_mcp_tools` tool: activates a deferred external MCP
/// server's tool group (definitions injected from the next turn on).
class McpToolsLoadToolRoute extends ToolRoute {
  const McpToolsLoadToolRoute() : super(kLoadMcpToolsToolName);
}

/// The synthetic `mcp_bridge` tool, dispatched in-process to the configured
/// servers (built-in or remote) on demand.
class BridgeToolRoute extends ToolRoute {
  const BridgeToolRoute() : super(kMcpBridgeToolName);
}

/// The `builtin_web_search` tool injected when the 网络搜索 session mode is on.
class WebSearchToolRoute extends ToolRoute {
  const WebSearchToolRoute() : super(kBuiltinWebSearchToolName);
}

/// The `search_memory` tool injected when 记忆 注入方式 is `tool`, letting the
/// model retrieve the user's long-term memories on demand.
class MemorySearchToolRoute extends ToolRoute {
  const MemorySearchToolRoute() : super(kSearchMemoryToolName);
}

/// A tool executed over a live connection to [server] via
/// [RemoteMcpConnectionManager].
class RemoteToolRoute extends ToolRoute {
  const RemoteToolRoute(this.server, super.toolName);

  final McpServer server;
}

/// A tool executed over a live stdio connection to [server] (a
/// workspace-spawned child process) via `StdioMcpConnectionManager`.
class StdioToolRoute extends ToolRoute {
  const StdioToolRoute(this.server, super.toolName);

  final McpServer server;
}

// ── 只读（并发安全）工具分类 ────────────────────────────────────────────────

/// `@aether/file-editor` 中的只读工具。get_diagnostics 虽语义只读，
/// 但会在工作区跑分析进程，不视为并发安全。
const Set<String> _kReadOnlyFileEditorTools = {
  'list_files',
  'read_file',
  'get_file_info',
  'search_files',
};

const Set<String> _kReadOnlyKnowledgeTools = {'kb_list', 'kb_search', 'kb_read'};

const Set<String> _kReadOnlySettingsTools = {
  'list_providers',
  'get_provider',
  'list_models',
  'get_current_model',
};

/// 内置 server（时间/计算/搜索/抓取/日历读取）中的只读工具。
const Set<String> _kReadOnlyBuiltinServerTools = {
  'get_current_time',
  'calculate',
  'convert_base',
  'convert_unit',
  'statistics',
  'searxng_search',
  'searxng_read_url',
  'fetch',
  'metaso_search',
  'metaso_reader',
  'metaso_chat',
  'web_search',
  'get_calendars',
  'get_calendar_events',
  'show_alarms',
};

/// 该工具调用是否只读（并发安全，对标 CC isConcurrencySafe）：同一轮内
/// 可与其他只读调用并行执行。写入/执行命令/语义未知（远端 MCP、bridge）
/// 一律视为不安全，保持串行。
bool toolRouteIsReadOnly(ToolRoute route) => switch (route) {
      FileEditorToolRoute() =>
        _kReadOnlyFileEditorTools.contains(route.toolName),
      KnowledgeToolRoute() => _kReadOnlyKnowledgeTools.contains(route.toolName),
      SettingsToolRoute() => _kReadOnlySettingsTools.contains(route.toolName),
      BuiltinToolRoute() =>
        _kReadOnlyBuiltinServerTools.contains(route.toolName),
      SkillReadToolRoute() => true,
      McpToolsLoadToolRoute() => true,
      WebSearchToolRoute() => true,
      MemorySearchToolRoute() => true,
      BridgeToolRoute() => false,
      TerminalToolRoute() => false,
      RemoteToolRoute() => false,
      StdioToolRoute() => false,
    };

// ── Web Search tool definition ──────────────────────────────────────────────

const String kBuiltinWebSearchToolName = 'builtin_web_search';

const McpToolDefinition kBuiltinWebSearchToolDefinition = McpToolDefinition(
  name: kBuiltinWebSearchToolName,
  description:
      '网络搜索工具，用于查找实时信息、新闻和最新数据。\n\n'
      '使用场景：\n'
      '- 用户询问实时信息（天气、新闻、股票等）\n'
      '- 用户询问你不确定的事实\n'
      '- 用户明确要求搜索网络\n'
      '- 需要最新数据来回答问题',
  inputSchema: {
    'type': 'object',
    'properties': {
      'query': {'type': 'string', 'description': '搜索查询关键词'},
      'maxResults': {'type': 'number', 'description': '最大结果数', 'default': 5},
      'language': {
        'type': 'string',
        'description': '语言代码，如 zh-CN, en',
        'default': 'zh-CN',
      },
      'categories': {
        'type': 'string',
        'description': '搜索类别：general, news, science, it, videos, images',
        'default': 'general',
      },
    },
    'required': ['query'],
  },
);
