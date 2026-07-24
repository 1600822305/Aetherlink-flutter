import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

class _FakeShell implements WorkspaceShellSession {
  final StreamController<List<int>> _out = StreamController.broadcast();
  final Completer<void> _done = Completer<void>();
  final StringBuffer written = StringBuffer();

  @override
  Stream<List<int>> get output => _out.stream;

  @override
  void write(List<int> data) => written.write(utf8.decode(data));

  @override
  void resize(int columns, int rows) {}

  @override
  Future<void> get done => _done.future;

  @override
  int? get exitCode => null;

  @override
  Future<void> close() async {
    if (!_done.isCompleted) _done.complete();
    await _out.close();
  }

  void emit(String text) => _out.add(utf8.encode(text));
}

class _FakeExecBackend extends WorkspaceBackend {
  final List<_FakeShell> shells = [];

  @override
  WorkspaceCapabilities get capabilities => const WorkspaceCapabilities(
    canExec: true,
    canWatch: false,
    isRemote: false,
  );

  @override
  Future<String> echo(String value) async => value;

  @override
  Future<List<WorkspaceEntry>> listDir(String path) async => const [];

  @override
  Future<String> readFile(String path) async => '';

  @override
  Future<WorkspaceShellSession> startShell({
    int columns = 80,
    int rows = 24,
    String? workingDirectory,
  }) async {
    final shell = _FakeShell();
    shells.add(shell);
    return shell;
  }
}

String _nonceOf(_FakeShell shell) {
  final match = RegExp(
    '__AETHER_DONE_([a-z0-9]+)_',
  ).firstMatch(shell.written.toString());
  expect(match, isNotNull, reason: '哨兵输入应已写入 shell');
  return match!.group(1)!;
}

void main() {
  late _FakeExecBackend backend;
  late WorkspaceSessionPool pool;

  setUp(() {
    backend = _FakeExecBackend();
    var next = 0;
    pool = WorkspaceSessionPool(backend, nextId: () => 's${++next}');
  });

  test('exec 正常完成：哨兵回来即返回输出与退出码，会话空闲', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    final future = session.exec('echo hi');
    await Future<void>.delayed(Duration.zero);
    final nonce = _nonceOf(shell);
    shell.emit('hi\n__AETHER_DONE_${nonce}_0__\n');
    final result = await future;
    expect(result.output, contains('hi'));
    expect(result.exitCode, 0);
    expect(result.timedOut, isFalse);
    expect(session.busy, isFalse);
  });

  test('exec 超时后会话保持占用，哨兵回来才释放', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    final result = await session.exec(
      'sleep 999',
      timeout: const Duration(milliseconds: 20),
    );
    expect(result.timedOut, isTrue);
    // 命令还在前台跑：busy 不释放，acquireDefault 不复用它。
    expect(session.busy, isTrue);
    final other = await pool.acquireDefault();
    expect(other.id, isNot(session.id));
    // 哨兵终于回来：释放会话。
    final nonce = _nonceOf(shell);
    shell.emit('done\n__AETHER_DONE_${nonce}_0__\n');
    await Future<void>.delayed(Duration.zero);
    expect(session.busy, isFalse);
  });

  test('超时占用中的会话拒绝新 exec', () async {
    final session = await pool.create();
    await session.exec('sleep 999', timeout: const Duration(milliseconds: 20));
    expect(
      () => session.exec('echo hi'),
      throwsA(isA<WorkspaceSessionException>()),
    );
  });
}
