import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/network_proxy_access.dart';
import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/core/database/database_provider.dart';
import 'package:aetherlink_flutter/core/network/dio_client.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/provider_factory.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/media/media_generation_api.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway_factory.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/media_generation_gateway.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/remote_mcp_connection_manager.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/stdio/stdio_mcp_connection_manager.dart';

export 'package:aetherlink_flutter/core/database/database_provider.dart'
    show appDatabaseProvider;
export 'package:aetherlink_flutter/features/chat/application/chat_debug_seed.dart';
export 'package:aetherlink_flutter/features/chat/application/chat_view_providers.dart';

part 'chat_providers.g.dart';

/// Application-layer DI seam + read view-models that back the ChatPage.
///
/// The page is a pure view: it watches [chatMessagesProvider] /
/// [currentTopicProvider] / [messageBlocksProvider] and never imports `data`
/// (Rule 1). Everything below is the composition that makes those reads real —
/// the M1 persistence stack (Drift [AppDatabase] → [ChatRepositoryImpl]) wired
/// up behind the [ChatRepository] port, with no mocks. An empty database yields
/// an empty list, which the page renders as its empty state.
///
/// M4.2.1 renders stored `main_text` blocks as bubbles, so this file gains a
/// per-message block read ([messageBlocks]) and a debug-only seed
/// ([debugChatSeed]) so the bubbles are visible before sending/streaming land.
/// Sending, streaming, the other 14 block variants and markdown are later
/// slices; this file intentionally exposes only `Future` reads.

/// The chat persistence port, backed by Drift. Upper layers depend on the
/// [ChatRepository] interface; this provider is the one place the `data`
/// implementation is wired in.
@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) =>
    ChatRepositoryImpl(ref.watch(appDatabaseProvider));

/// The LLM gateway factory port, backed by the protocol-selecting
/// `LlmProviderFactory` (M2 `data`) with a runtime `dio`. The [ChatController]
/// depends only on the [LlmGatewayFactory] interface; tests override this with
/// a fake factory (and a fake gateway) so the closed loop runs without a
/// network or a real key.
@Riverpod(keepAlive: true)
LlmGatewayFactory llmGatewayFactory(Ref ref) =>
    LlmProviderFactory(proxy: ref.watch(appNetworkProxyConfigProvider));

/// 图像/视频生成的供应商适配层（OpenAI 兼容 / Gemini / DashScope / Veo /
/// 硅基流动），与 LLM 通道共用同一套 dio 构造（含代理配置）。
@Riverpod(keepAlive: true)
MediaGenerationGateway mediaGenerationApi(Ref ref) => MediaGenerationApi(
  buildLlmDio(proxy: ref.watch(appNetworkProxyConfigProvider)),
);

/// The live MCP connection pool for remote (sse / streamableHttp) servers,
/// shared across chat turns. Kept alive so connections are reused; closed when
/// the container disposes. The chat tool-call loop and the 设置 详情页「测试」
/// button both dispatch tool discovery / execution through it (the latter via
/// the `app/di` re-export, since settings may not import chat internals).
@Riverpod(keepAlive: true)
RemoteMcpConnectionManager remoteMcpConnectionManager(Ref ref) {
  final manager = RemoteMcpConnectionManager(
    proxy: ref.watch(appNetworkProxyConfigProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
}

/// The live MCP connection pool for **stdio** servers (workspace-spawned
/// child processes, 移动端专用). Same shape as
/// [remoteMcpConnectionManager]; the settings stdio 面板 also reads its
/// status / logs via the `app/di` re-export.
@Riverpod(keepAlive: true)
StdioMcpConnectionManager stdioMcpConnectionManager(Ref ref) {
  final manager = StdioMcpConnectionManager(ref);
  ref.onDispose(manager.dispose);
  return manager;
}
