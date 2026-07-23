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
  const McpToolResult(
    this.text, {
    this.isError = false,
    this.imagePath,
    this.imageMimeType,
  });

  final String text;
  final bool isError;

  /// 图片结果落盘路径（截图类工具用，浏览器设计稿 §20.3）：图片不以
  /// base64 进文本回填，由智能体重放层读文件注入多模态图片消息。
  final String? imagePath;

  /// [imagePath] 图片的 MIME 类型（如 `image/jpeg`）。
  final String? imageMimeType;
}
