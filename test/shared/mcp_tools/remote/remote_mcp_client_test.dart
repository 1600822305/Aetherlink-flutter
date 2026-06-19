import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/mcp_tools/remote/mcp_transport.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/remote_mcp_client.dart';

/// A scripted [McpTransport]: records sent messages and, for each request (a
/// message carrying an `id`), echoes back whatever [responder] returns — a
/// `{'result': ...}` or `{'error': ...}` fragment — on the message stream.
/// Returning `null` leaves the request unanswered (to exercise timeouts).
class _ScriptedTransport implements McpTransport {
  _ScriptedTransport(this.responder);

  final Map<String, Object?>? Function(Map<String, Object?> request) responder;
  final _controller = StreamController<Map<String, Object?>>.broadcast();
  final sent = <Map<String, Object?>>[];
  bool started = false;
  bool closed = false;

  @override
  Stream<Map<String, Object?>> get messages => _controller.stream;

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> send(Map<String, Object?> message) async {
    sent.add(message);
    final id = message['id'];
    if (id == null) return; // notification — no reply
    final fragment = responder(message);
    if (fragment != null) {
      _controller.add({'jsonrpc': '2.0', 'id': id, ...fragment});
    }
  }

  @override
  Future<void> close() async {
    closed = true;
    await _controller.close();
  }
}

Map<String, Object?>? _okResponder(Map<String, Object?> request) {
  switch (request['method']) {
    case 'initialize':
      return {
        'result': {'protocolVersion': kMcpProtocolVersion},
      };
    case 'tools/list':
      return {
        'result': {
          'tools': [
            {
              'name': 'do-thing',
              'description': 'does a thing',
              'inputSchema': {'type': 'object'},
            },
            {'name': ''}, // skipped: empty name
            'not-a-map', // skipped: not a map
          ],
        },
      };
    case 'tools/call':
      return {
        'result': {
          'content': [
            {'type': 'text', 'text': 'line 1'},
            {'type': 'text', 'text': 'line 2'},
            {'type': 'image', 'mimeType': 'image/png'},
          ],
        },
      };
    default:
      return {'result': <String, Object?>{}};
  }
}

void main() {
  group('RemoteMcpClient', () {
    test('connect runs the initialize handshake and is idempotent', () async {
      final transport = _ScriptedTransport(_okResponder);
      final client = RemoteMcpClient(transport: transport);

      await client.connect();
      await client.connect();

      expect(transport.started, isTrue);
      final methods = transport.sent.map((m) => m['method']).toList();
      expect(methods, ['initialize', 'notifications/initialized']);
    });

    test(
      'listTools maps + prefixes names and drops malformed entries',
      () async {
        final transport = _ScriptedTransport(_okResponder);
        final client = RemoteMcpClient(transport: transport);
        await client.connect();

        final tools = await client.listTools('my-server');

        expect(tools, hasLength(1));
        expect(tools.single.toolName, 'do-thing');
        expect(tools.single.definition.name, 'my_serv-do_thing');
        expect(tools.single.definition.description, 'does a thing');
        expect(tools.single.definition.inputSchema, {'type': 'object'});
      },
    );

    test('callTool flattens content blocks to text', () async {
      final transport = _ScriptedTransport(_okResponder);
      final client = RemoteMcpClient(transport: transport);
      await client.connect();

      final result = await client.callTool('do-thing', {'x': 1});

      expect(result.isError, isFalse);
      expect(result.text, 'line 1\nline 2\n[图片] image/png');
      final call = transport.sent.last;
      expect(call['method'], 'tools/call');
      expect((call['params']! as Map)['name'], 'do-thing');
    });

    test('callTool surfaces isError from the server', () async {
      final transport = _ScriptedTransport((request) {
        if (request['method'] == 'initialize') {
          return {'result': <String, Object?>{}};
        }
        return {
          'result': {
            'isError': true,
            'content': [
              {'type': 'text', 'text': 'boom'},
            ],
          },
        };
      });
      final client = RemoteMcpClient(transport: transport);
      await client.connect();

      final result = await client.callTool('do-thing', const {});

      expect(result.isError, isTrue);
      expect(result.text, 'boom');
    });

    test('a JSON-RPC error response throws McpRpcException', () async {
      final transport = _ScriptedTransport((request) {
        if (request['method'] == 'initialize') {
          return {'result': <String, Object?>{}};
        }
        return {
          'error': {'code': -32601, 'message': 'Method not found'},
        };
      });
      final client = RemoteMcpClient(transport: transport);
      await client.connect();

      expect(
        () => client.listTools('s'),
        throwsA(
          isA<McpRpcException>()
              .having((e) => e.code, 'code', -32601)
              .having((e) => e.message, 'message', 'Method not found'),
        ),
      );
    });

    test('an unanswered request times out', () async {
      final transport = _ScriptedTransport((request) {
        if (request['method'] == 'initialize') {
          return {'result': <String, Object?>{}};
        }
        return null; // never answered
      });
      final client = RemoteMcpClient(transport: transport);
      await client.connect();

      await expectLater(
        client.callTool(
          'do-thing',
          const {},
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<McpRpcException>()),
      );
    });
  });

  group('buildFunctionCallToolName', () {
    test('leaves a name that already contains the server slice untouched', () {
      // 'get_current_time' contains the 'time' slice, so no prefix is added.
      expect(
        buildFunctionCallToolName('time', 'get_current_time'),
        'get_current_time',
      );
    });

    test('prefixes a 7-char server slice and sanitizes separators', () {
      expect(
        buildFunctionCallToolName('my-server', 'do-thing'),
        'my_serv-do_thing',
      );
    });

    test('prepends tool- when the result would not start with a letter', () {
      expect(buildFunctionCallToolName('1srv', '9tool'), 'tool-1srv-9tool');
    });

    test('replaces disallowed characters and caps length at 63', () {
      final name = buildFunctionCallToolName('srv', 'a b/c!' * 20);
      expect(name.length, lessThanOrEqualTo(63));
      expect(RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]*$').hasMatch(name), isTrue);
    });
  });
}
