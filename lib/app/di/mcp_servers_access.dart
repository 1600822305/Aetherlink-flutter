/// App-level composition seam re-exposing the settings-owned MCP server store
/// to the chat feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`;
/// only its `domain` is allowed. The MCP 服务器 settings page (settings) owns
/// [McpServers] (the persisted server list + CRUD), but the chat feature will
/// need to read the active servers to assemble tool definitions once the
/// request layer lands (Phase C). It reaches them through this `app/` re-export
/// — the composition root, which may depend on any feature — instead of
/// importing `settings/application` directly. The [McpServer] domain type
/// itself lives in `shared/domain`, so chat imports that directly. Mirrors
/// `quick_phrases_access` (settings → chat).
library;

export 'package:aetherlink_flutter/features/settings/application/mcp_servers_controller.dart'
    show McpServers, mcpServersProvider;
