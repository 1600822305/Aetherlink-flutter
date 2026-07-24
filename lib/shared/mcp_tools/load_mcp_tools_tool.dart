import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';

/// `load_mcp_tools`：外部 MCP 工具的渐进披露发现入口（对标 CC 的
/// ToolSearchTool）。外部 MCP 服务器的工具定义默认不进 tools 列表，
/// 系统提示只列服务器名 + 工具名清单；模型调用本工具装载某服务器后，
/// 下一轮起该服务器全部工具定义注入。装载成功事件即激活记录
/// （与 read_skill 激活同款事件流扫描恢复）。
const String kLoadMcpToolsToolName = 'load_mcp_tools';

const McpToolDefinition kLoadMcpToolsToolDefinition = McpToolDefinition(
  name: kLoadMcpToolsToolName,
  description:
      '装载一个外部 MCP 服务器的工具：调用后该服务器全部工具定义自下一轮起'
      '可直接调用。可装载的服务器与其工具名清单见系统提示'
      '「外部 MCP 服务器」；重复装载无副作用。',
  inputSchema: {
    'type': 'object',
    'properties': {
      'server': {'type': 'string', 'description': '服务器名称或 id'},
    },
    'required': ['server'],
  },
);

/// 服务器定位：id 精确 → 名称精确 → 忽略大小写 → 子串（与
/// mcp_bridge 的 findServerByName 同款宽松匹配），执行与事件流
/// 激活恢复两侧共用，避免装载成功但没激活的错位。
McpServer? matchMcpServerByName(List<McpServer> servers, String raw) {
  final lower = raw.toLowerCase();
  return servers.where((s) => s.id == raw).firstOrNull ??
      servers.where((s) => s.name == raw).firstOrNull ??
      servers.where((s) => s.name.toLowerCase() == lower).firstOrNull ??
      servers.where((s) => s.name.toLowerCase().contains(lower)).firstOrNull;
}
