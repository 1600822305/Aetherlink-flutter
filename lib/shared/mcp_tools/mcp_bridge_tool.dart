import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';

/// The synthetic tool name the model calls to drive MCP servers dynamically —
/// the port of the web `MCP_BRIDGE_TOOL_NAME` (`McpBridgeTool.ts`).
const String kMcpBridgeToolName = 'mcp_bridge';

/// Virtual server marker for the bridge tool: it belongs to no real MCP server,
/// so dispatch routes it in-process. Matches the web `'__bridge__'`.
const String kBridgeVirtualServer = '__bridge__';

/// The `mcp_bridge` tool definition — the port of `MCP_BRIDGE_TOOL_DEFINITION`.
/// When bridge mode is on, this single tool replaces injecting every server's
/// tools: the model discovers servers/tools and calls them on demand via the
/// `action` argument (`list_servers` / `list_tools` / `call`).
const McpToolDefinition kMcpBridgeToolDefinition = McpToolDefinition(
  name: kMcpBridgeToolName,
  description:
      '动态调用 MCP 工具服务器。支持三种操作：list_servers（列出所有可用服务器）、'
      'list_tools（列出某服务器的工具，需 server）、call（调用工具，需 server、tool、arguments）。',
  inputSchema: {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['list_servers', 'list_tools', 'call'],
        'description': '操作类型',
      },
      'server': {
        'type': 'string',
        'description': '服务器名称（list_tools / call 时必填）',
      },
      'tool': {'type': 'string', 'description': '工具名称（call 时必填）'},
      'arguments': {
        'type': 'object',
        'description': '工具参数（call 时传入）',
        'additionalProperties': true,
      },
    },
    'required': ['action'],
  },
);
