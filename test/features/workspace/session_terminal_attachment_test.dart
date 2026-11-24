import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/session_terminal.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeExecBackend backend;
  late WorkspaceSessionPool pool;

  setUp(() {
    backend = _FakeExecBackend();
    var next = 0;
    pool = WorkspaceSessionPool(backend, nextId: () => 's${++next}');
  });

  test('构造时不同步回放历史，ready 后历史在前、期间实时输出在后', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    shell.emit('history\r\n');
    await Future<void>.delayed(Duration.zero);

    final view = SessionTerminalAttachment(session);
    expect(view.terminal.buffer.getText(), isNot(contains('history')));
    shell.emit('live\r\n');
    await view.ready;
    await Future<void>.delayed(Duration.zero);

    final text = view.terminal.buffer.getText();
    expect(text, contains('history'));
    expect(text.indexOf('history'), lessThan(text.indexOf('live')));
    await view.detach();
  });

  test('detach 后解除输出回调与订阅，不再回放', () async {
    final session = await pool.create();
    final shell = backend.shells.single;
    shell.emit('history\r\n');
    await Future<void>.delayed(Duration.zero);

    final view = SessionTerminalAttachment(session);
    await view.detach();
    await view.ready;
    shell.emit('late\r\n');
    await Future<void>.delayed(Duration.zero);

    expect(view.terminal.onOutput, isNull);
    final text = view.terminal.buffer.getText();
    expect(text, isNot(contains('history')));
    expect(text, isNot(contains('late')));
  });
}
