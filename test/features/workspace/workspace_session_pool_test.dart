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

  test('手动标记等交互：exec 带已有输出提前返回，busy 保持，哨兵回来才释放', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    final future = session.exec('npx create-app');
    await Future<void>.delayed(Duration.zero);
    shell.emit('Ok to proceed? (y)');
    await Future<void>.delayed(Duration.zero);
    // 用户在工具卡片点了「在等交互输入」。
    expect(session.markWaitingInput(), isTrue);
    final result = await future;
    expect(result.waitingInput, isTrue);
    expect(result.timedOut, isFalse);
    expect(result.exitCode, isNull);
    expect(result.output, contains('Ok to proceed?'));
    // 命令还在前台等输入：busy 不释放，新命令不能抢占该会话。
    expect(session.busy, isTrue);
    expect(
      () => session.exec('echo hi'),
      throwsA(isA<WorkspaceSessionException>()),
    );
    // 写 stdin 回答后命令跑完，哨兵回来释放会话。
    session.writeInput('y\n');
    final nonce = _nonceOf(shell);
    shell.emit('done\n__AETHER_DONE_${nonce}_0__\n');
    await Future<void>.delayed(Duration.zero);
    expect(session.busy, isFalse);
  });

  test('没有正在等结果的 exec 时手动标记返回 false', () async {
    final session = await pool.create();
    expect(session.markWaitingInput(), isFalse);
    expect(WorkspaceSessionPoolManager().markWaitingInputAll(), 0);
  });

  test('超时占用中的会话拒绝新 exec', () async {
    final session = await pool.create();
    await session.exec('sleep 999', timeout: const Duration(milliseconds: 20));
    expect(
      () => session.exec('echo hi'),
      throwsA(isA<WorkspaceSessionException>()),
    );
  });

  test('interrupt 向会话写 Ctrl-C，会话保活', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    session.interrupt();
    expect(shell.written.toString(), contains('\x03'));
    expect(session.alive, isTrue);
  });

  test('close 让超时后仍在后台等哨兵的 exec 立即收尾，不永久悬挂', () async {
    final session = await pool.create();
    await session.exec('sleep 999', timeout: const Duration(milliseconds: 20));
    expect(session.busy, isTrue);
    await pool.close(session.id);
    await Future<void>.delayed(Duration.zero);
    expect(session.alive, isFalse);
    expect(pool.list(), isEmpty);
  });

  test('close 让正在等待中的 exec 出错返回', () async {
    final session = await pool.create();
    final future = expectLater(
      session.exec('sleep 999'),
      throwsA(isA<WorkspaceSessionException>()),
    );
    await Future<void>.delayed(Duration.zero);
    await pool.close(session.id);
    await future;
  });

  test('background exec 立即返回，哨兵回来后释放 busy 并记录退出码', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    final result = await session.exec('make -j', background: true);
    expect(result.background, isTrue);
    expect(result.exitCode, isNull);
    expect(session.busy, isTrue);
    expect(session.lastExitCode, isNull);
    final nonce = _nonceOf(shell);
    shell.emit('built\n__AETHER_DONE_${nonce}_3__\n');
    await Future<void>.delayed(Duration.zero);
    expect(session.busy, isFalse);
    expect(session.lastExitCode, 3);
    expect(session.tailOutput(), contains('built'));
  });

  test('splitStderr exec 把 stderr 分流到结果字段', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    final future = session.exec('make', splitStderr: true);
    await Future<void>.delayed(Duration.zero);
    expect(shell.written.toString(), contains('__AETHER_ERR_'));
    final nonce = _nonceOf(shell);
    shell.emit(
      'building\n__AETHER_ERR_${nonce}__\nwarn: x\n'
      '\n__AETHER_DONE_${nonce}_0__\n',
    );
    final result = await future;
    expect(result.output.trim(), 'building');
    expect(result.stderr, 'warn: x');
  });

  test('outputSince 增量游标：只取新增输出，cursor 单调递增', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    shell.emit('first\n');
    await Future<void>.delayed(Duration.zero);
    final r1 = session.outputSince(0);
    expect(r1.output, 'first\n');
    shell.emit('second\n');
    await Future<void>.delayed(Duration.zero);
    final r2 = session.outputSince(r1.cursor);
    expect(r2.output, 'second\n');
    expect(r2.cursor, greaterThan(r1.cursor));
    // 无新增时返回空串，cursor 不变。
    final r3 = session.outputSince(r2.cursor);
    expect(r3.output, isEmpty);
    expect(r3.cursor, r2.cursor);
    expect(session.outputCursor, r2.cursor);
  });

  test('markWaitingInputAll 传 sessionRef 只标记目标会话', () async {
    final manager = WorkspaceSessionPoolManager();
    final p = manager.poolFor(backend);
    final a = await p.create(name: 'build');
    final b = await p.create(name: 'ask');
    final futureA = a.exec('make -j');
    final futureB = b.exec('npx create-app');
    await Future<void>.delayed(Duration.zero);
    expect(manager.markWaitingInputAll(sessionRef: 'ask'), 1);
    final resultB = await futureB;
    expect(resultB.waitingInput, isTrue);
    // 未命中的会话不受影响，仍在等哨兵。
    expect(a.busy, isTrue);
    b.markWaitingInput();
    a.markWaitingInput();
    await futureA;
  });
}
