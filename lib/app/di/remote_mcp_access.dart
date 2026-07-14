/// App-level composition seam re-exposing the chat-owned remote MCP connection
/// pool to the settings feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`;
/// only its `domain` is allowed. The connection pool
/// ([remoteMcpConnectionManagerProvider]) is kept alive by the chat feature
/// (its primary consumer — the tool-call loop), but the MCP 服务器 详情页
/// (settings) also needs it for the「测试」connection / 工具发现 button. It
/// reaches the provider through this `app/` re-export — the composition root,
/// which may depend on any feature — instead of importing `chat/application`
/// directly. Mirrors `mcp_servers_access` (settings → chat), in reverse.
library;

export 'package:aetherlink_flutter/features/chat/application/chat_providers.dart'
    show remoteMcpConnectionManagerProvider, stdioMcpConnectionManagerProvider;
