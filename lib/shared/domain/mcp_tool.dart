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
    this.imageUrls,
    this.videoUrls,
  });

  final String text;
  final bool isError;

  /// 图片结果落盘路径（截图类工具用，浏览器设计稿 §20.3）：图片不以
  /// base64 进文本回填，由智能体重放层读文件注入多模态图片消息。
  final String? imagePath;

  /// [imagePath] 图片的 MIME 类型（如 `image/jpeg`）。
  final String? imageMimeType;

  /// 生成的图片 URL 列表（`generate_image` 工具用）：http(s) 或 data URL，
  /// 由聊天层落成 IMAGE 消息块直接展示，不回填给模型。
  final List<String>? imageUrls;

  /// 生成的视频 URL 列表（`generate_video` 工具用）：由聊天层落成 VIDEO
  /// 消息块直接展示，不回填给模型。
  final List<String>? videoUrls;
}
