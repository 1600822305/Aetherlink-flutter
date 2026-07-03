import 'dart:async';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/mcp_transport.dart';

/// Thrown when an MCP server returns a JSON-RPC error, or a request times out.
class McpRpcException implements Exception {
  const McpRpcException(this.message, {this.code});

  final String message;
  final int? code;

  @override
  String toString() => 'McpRpcException(${code ?? '-'}): $message';
}

/// A connected MCP client speaking JSON-RPC 2.0 over a [McpTransport] — the
/// hand-rolled Dart port of the SDK `Client` (`@modelcontextprotocol/sdk`),
/// since there is no official Dart SDK. Owns the `initialize` handshake and the
/// `tools/list` / `tools/call` calls the chat loop needs; request/response
/// correlation is by JSON-RPC `id`.
///
/// One instance maps to one live connection; [RemoteMcpConnectionManager]
/// caches them per server.
class RemoteMcpClient {
  RemoteMcpClient({
    required McpTransport transport,
    Duration requestTimeout = const Duration(seconds: 60),
  }) : _transport = transport,
       _requestTimeout = requestTimeout;

  final McpTransport _transport;
  final Duration _requestTimeout;

  final _pending = <int, Completer<Map<String, Object?>>>{};
  StreamSubscription<Map<String, Object?>>? _subscription;
  int _nextId = 0;
  bool _initialized = false;

  /// Performs the MCP handshake: subscribes to inbound messages, sends
  /// `initialize`, then the `notifications/initialized` notification. Idempotent.
  Future<void> connect() async {
    if (_initialized) return;
    await _transport.start();
    _subscription = _transport.messages.listen(
      _onMessage,
      onError: _onStreamError,
    );
    final initResult = await _request('initialize', {
      'protocolVersion': kMcpProtocolVersion,
      'capabilities': <String, Object?>{},
      'clientInfo': {'name': 'AetherLink', 'version': '1.0.0'},
    });
    // 后续请求的 MCP-Protocol-Version 头必须携带服务端协商出的版本。
    final negotiated = initResult['protocolVersion'];
    _transport.setProtocolVersion(
      negotiated is String && negotiated.isNotEmpty
          ? negotiated
          : kMcpProtocolVersion,
    );
    await _transport.send({
      'jsonrpc': '2.0',
      'method': 'notifications/initialized',
    });
    _initialized = true;
  }

  /// Lists the server's tools (`tools/list`), mapping each into the shared
  /// [McpToolDefinition]. [serverName] is woven into a function-call-safe
  /// exposed name (web `buildFunctionCallToolName`); the original wire name is
  /// preserved for dispatch.
  Future<List<RemoteMcpTool>> listTools(String serverName) async {
    final result = await _request('tools/list');
    final tools = result['tools'];
    if (tools is! List) return const <RemoteMcpTool>[];
    final out = <RemoteMcpTool>[];
    for (final raw in tools) {
      if (raw is! Map) continue;
      final name = raw['name'];
      if (name is! String || name.isEmpty) continue;
      final schema = raw['inputSchema'];
      out.add(
        RemoteMcpTool(
          toolName: name,
          definition: McpToolDefinition(
            name: buildFunctionCallToolName(serverName, name),
            description: (raw['description'] as String?) ?? '',
            inputSchema: schema is Map
                ? schema.map((k, v) => MapEntry('$k', v))
                : const <String, Object?>{},
          ),
        ),
      );
    }
    return out;
  }

  /// Calls a tool (`tools/call`) and flattens its content blocks into the shared
  /// [McpToolResult] the chat loop feeds back to the model (web
  /// `MCPCallToolResponse` → text). [timeout] overrides the per-request budget.
  Future<McpToolResult> callTool(
    String toolName,
    Map<String, Object?> arguments, {
    Duration? timeout,
  }) async {
    final result = await _request('tools/call', {
      'name': toolName,
      'arguments': arguments,
    }, timeout);
    final content = result['content'];
    final isError = result['isError'] == true;
    final buffer = <String>[];
    if (content is List) {
      for (final block in content) {
        if (block is! Map) continue;
        final type = block['type'];
        if (type == 'text') {
          final text = block['text'];
          if (text is String) buffer.add(text);
        } else if (type == 'resource') {
          final resource = block['resource'];
          if (resource is Map && resource['text'] is String) {
            buffer.add(resource['text'] as String);
          } else {
            buffer.add('[资源] ${resource is Map ? resource['uri'] ?? '' : ''}');
          }
        } else if (type == 'image') {
          buffer.add('[图片] ${block['mimeType'] ?? ''}');
        }
      }
    }
    return McpToolResult(buffer.join('\n'), isError: isError);
  }

  /// Closes the underlying transport and fails any in-flight requests.
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(const McpRpcException('连接已关闭'));
      }
    }
    _pending.clear();
    await _transport.close();
  }

  Future<Map<String, Object?>> _request(
    String method, [
    Map<String, Object?>? params,
    Duration? timeout,
  ]) {
    final id = _nextId++;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;

    final envelope = <String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    };

    // Fire the send; for Streamable HTTP the reply is read inside `send` and
    // pushed onto the message stream before `send` completes, so the completer
    // is usually already done. Route send failures to the completer.
    unawaited(
      _transport.send(envelope).catchError((Object error, StackTrace stack) {
        final pending = _pending.remove(id);
        if (pending != null && !pending.isCompleted) {
          pending.completeError(error, stack);
        }
      }),
    );

    return completer.future.timeout(
      timeout ?? _requestTimeout,
      onTimeout: () {
        _pending.remove(id);
        throw McpRpcException('请求超时: $method');
      },
    );
  }

  void _onMessage(Map<String, Object?> message) {
    final id = message['id'];
    if (id is! int) return; // server-initiated notification/request — ignore.
    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) return;

    final error = message['error'];
    if (error is Map) {
      completer.completeError(
        McpRpcException(
          (error['message'] as String?) ?? '未知错误',
          code: error['code'] is int ? error['code'] as int : null,
        ),
      );
      return;
    }
    final result = message['result'];
    completer.complete(
      result is Map
          ? result.map((k, v) => MapEntry('$k', v))
          : const <String, Object?>{},
    );
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    }
    _pending.clear();
  }
}

/// A tool discovered on a remote server: the model-facing [definition] (with a
/// function-call-safe name) plus the original [toolName] used on the wire.
class RemoteMcpTool {
  const RemoteMcpTool({required this.toolName, required this.definition});

  final String toolName;
  final McpToolDefinition definition;
}

/// Port of the web `buildFunctionCallToolName`: derives a function-call-safe,
/// ≤63-char tool name from [serverName] + [toolName] so distinct servers don't
/// collide and providers (OpenAI requires `^[a-zA-Z0-9_-]+$`) accept it.
String buildFunctionCallToolName(String serverName, String toolName) {
  final sanitizedServer = serverName.trim().replaceAll('-', '_');
  final sanitizedTool = toolName.trim().replaceAll('-', '_');
  final serverSlice = sanitizedServer.length > 7
      ? sanitizedServer.substring(0, 7)
      : sanitizedServer;

  var name = sanitizedTool;
  if (!sanitizedTool.contains(serverSlice)) {
    name = '$serverSlice-$sanitizedTool';
  }

  name = name.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');

  if (!RegExp('^[a-zA-Z]').hasMatch(name)) {
    name = 'tool-$name';
  }

  name = name.replaceAll(RegExp('[_-]{2,}'), '_');

  if (name.length > 63) {
    name = name.substring(0, 63);
  }

  if (name.endsWith('_') || name.endsWith('-')) {
    name = name.substring(0, name.length - 1);
  }

  return name;
}
