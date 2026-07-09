import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/calculator_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/fetch_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/grok_search_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/metaso_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/searxng_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/time_tool.dart';

/// Local execution router for built-in MCP servers.
///
/// The chat tool-call loop (Phase C) routes a built-in tool call here; the
/// settings detail page only lists the catalog (`builtin_tool_catalog.dart`).
///
/// Returns `null` for servers that aren't locally runnable (external servers,
/// or servers that need native device plugins).
///
/// [env] is the server's configured environment (e.g. `SEARXNG_BASE_URL`).
Future<McpToolResult?> runBuiltinTool(
  String serverName,
  String toolName,
  Map<String, Object?> args, {
  DateTime? now,
  Map<String, String>? env,
}) async {
  switch (serverName) {
    case '@aether/calculator':
      return runCalculatorTool(toolName, args);
    case '@aether/time':
      return runTimeTool(toolName, args, now: now);
    case '@aether/searxng':
      return runSearxngTool(toolName, args, env: env);
    case '@aether/fetch':
      return runFetchTool(toolName, args);
    case '@aether/metaso-search':
      return runMetasoTool(toolName, args, env: env);
    case '@aether/grok-search':
      return runGrokSearchTool(toolName, args, env: env);
  }
  return null;
}
