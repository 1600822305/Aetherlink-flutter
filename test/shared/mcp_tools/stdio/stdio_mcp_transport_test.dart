import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/mcp_transport.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/remote_mcp_client.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/stdio/stdio_mcp_transport.dart';

/// A fake child process: tests push raw stdout/stderr bytes and end it.
class _FakeProcessSession implements WorkspaceProcessSession {
  final stdoutController = StreamController<List<int>>();
  final stderrController = StreamController<List<int>>();
  final _done = Completer<void>();
  final written = <String>[];
  int? code;
  bool closed = false;

  @override
  Stream<List<int>> get stdout => stdoutController.stream;

  @override
  Stream<List<int>> get stderr => stderrController.stream;

  @override
  void write(List<int> data) => written.add(utf8.decode(data));

  @override
  Future<void> get done => _done.future;

  @override
  int? get exitCode => code;

  void exit(int exitCode) {
    code = exitCode;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> close() async {
    closed = true;
    exit(-9);
  }
}

void main() {
  group('StdioMcpTransport', () {
    test('按行解帧：跨 chunk 的半行、CRLF、非 JSON 行进日志', () async {
      final session = _FakeProcessSession();
      final logs = <String>[];
      final transport = StdioMcpTransport(session, onLog: logs.add);
      final received = <Map<String, Object?>>[];
      transport.messages.listen(received.add);
      await transport.start();

      session.stdoutController
        ..add(utf8.encode('npm warn exec\n{"jsonrpc":"2.0",'))
        ..add(utf8.encode('"id":1,"result":{}}\r\n'));
      await pumpEventQueue();

      expect(received, [
        {'jsonrpc': '2.0', 'id': 1, 'result': <String, Object?>{}},
      ]);
      expect(logs, ['npm warn exec']);
      await transport.close();
      expect(session.closed, isTrue);
    });

    test('send 每条消息一行', () async {
      final session = _FakeProcessSession();
      final transport = StdioMcpTransport(session);
      await transport.start();

      await transport.send({'jsonrpc': '2.0', 'method': 'ping'});

      expect(session.written, ['{"jsonrpc":"2.0","method":"ping"}\n']);
      await transport.close();
    });

    test('进程在握手中退出：请求立即带退出码失败而不是等超时', () async {
      final session = _FakeProcessSession();
      final logs = <String>[];
      final client = RemoteMcpClient(
        transport: StdioMcpTransport(session, onLog: logs.add),
        requestTimeout: const Duration(seconds: 30),
      );

      final connecting = client.connect();
      await pumpEventQueue();
      session.exit(1);

      await expectLater(
        connecting.timeout(const Duration(seconds: 1)),
        throwsA(
          isA<McpTransportException>().having(
            (e) => e.message,
            'message',
            contains('退出码 1'),
          ),
        ),
      );
      expect(logs.last, '[进程退出，退出码 1]');
      await client.close();
    });
  });
}
