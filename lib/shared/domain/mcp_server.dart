import 'package:freezed_annotation/freezed_annotation.dart';

part 'mcp_server.freezed.dart';
part 'mcp_server.g.dart';

/// MCP server transport type. Mirrors the web `MCPServerType`
/// (`src/shared/types/index.ts`); the JSON values match the source verbatim so
/// configs round-trip with the web app.
enum McpServerType {
  @JsonValue('inMemory')
  inMemory,
  @JsonValue('sse')
  sse,
  @JsonValue('streamableHttp')
  streamableHttp,
  @JsonValue('stdio')
  stdio,
  @JsonValue('httpStream')
  httpStream,
}

/// Which tab an MCP server is surfaced under. Mirrors the web
/// `MCPServerCategory`. (`external` is a Dart built-in identifier, so the
/// constant is [externalServer] while its JSON value stays `'external'`.)
enum McpServerCategory {
  @JsonValue('external')
  externalServer,
  @JsonValue('builtin')
  builtin,
  @JsonValue('assistant')
  assistant,
}

/// A configured MCP server. Mirrors the web `MCPServer` interface
/// (`src/shared/types/index.ts`) — the single source of truth shared by the
/// settings page (which manages it) and, later, the chat feature (which will
/// consume it). Connection / tool-discovery fields are persisted but unused
/// until the request layer lands (Phase C).
@freezed
abstract class McpServer with _$McpServer {
  const factory McpServer({
    required String id,
    required String name,
    required McpServerType type,
    @Default(false) bool isActive,
    String? description,
    String? baseUrl,
    Map<String, String>? headers,
    Map<String, String>? env,
    List<String>? args,
    List<String>? disabledTools,
    Map<String, String>? toolPermissionOverrides,
    String? provider,
    String? logoUrl,
    List<String>? tags,
    McpServerCategory? category,
    String? command,
    String? cwd,
    int? timeout,
  }) = _McpServer;

  factory McpServer.fromJson(Map<String, dynamic> json) =>
      _$McpServerFromJson(json);
}
