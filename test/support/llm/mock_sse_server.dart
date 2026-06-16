import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// How the [MockSseServer] should respond to a request.
enum MockSseMode {
  /// Stream the configured body back as `text/event-stream`, chunk by chunk.
  /// An empty body yields a valid-but-empty stream.
  stream,

  /// Reply with a non-2xx status and a JSON error body (no streaming).
  errorStatus,

  /// Start a stream then drop the connection mid-body (declared
  /// `content-length` is never satisfied), simulating a broken/aborted stream.
  abort,
}

/// What the server saw on the wire, so E2E tests can assert that the real
/// adapter built the right request without a network or a real key.
class CapturedRequest {
  CapturedRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String body;
}

/// A throwaway local HTTP server that replays a recorded SSE body so the full
/// M2 chain (real `dio` → handwritten `decodeSse` → protocol adapter) can be
/// exercised end-to-end against `localhost` — no network, no API key, no UI.
///
/// Built on `dart:io`'s [HttpServer] only (zero new dependencies). It is
/// deliberately protocol-agnostic: it ignores the request path and streams the
/// bytes it was given, emitting them in small chunks so the decoder is driven
/// across network-chunk boundaries (including multi-byte UTF-8).
class MockSseServer {
  MockSseServer._({
    required HttpServer server,
    required String body,
    required MockSseMode mode,
    required int statusCode,
    required int chunkSize,
    required String contentType,
  }) : _server = server,
       _body = body,
       _mode = mode,
       _statusCode = statusCode,
       _chunkSize = chunkSize,
       _contentType = contentType {
    _server.listen(_handle);
  }

  final HttpServer _server;
  final String _body;
  final MockSseMode _mode;
  final int _statusCode;
  final int _chunkSize;
  final String _contentType;

  /// The most recent request the server handled.
  CapturedRequest? lastRequest;

  /// Base URL to hand to a `Model` (e.g. `http://127.0.0.1:<port>`).
  Uri get baseUri => Uri(scheme: 'http', host: '127.0.0.1', port: _server.port);

  /// Binds an ephemeral loopback port and starts serving.
  static Future<MockSseServer> start({
    required String body,
    MockSseMode mode = MockSseMode.stream,
    int statusCode = 200,
    int chunkSize = 16,
    String contentType = 'text/event-stream',
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return MockSseServer._(
      server: server,
      body: body,
      mode: mode,
      statusCode: statusCode,
      chunkSize: chunkSize,
      contentType: contentType,
    );
  }

  /// Stops the server, dropping any in-flight connection.
  Future<void> stop() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      lastRequest = CapturedRequest(
        method: request.method,
        uri: request.uri,
        headers: _headersOf(request),
        body: body,
      );
      switch (_mode) {
        case MockSseMode.errorStatus:
          await _respondError(request);
        case MockSseMode.abort:
          await _abortMidStream(request);
        case MockSseMode.stream:
          await _streamBody(request);
      }
    } on Object {
      // The client (or the test tearing the server down) can disconnect
      // mid-write; that is expected for the abort/cleanup paths.
    }
  }

  Future<void> _streamBody(HttpRequest request) async {
    final response = request.response;
    response.statusCode = _statusCode;
    response.headers.set(HttpHeaders.contentTypeHeader, _contentType);
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');

    final bytes = utf8.encode(_body);
    for (var i = 0; i < bytes.length; i += _chunkSize) {
      final end = (i + _chunkSize < bytes.length)
          ? i + _chunkSize
          : bytes.length;
      response.add(bytes.sublist(i, end));
      await response.flush();
    }
    await response.close();
  }

  Future<void> _respondError(HttpRequest request) async {
    final response = request.response;
    response.statusCode = _statusCode;
    response.headers.contentType = ContentType.json;
    response.write('{"error":{"message":"mock provider error","type":"mock"}}');
    await response.close();
  }

  Future<void> _abortMidStream(HttpRequest request) async {
    // Detach the raw socket and write a response that promises more bytes than
    // it delivers, then destroy it — the client sees EOF before the declared
    // content-length, surfacing as a transport error mid-stream.
    final socket = await request.response.detachSocket(writeHeaders: false);
    final partial = utf8.encode(_body);
    socket.add(
      utf8.encode(
        'HTTP/1.1 200 OK\r\n'
        'content-type: text/event-stream\r\n'
        'content-length: ${partial.length + 4096}\r\n'
        'cache-control: no-cache\r\n'
        '\r\n',
      ),
    );
    socket.add(partial);
    await socket.flush();
    socket.destroy();
  }

  static Map<String, String> _headersOf(HttpRequest request) {
    final headers = <String, String>{};
    request.headers.forEach((name, values) {
      headers[name] = values.join(',');
    });
    return headers;
  }
}
