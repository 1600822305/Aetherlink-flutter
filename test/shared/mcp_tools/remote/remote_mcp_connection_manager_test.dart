import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/remote_mcp_connection_manager.dart';

/// A throwaway in-process MCP server speaking the Streamable HTTP transport
/// (single endpoint, one JSON reply per POST) — enough to exercise the real Dio
/// stack: handshake, `tools/list`, `tools/call`, and `Mcp-Session-Id` echo.
class _FakeStreamableServer {
  _FakeStreamableServer(this._server);

  final HttpServer _server;
  int initializeCount = 0;
  int get port => _server.port;

  static Future<_FakeStreamableServer> start() async {
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final server = _FakeStreamableServer(httpServer);
    httpServer.listen(server._handle);
    return server;
  }

  Future<void> _handle(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final message = jsonDecode(body) as Map<String, Object?>;
    final method = message['method'];
    final id = message['id'];
    final response = request.response;
    response.headers.set('Mcp-Session-Id', 'session-123');

    if (id == null) {
      response.statusCode = 202; // notification ack
      await response.close();
      return;
    }

    Map<String, Object?> result;
    switch (method) {
      case 'initialize':
        initializeCount++;
        result = {'protocolVersion': '2025-03-26'};
      case 'tools/list':
        result = {
          'tools': [
            {
              'name': 'echo',
              'description': 'echoes input',
              'inputSchema': {'type': 'object'},
            },
            {
              'name': 'hidden',
              'description': 'should be filtered',
              'inputSchema': {'type': 'object'},
            },
          ],
        };
      case 'tools/call':
        final params = message['params']! as Map;
        final args = params['arguments'] as Map?;
        result = {
          'content': [
            {'type': 'text', 'text': 'echo: ${args?['value']}'},
          ],
        };
      default:
        result = <String, Object?>{};
    }

    response.headers.contentType = ContentType('application', 'json');
    response.write(jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result}));
    await response.close();
  }

  Future<void> stop() => _server.close(force: true);
}

void main() {
  late _FakeStreamableServer server;
  late RemoteMcpConnectionManager manager;

  setUp(() async {
    server = await _FakeStreamableServer.start();
    manager = RemoteMcpConnectionManager();
  });

  tearDown(() async {
    await manager.dispose();
    await server.stop();
  });

  McpServer serverConfig() => McpServer(
    id: 'srv-1',
    name: 'echo-server',
    type: McpServerType.streamableHttp,
    isActive: true,
    baseUrl: 'http://localhost:${server.port}/mcp',
    disabledTools: const ['hidden'],
    timeout: 10,
  );

  test('isRemote covers the two HTTP transports + legacy httpStream', () {
    expect(
      RemoteMcpConnectionManager.isRemote(
        serverConfig().copyWith(type: McpServerType.sse),
      ),
      isTrue,
    );
    expect(
      RemoteMcpConnectionManager.isRemote(
        serverConfig().copyWith(type: McpServerType.streamableHttp),
      ),
      isTrue,
    );
    expect(
      RemoteMcpConnectionManager.isRemote(
        serverConfig().copyWith(type: McpServerType.httpStream),
      ),
      isTrue,
    );
    expect(
      RemoteMcpConnectionManager.isRemote(
        serverConfig().copyWith(type: McpServerType.inMemory),
      ),
      isFalse,
    );
  });

  test('listTools discovers tools and honours disabledTools', () async {
    final tools = await manager.listTools(serverConfig());

    expect(tools, hasLength(1));
    expect(tools.single.toolName, 'echo');
    expect(tools.single.definition.name, 'echo_se-echo');
  });

  test('callTool round-trips arguments and result over real Dio', () async {
    final result = await manager.callTool(serverConfig(), 'echo', const {
      'value': 42,
    });

    expect(result.isError, isFalse);
    expect(result.text, 'echo: 42');
  });

  test('the connection is cached across calls (one handshake)', () async {
    await manager.listTools(serverConfig());
    await manager.callTool(serverConfig(), 'echo', const {'value': 1});

    expect(server.initializeCount, 1);
  });

  test('an unreachable server surfaces a transport error', () async {
    final dead = serverConfig().copyWith(baseUrl: 'http://localhost:1/mcp');

    await expectLater(manager.listTools(dead), throwsA(isA<Object>()));
  });
}
