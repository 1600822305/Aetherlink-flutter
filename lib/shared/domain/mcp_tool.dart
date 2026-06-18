/// A tool exposed by an MCP server — the port of the SDK `Tool`
/// (`@modelcontextprotocol/sdk/types`). Carries the [name], a human-readable
/// [description] and the JSON-schema [inputSchema] describing its arguments.
///
/// For built-in servers these are static (see `builtin_tool_catalog.dart`); for
/// external servers they are discovered over a live connection (Phase C).
class McpToolDefinition {
  const McpToolDefinition({
    required this.name,
    required this.description,
    this.inputSchema = const <String, Object?>{},
  });

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
}

/// The result of running an MCP tool — the port of the SDK tool-call result
/// (`{ content: [{ type: 'text', text }], isError }`). [text] is the payload
/// the model receives (usually a JSON string); [isError] flags a failed call.
class McpToolResult {
  const McpToolResult(this.text, {this.isError = false});

  final String text;
  final bool isError;
}
