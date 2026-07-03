import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/core/network/sse_decoder.dart';

/// The latest MCP protocol version this client supports, offered in the
/// `initialize` request body; the server may negotiate down.
const String kMcpProtocolVersion = '2025-06-18';

/// A bidirectional channel that carries JSON-RPC messages to and from one MCP
/// server — the Dart port of the SDK `Transport` interface
/// (`@modelcontextprotocol/sdk/shared/transport`). [RemoteMcpClient] sits on top
/// and handles request/response correlation; a transport only moves raw
/// messages.
///
/// Two HTTP transports exist, picked by `McpServerType`:
///   * [StreamableHttpTransport] — the current spec (single endpoint, POST per
///     message; each POST's reply is JSON or an SSE stream).
///   * [SseClientTransport] — the legacy HTTP+SSE transport (a long-lived GET
///     stream for server→client, a POST endpoint announced by an `endpoint`
///     event for client→server).
///
/// CORS is irrelevant here (this is a native Dio client, not a browser), so the
/// web's `MobileSSETransport` / CorsBypass path has no Flutter equivalent.
abstract class McpTransport {
  /// Inbound JSON-RPC messages (responses + server-initiated notifications).
  /// Broadcast so a single late listener in [RemoteMcpClient] never drops the
  /// reply that arrives during the same microtask as the POST.
  Stream<Map<String, Object?>> get messages;

  /// Opens the channel. For [SseClientTransport] this opens the GET stream and
  /// resolves once the server announces its POST endpoint; for
  /// [StreamableHttpTransport] it is a no-op (the first POST drives the
  /// handshake).
  Future<void> start();

  /// Sends one JSON-RPC [message] (request or notification) to the server.
  Future<void> send(Map<String, Object?> message);

  /// Records the protocol version negotiated during `initialize`. Per spec,
  /// the `MCP-Protocol-Version` header carries the **negotiated** version and
  /// is only sent on requests **after** initialization — sending it up front
  /// makes strict servers reject the handshake with HTTP 400
  /// “Invalid MCP-Protocol-Version”.
  void setProtocolVersion(String version);

  /// Tears down the channel and releases the socket.
  Future<void> close();
}

/// Thrown when a transport cannot reach or talk to the server (network failure,
/// non-2xx HTTP status, missing SSE endpoint).
class McpTransportException implements Exception {
  const McpTransportException(this.message);

  final String message;

  @override
  String toString() => 'McpTransportException: $message';
}

/// Merges [headers] with the negotiated MCP protocol-version header (absent
/// until `initialize` completes). Caller-supplied values win.
Map<String, String> _withProtocol(
  Map<String, String>? headers,
  String? protocolVersion,
) => {
  if (protocolVersion != null) 'mcp-protocol-version': protocolVersion,
  ...?headers,
};

/// Streamable HTTP transport (web `StreamableHTTPClientTransport`): every
/// JSON-RPC message is an HTTP POST to a single endpoint. The server replies
/// either with `application/json` (one response) or `text/event-stream` (an SSE
/// stream that ends after delivering the response). A server-assigned
/// `Mcp-Session-Id` from the `initialize` reply is echoed on later requests.
class StreamableHttpTransport implements McpTransport {
  StreamableHttpTransport({
    required Dio dio,
    required Uri url,
    Map<String, String>? headers,
  }) : _dio = dio,
       _url = url,
       _headers = headers;

  final Dio _dio;
  final Uri _url;
  final Map<String, String>? _headers;

  final _controller = StreamController<Map<String, Object?>>.broadcast();
  String? _sessionId;
  String? _protocolVersion;

  @override
  Stream<Map<String, Object?>> get messages => _controller.stream;

  @override
  void setProtocolVersion(String version) => _protocolVersion = version;

  @override
  Future<void> start() async {}

  @override
  Future<void> send(Map<String, Object?> message) async {
    final Response<ResponseBody> response;
    try {
      response = await _dio.postUri<ResponseBody>(
        _url,
        data: jsonEncode(message),
        options: Options(
          responseType: ResponseType.stream,
          validateStatus: (_) => true,
          headers: {
            ..._withProtocol(_headers, _protocolVersion),
            'Content-Type': 'application/json',
            'Accept': 'application/json, text/event-stream',
            if (_sessionId != null) 'Mcp-Session-Id': _sessionId,
          },
        ),
      );
    } on DioException catch (error) {
      throw McpTransportException(error.message ?? '$error');
    }

    final sessionId = response.headers.value('mcp-session-id');
    if (sessionId != null && sessionId.isNotEmpty) _sessionId = sessionId;

    final status = response.statusCode ?? 0;
    final body = response.data;
    final contentType = (response.headers.value('content-type') ?? '')
        .toLowerCase();

    // Notifications / responses are acknowledged with 202 and an empty body.
    if (status == 202) {
      await _drain(body);
      return;
    }

    if (status < 200 || status >= 300) {
      final text = await _readAll(body);
      throw McpTransportException(
        'HTTP $status${text.isEmpty ? '' : ': ${_trim(text)}'}',
      );
    }

    if (contentType.contains('text/event-stream')) {
      if (body == null) return;
      await for (final event in decodeSse(body.stream)) {
        _emit(event.data);
      }
    } else {
      _emit(await _readAll(body));
    }
  }

  @override
  Future<void> close() async {
    await _controller.close();
  }

  void _emit(String data) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) return;
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) {
      _controller.add(decoded);
    } else if (decoded is List) {
      for (final item in decoded) {
        if (item is Map<String, dynamic>) _controller.add(item);
      }
    }
  }

  static Future<void> _drain(ResponseBody? body) async {
    if (body == null) return;
    await body.stream.drain<void>();
  }

  static Future<String> _readAll(ResponseBody? body) async {
    if (body == null) return '';
    final chunks = <int>[];
    await for (final chunk in body.stream) {
      chunks.addAll(chunk);
    }
    return utf8.decode(chunks, allowMalformed: true);
  }

  static String _trim(String text) =>
      text.length > 300 ? '${text.substring(0, 300)}…' : text;
}

/// Legacy HTTP+SSE transport (web `SSEClientTransport`): a long-lived GET stream
/// carries server→client messages. The first event is `endpoint`, whose data is
/// the URL to POST client→server messages to (often a relative path with a
/// session query). JSON-RPC responses then arrive as `message` events on the
/// GET stream and are correlated by id in [RemoteMcpClient].
class SseClientTransport implements McpTransport {
  SseClientTransport({
    required Dio dio,
    required Uri url,
    Map<String, String>? headers,
  }) : _dio = dio,
       _url = url,
       _headers = headers;

  final Dio _dio;
  final Uri _url;
  final Map<String, String>? _headers;

  final _controller = StreamController<Map<String, Object?>>.broadcast();
  final _endpointReady = Completer<void>();
  final _cancel = CancelToken();
  StreamSubscription<SseEvent>? _subscription;
  Uri? _endpoint;
  String? _protocolVersion;

  @override
  Stream<Map<String, Object?>> get messages => _controller.stream;

  @override
  void setProtocolVersion(String version) => _protocolVersion = version;

  @override
  Future<void> start() async {
    final Response<ResponseBody> response;
    try {
      response = await _dio.getUri<ResponseBody>(
        _url,
        options: Options(
          responseType: ResponseType.stream,
          // The SSE stream is long-lived; no idle-receive timeout.
          receiveTimeout: Duration.zero,
          headers: {
            ..._withProtocol(_headers, _protocolVersion),
            'Accept': 'text/event-stream',
          },
        ),
        cancelToken: _cancel,
      );
    } on DioException catch (error) {
      throw McpTransportException(error.message ?? '$error');
    }

    final body = response.data;
    if (body == null) {
      throw const McpTransportException('SSE 连接未返回数据流');
    }

    _subscription = decodeSse(body.stream).listen(
      _onEvent,
      onError: _onStreamError,
      onDone: () {
        if (!_endpointReady.isCompleted) {
          _endpointReady.completeError(
            const McpTransportException('SSE 流在握手前关闭'),
          );
        }
        if (!_controller.isClosed) _controller.close();
      },
    );

    await _endpointReady.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () =>
          throw const McpTransportException('等待 SSE endpoint 事件超时'),
    );
  }

  @override
  Future<void> send(Map<String, Object?> message) async {
    await _endpointReady.future;
    final endpoint = _endpoint;
    if (endpoint == null) {
      throw const McpTransportException('SSE endpoint 未就绪');
    }
    try {
      await _dio.postUri<void>(
        endpoint,
        data: jsonEncode(message),
        options: Options(
          validateStatus: (status) => status != null && status < 400,
          headers: {
            ..._withProtocol(_headers, _protocolVersion),
            'Content-Type': 'application/json',
          },
        ),
      );
    } on DioException catch (error) {
      throw McpTransportException(error.message ?? '$error');
    }
  }

  @override
  Future<void> close() async {
    _cancel.cancel('closed');
    await _subscription?.cancel();
    if (!_controller.isClosed) await _controller.close();
  }

  void _onEvent(SseEvent event) {
    if (event.event == 'endpoint') {
      final raw = event.data.trim();
      _endpoint = raw.isEmpty ? _url : _url.resolve(raw);
      if (!_endpointReady.isCompleted) _endpointReady.complete();
      return;
    }

    final data = event.data.trim();
    if (data.isEmpty) return;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        _controller.add(decoded);
      } else if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) _controller.add(item);
        }
      }
    } on FormatException {
      // Keep-alive comment or non-JSON frame — ignore.
    }
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    if (!_endpointReady.isCompleted) {
      _endpointReady.completeError(error, stackTrace);
    }
    if (!_controller.isClosed) _controller.addError(error, stackTrace);
  }
}
