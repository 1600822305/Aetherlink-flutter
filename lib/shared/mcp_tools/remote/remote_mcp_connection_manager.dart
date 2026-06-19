import 'dart:async';

import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/core/network/dio_client.dart';
import 'package:aetherlink_flutter/core/network/network_proxy_config.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/mcp_transport.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/remote_mcp_client.dart';

/// Builds the [Dio] used for MCP transport. Mechanical plumbing only: a short
/// connect timeout (so an unreachable active server fails fast instead of
/// stalling the turn), and no global receive timeout (the legacy SSE GET stream
/// is long-lived; per-request liveness is enforced by [RemoteMcpClient]).
Dio buildMcpDio({NetworkProxyConfig? proxy}) {
  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
  configureDioProxy(dio, proxy);
  return dio;
}

/// Caches one live [RemoteMcpClient] per configured server — the Flutter port of
/// the web `MCPConnectionManager`, minus the in-memory / stdio paths (those are
/// the built-in servers / desktop-only, neither of which applies here). Opens
/// HTTP/SSE connections lazily and reuses them across chat turns; the chat loop
/// and the 设置 详情页「测试」 button both dispatch through it.
class RemoteMcpConnectionManager {
  RemoteMcpConnectionManager({Dio? dio, NetworkProxyConfig? proxy})
    : _dio = dio ?? buildMcpDio(proxy: proxy);

  final Dio _dio;
  final _clients = <String, RemoteMcpClient>{};
  final _pending = <String, Future<RemoteMcpClient>>{};

  /// Whether [server] uses one of the two supported HTTP transports.
  static bool isRemote(McpServer server) =>
      server.type == McpServerType.sse ||
      server.type == McpServerType.streamableHttp ||
      server.type == McpServerType.httpStream;

  /// Discovers [server]'s tools over a live connection (web
  /// `MCPToolExecutor.listTools`), filtering out any in `disabledTools`.
  Future<List<RemoteMcpTool>> listTools(McpServer server) async {
    final client = await _clientFor(server);
    final tools = await client.listTools(server.name);
    final disabled = server.disabledTools?.toSet() ?? const <String>{};
    if (disabled.isEmpty) return tools;
    return tools.where((t) => !disabled.contains(t.toolName)).toList();
  }

  /// Calls [toolName] on [server] (web `MCPToolExecutor.callTool`), honouring the
  /// server's configured timeout.
  Future<McpToolResult> callTool(
    McpServer server,
    String toolName,
    Map<String, Object?> arguments,
  ) async {
    final client = await _clientFor(server);
    return client.callTool(
      toolName,
      arguments,
      timeout: Duration(seconds: server.timeout ?? 60),
    );
  }

  /// Closes a single server's connection and drops it from the cache.
  Future<void> closeServer(McpServer server) async {
    final key = _key(server);
    final client = _clients.remove(key);
    await client?.close();
  }

  /// Closes every cached connection (called when the owning provider disposes).
  Future<void> dispose() async {
    final clients = _clients.values.toList();
    _clients.clear();
    _pending.clear();
    for (final client in clients) {
      await client.close();
    }
  }

  Future<RemoteMcpClient> _clientFor(McpServer server) {
    final key = _key(server);
    final existing = _clients[key];
    if (existing != null) return Future.value(existing);

    final pending = _pending[key];
    if (pending != null) return pending;

    final future = _connect(server);
    _pending[key] = future;
    return future.whenComplete(() => _pending.remove(key));
  }

  Future<RemoteMcpClient> _connect(McpServer server) async {
    final baseUrl = server.baseUrl?.trim();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw const McpTransportException('远程 MCP 服务器缺少 URL');
    }
    final uri = Uri.parse(baseUrl);
    final transport = _transportFor(server, uri);
    final client = RemoteMcpClient(
      transport: transport,
      requestTimeout: Duration(seconds: server.timeout ?? 60),
    );
    try {
      await client.connect();
    } on Object {
      await client.close();
      rethrow;
    }
    _clients[_key(server)] = client;
    return client;
  }

  McpTransport _transportFor(McpServer server, Uri uri) {
    final headers = server.headers;
    // Web `normalizeServerType`: only `streamableHttp` uses the Streamable HTTP
    // transport; `sse` and the deprecated `httpStream` both use legacy SSE.
    if (server.type == McpServerType.streamableHttp) {
      return StreamableHttpTransport(dio: _dio, url: uri, headers: headers);
    }
    return SseClientTransport(dio: _dio, url: uri, headers: headers);
  }

  String _key(McpServer server) =>
      '${server.id}|${server.type.name}|${server.baseUrl}';
}
