import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

class _FakeShell implements WorkspaceShellSession {
  final StreamController<List<int>> _out = StreamController.broadcast();
  final Completer<void> _done = Completer<void>();
  final StringBuffer written = StringBuffer();
  final List<(int, int)> resizes = [];

  @override
  Stream<List<int>> get output => _out.stream;

  @override
  void write(List<int> data) => written.write(utf8.decode(data));

  @override
  void resize(int columns, int rows) => resizes.add((columns, rows));

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

/// 中断收尾的探针哨兵 nonce（`p` 前缀）。
String _probeNonceOf(_FakeShell shell) {
  final match = RegExp(
    '__AETHER_DONE_(p[a-z0-9]+)_',
  ).firstMatch(shell.written.toString());
  expect(match, isNotNull, reason: '中断后应写入探针哨兵');
  return match!.group(1)!;
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

  test('用户键入未回车的半行时 exec 拒绝执行，不写入命令', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    session.writeUserInput('rm -');
    expect(session.isUserTyping, isTrue);
    await expectLater(
      session.exec('echo hi'),
      throwsA(
        isA<WorkspaceSessionException>().having(
          (e) => e.message,
          'message',
          contains('用户正在'),
        ),
      ),
    );
    expect(shell.written.toString(), isNot(contains('__AETHER_DONE_')));
    expect(session.busy, isFalse);
  });

  test('用户回车后不再占用，exec 先发 Ctrl-U 清行再写命令', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    session.writeUserInput('ls');
    session.writeUserInput('\r');
    expect(session.isUserTyping, isFalse);
    shell.written.clear();
    final future = session.exec('echo hi');
    await Future<void>.delayed(Duration.zero);
    expect(shell.written.toString(), startsWith('\x05\x15'));
    final nonce = _nonceOf(shell);
    shell.emit('hi\n__AETHER_DONE_${nonce}_0__\n');
    expect((await future).exitCode, 0);
  });

  test('AI 命令运行期间用户写 stdin 不算占用', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    final future = session.exec('read x');
    await Future<void>.delayed(Duration.zero);
    session.writeUserInput('abc');
    final nonce = _nonceOf(shell);
    shell.emit('__AETHER_DONE_${nonce}_0__\n');
    await future;
    expect(session.isUserTyping, isFalse);
  });

  test('exec 期间 interrupt 立即返回结果，但等探针回来（shell 回到提示符）才释放', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    final future = session.exec('sleep 999');
    await Future<void>.delayed(Duration.zero);
    session.interrupt();
    final result = await future;
    expect(result.canceled, isTrue);
    // 旧进程可能还在收尾：先保持占用。
    expect(session.busy, isTrue);
    final probe = _probeNonceOf(shell);
    // 回显里的 `%s__` 原文不算数。
    shell.emit("printf '\\n__AETHER_DONE_${probe}_%s__\\n'\n");
    await Future<void>.delayed(Duration.zero);
    expect(session.busy, isTrue);
    shell.emit('\n__AETHER_DONE_${probe}_0__\n');
    await Future<void>.delayed(Duration.zero);
    expect(session.busy, isFalse);
  });

  test('interrupt 后探针一直不回来：最多等 kInterruptSettleTimeout 后释放', () {
    fakeAsync((async) {
      late PooledWorkspaceSession session;
      pool.create().then((s) => session = s);
      async.flushMicrotasks();
      session.exec('npm install');
      async.flushMicrotasks();
      session.interrupt();
      async.flushMicrotasks();
      expect(session.busy, isTrue);
      async.elapse(kInterruptSettleTimeout - const Duration(milliseconds: 100));
      expect(session.busy, isTrue);
      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();
      expect(session.busy, isFalse);
    });
  });

  test('超时后 interrupt 释放仍在等哨兵的 busy 会话', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    await session.exec('sleep 999', timeout: const Duration(milliseconds: 20));
    expect(session.busy, isTrue);
    session.writeInput('\x03');
    await Future<void>.delayed(Duration.zero);
    // 等 shell 回到提示符（探针哨兵）才释放。
    expect(session.busy, isTrue);
    final probe = _probeNonceOf(shell);
    shell.emit('\n__AETHER_DONE_${probe}_130__\n');
    await Future<void>.delayed(Duration.zero);
    expect(session.busy, isFalse);
    shell.written.clear();
    final next = session.exec('echo hi');
    await Future<void>.delayed(Duration.zero);
    final nonce = _nonceOf(shell);
    shell.emit('hi\n__AETHER_DONE_${nonce}_0__\n');
    expect((await next).exitCode, 0);
  });

  test('exec 先发 Ctrl-E 再 Ctrl-U：光标在行中时也清干净整行', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    final future = session.exec('echo hi');
    await Future<void>.delayed(Duration.zero);
    expect(shell.written.toString(), startsWith('\x05\x15'));
    final nonce = _nonceOf(shell);
    shell.emit('__AETHER_DONE_${nonce}_0__\n');
    await future;
  });

  test('resize 转发到 shell，尺寸未变时不重复转发', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    session.resize(45, 30);
    session.resize(45, 30);
    session.resize(kDefaultSessionColumns, kDefaultSessionRows);
    expect(shell.resizes, [
      (45, 30),
      (kDefaultSessionColumns, kDefaultSessionRows),
    ]);
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
  group('会话归属：AI 与用户不抢会话', () {
    test('acquireDefault 跳过用户手动新建的空闲会话', () async {
      final user = await pool.create(name: 'mine', owner: SessionOwner.user);
      expect(user.owner, SessionOwner.user);
      final ai = await pool.acquireDefault();
      expect(ai.id, isNot(user.id));
      expect(ai.owner, SessionOwner.ai);
      // 再取一次复用同一个 AI 会话，不会落到用户会话上。
      final again = await pool.acquireDefault();
      expect(again.id, ai.id);
    });

    test('acquireDefault 跳过用户正在键入半行的 AI 会话', () async {
      final typing = await pool.create();
      typing.writeUserInput('git sta'); // 半行未回车
      expect(typing.isUserTyping, isTrue);
      final picked = await pool.acquireDefault();
      expect(picked.id, isNot(typing.id));
    });

    test('用户回车后半行清除，会话重新可被复用', () async {
      final s = await pool.create();
      s.writeUserInput('ls');
      expect(s.isUserTyping, isTrue);
      s.writeUserInput('\r');
      expect(s.isUserTyping, isFalse);
      final picked = await pool.acquireDefault();
      expect(picked.id, s.id);
    });

    test('create 默认 owner 为 ai（兼容旧调用）', () async {
      final s = await pool.create();
      expect(s.owner, SessionOwner.ai);
    });
  });

  group('视图接入期间不被空闲回收', () {
    test('有视图时跳过回收，视图断开后照常回收', () {
      fakeAsync((async) {
        late PooledWorkspaceSession s;
        pool.create().then((v) => s = v);
        async.flushMicrotasks();

        s.addViewer();
        expect(s.hasViewers, isTrue);
        s.lastUsedAt = DateTime.now().subtract(
          kSessionIdleTimeout + const Duration(minutes: 1),
        );
        async.elapse(const Duration(minutes: 1, seconds: 1));
        async.flushMicrotasks();
        expect(s.alive, isTrue, reason: '有视图接入不应被回收');

        s.removeViewer();
        expect(s.hasViewers, isFalse);
        // removeViewer 重新计时：刚断开不立刻回收。
        async.elapse(const Duration(minutes: 1));
        async.flushMicrotasks();
        expect(s.alive, isTrue, reason: '断开视图后应重新计时');

        s.lastUsedAt = DateTime.now().subtract(
          kSessionIdleTimeout + const Duration(minutes: 1),
        );
        async.elapse(const Duration(minutes: 1));
        async.flushMicrotasks();
        expect(s.alive, isFalse, reason: '无视图且空闲超时应被回收');
      });
    });

    test('removeViewer 不会减到负数', () async {
      final s = await pool.create();
      s.removeViewer();
      expect(s.hasViewers, isFalse);
      s.addViewer();
      expect(s.hasViewers, isTrue);
    });
  });
  group('会话 ID 与跨工作区标记', () {
    test('管理器分配的会话 ID 带启动标识（s1-xxx），不同启动不撞号', () async {
      final m1 = WorkspaceSessionPoolManager();
      final s = await m1.poolFor(backend).create();
      expect(s.id, matches(RegExp(r'^s1-[a-z0-9]{3}$')));
      // 不传 name 时 name 与 id 一致。
      expect(s.name, s.id);
    });

    test('markWaitingInputAll 传 workspaceId 只标记该工作区的同名会话', () async {
      final manager = WorkspaceSessionPoolManager();
      final a = await manager
          .poolFor(backend, workspaceId: 'ws-a')
          .create(name: 'build');
      final b = await manager
          .poolFor(backend, workspaceId: 'ws-b')
          .create(name: 'build');
      final futureA = a.exec('make');
      final futureB = b.exec('make');
      await Future<void>.delayed(Duration.zero);
      expect(
        manager.markWaitingInputAll(sessionRef: 'build', workspaceId: 'ws-b'),
        1,
      );
      expect((await futureB).waitingInput, isTrue);
      expect(a.busy, isTrue);
      a.markWaitingInput();
      await futureA;
    });
  });
  group('工作区生命周期：配置变化重建 / 上限分开 / 移除关闭', () {
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    String key({String root = '/a', String? conn}) => workspaceConfigKey(
      backendType: 'ssh',
      root: root,
      connectionId: conn ?? 'c1',
      scope: 'project',
    );

    test('配置指纹不变：复用同一个池，改名只更新展示名', () async {
      final m = WorkspaceSessionPoolManager();
      final p1 = m.poolFor(
        backend,
        workspaceId: 'ws',
        workspaceLabel: '旧名',
        configKey: key(),
      );
      final s = await p1.create();
      final p2 = m.poolFor(
        backend,
        workspaceId: 'ws',
        workspaceLabel: '新名',
        configKey: key(),
      );
      expect(identical(p1, p2), isTrue);
      expect(p2.workspaceLabel, '新名');
      expect(s.alive, isTrue);
    });

    test('根目录 / 连接变了：关掉旧池会话并重建', () async {
      final m = WorkspaceSessionPoolManager();
      final p1 = m.poolFor(backend, workspaceId: 'ws', configKey: key());
      final a = await p1.create();
      final b = await p1.create(owner: SessionOwner.user);
      final p2 = m.poolFor(
        backend,
        workspaceId: 'ws',
        configKey: key(root: '/b'),
      );
      await settle();
      expect(identical(p1, p2), isFalse);
      expect(a.alive, isFalse);
      expect(b.alive, isFalse);
      expect(m.find(a.id), isNull);
      expect(m.allSessions(), isEmpty);

      final p3 = m.poolFor(
        backend,
        workspaceId: 'ws',
        configKey: key(root: '/b', conn: 'c2'),
      );
      expect(identical(p2, p3), isFalse);
    });

    test('后端实例换了（SSH 连接改绑）：即使不传指纹也重建', () async {
      final m = WorkspaceSessionPoolManager();
      final p1 = m.poolFor(backend, workspaceId: 'ws');
      final s = await p1.create();
      final other = _FakeExecBackend();
      final p2 = m.poolFor(other, workspaceId: 'ws');
      await settle();
      expect(identical(p1, p2), isFalse);
      expect(s.alive, isFalse);
      expect(identical(p2.backend, other), isTrue);
    });

    test('旧池未记录指纹（null）时不因指纹误判重建', () async {
      final m = WorkspaceSessionPoolManager();
      final p1 = m.poolFor(backend, workspaceId: 'ws');
      final p2 = m.poolFor(backend, workspaceId: 'ws', configKey: key());
      expect(identical(p1, p2), isTrue);
    });

    test('上限按创建者分开计数：AI 满了用户仍可新建，反之亦然', () async {
      for (var i = 0; i < kMaxPooledSessions; i++) {
        await pool.create();
      }
      await expectLater(
        pool.create(),
        throwsA(isA<WorkspaceSessionException>()),
      );
      for (var i = 0; i < kMaxPooledSessions; i++) {
        await pool.create(owner: SessionOwner.user);
      }
      await expectLater(
        pool.create(owner: SessionOwner.user),
        throwsA(
          isA<WorkspaceSessionException>().having(
            (e) => e.message,
            'message',
            contains('手动会话'),
          ),
        ),
      );
      expect(pool.list(), hasLength(kMaxPooledSessions * 2));
    });

    test('closeWorkspace 关掉该工作区全部会话，不影响其他工作区', () async {
      final m = WorkspaceSessionPoolManager();
      final a1 = await m.poolFor(backend, workspaceId: 'ws-a').create();
      final a2 = await m
          .poolFor(backend, workspaceId: 'ws-a')
          .create(owner: SessionOwner.user);
      final b1 = await m.poolFor(backend, workspaceId: 'ws-b').create();
      var notified = 0;
      m.addListener(() => notified++);
      await m.closeWorkspace('ws-a');
      expect(a1.alive, isFalse);
      expect(a2.alive, isFalse);
      expect(b1.alive, isTrue);
      expect(m.allSessions().map((s) => s.id), [b1.id]);
      expect(notified, greaterThan(0));
      // 再关一次 / 关不存在的工作区：无副作用。
      await m.closeWorkspace('ws-a');
      await m.closeWorkspace('nope');
    });

    test('closeWorkspace 让后台等哨兵的 exec 收尾，不悬挂', () async {
      final m = WorkspaceSessionPoolManager();
      final s = await m.poolFor(backend, workspaceId: 'ws').create();
      await s.exec('sleep 999', timeout: const Duration(milliseconds: 20));
      expect(s.busy, isTrue);
      await m.closeWorkspace('ws');
      await settle();
      expect(s.alive, isFalse);
    });
  });
  test('currentCommand：执行期间记录命令原文，结束后清空', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    expect(session.currentCommand, isNull);
    final future = session.exec('npm run build');
    await Future<void>.delayed(Duration.zero);
    expect(session.currentCommand, 'npm run build');
    final nonce = _nonceOf(shell);
    shell.emit('ok\n__AETHER_DONE_${nonce}_0__\n');
    await future;
    expect(session.currentCommand, isNull);
  });

  test('currentCommand：超时后仍在跑时保留，哨兵回来才清空', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    await session.exec('sleep 999', timeout: const Duration(milliseconds: 20));
    expect(session.currentCommand, 'sleep 999');
    shell.emit('\n__AETHER_DONE_${_nonceOf(shell)}_0__\n');
    await Future<void>.delayed(Duration.zero);
    expect(session.currentCommand, isNull);
  });
}
