// 内置终端长驻会话池（设计文档 §2.3 P1）。
//
// 给 AI 工具（@aether/terminal 的 terminal_session_*）提供可复用的长驻
// Alpine shell：毫秒级复用避免每条命令重开 proot；空闲超时自动释放进程。
// 交互式终端页不走这里（那是用户自己的会话，生命周期由页面管理）。

import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/terminal/domain/terminal_session_protocol.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/data/proot_local_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

part 'proot_session_pool.g.dart';

/// 会话空闲多久后自动释放进程（设计文档：无任务 N 分钟后自动释放）。
const Duration kSessionIdleTimeout = Duration(minutes: 10);

/// 池内并发会话上限（Agent 并发时按需扩容的上限）。
const int kMaxPooledSessions = 4;

/// 单个会话保留的输出回看缓冲上限（字符）。
const int kSessionBufferLimit = 200 * 1024;

/// 在长驻会话里跑一条命令的结果。输出为 PTY 合并流（stdout+stderr+回显）。
class TerminalSessionExecResult {
  const TerminalSessionExecResult({
    required this.output,
    required this.exitCode,
    this.timedOut = false,
  });

  final String output;

  /// 命令退出码；超时（命令仍在跑）时为 null。
  final int? exitCode;
  final bool timedOut;
}

/// 池内一个长驻 shell 会话。
class PooledTerminalSession {
  PooledTerminalSession._({
    required this.id,
    required this.name,
    required WorkspaceShellSession shell,
  })  : _shell = shell,
        createdAt = DateTime.now(),
        lastUsedAt = DateTime.now() {
    _outputSub = shell.output
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(_append);
    shell.done.whenComplete(() => _alive = false);
  }

  final String id;
  final String name;
  final DateTime createdAt;
  DateTime lastUsedAt;

  final WorkspaceShellSession _shell;
  StreamSubscription<String>? _outputSub;
  final StringBuffer _buffer = StringBuffer();
  final StreamController<String> _chunks = StreamController<String>.broadcast();
  bool _alive = true;
  bool _busy = false;

  bool get alive => _alive;
  bool get busy => _busy;

  /// 回看缓冲的尾部 [tail] 个字符。
  String tailOutput([int tail = 4000]) {
    final text = _buffer.toString();
    return text.length <= tail ? text : text.substring(text.length - tail);
  }

  void _append(String chunk) {
    _buffer.write(chunk);
    if (_buffer.length > kSessionBufferLimit) {
      final text = _buffer.toString();
      _buffer
        ..clear()
        ..write(text.substring(text.length - kSessionBufferLimit ~/ 2));
    }
    if (!_chunks.isClosed) _chunks.add(chunk);
  }

  /// 在本会话里跑 [command]，等哨兵回来或超时。超时不杀会话——命令继续在
  /// 后台跑，之后可用 [tailOutput] 回看。
  Future<TerminalSessionExecResult> exec(
    String command, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    if (!_alive) {
      throw const ProotBackendException('会话已结束，请新建会话');
    }
    if (_busy) {
      throw const ProotBackendException('会话正忙（上一条命令还没结束），可换一个会话或稍后再试');
    }
    _busy = true;
    lastUsedAt = DateTime.now();
    final nonce = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final collected = StringBuffer();
    final done = Completer<SentinelMatch>();
    final sub = _chunks.stream.listen((chunk) {
      collected.write(chunk);
      final match = matchSentinel(collected.toString(), nonce);
      if (match != null && !done.isCompleted) done.complete(match);
    });
    try {
      _shell.write(utf8.encode(buildSentinelInput(command, nonce)));
      final match = await done.future.timeout(timeout);
      return TerminalSessionExecResult(
        output: match.output,
        exitCode: match.exitCode,
      );
    } on TimeoutException {
      return TerminalSessionExecResult(
        output: collected.toString(),
        exitCode: null,
        timedOut: true,
      );
    } finally {
      _busy = false;
      lastUsedAt = DateTime.now();
      await sub.cancel();
    }
  }

  Future<void> close() async {
    _alive = false;
    await _outputSub?.cancel();
    _outputSub = null;
    if (!_chunks.isClosed) await _chunks.close();
    await _shell.close();
  }
}

/// 长驻会话池：新建 / 列出 / 关闭 / 复用默认会话，空闲超时自动回收。
class ProotSessionPool {
  ProotSessionPool(this._backend);

  final ProotLocalBackend _backend;
  final Map<String, PooledTerminalSession> _sessions = {};
  Timer? _reaper;
  int _nextId = 1;

  List<PooledTerminalSession> list() {
    _prune();
    return _sessions.values.toList();
  }

  PooledTerminalSession? find(String id) {
    _prune();
    return _sessions[id];
  }

  Future<PooledTerminalSession> create({
    String? name,
    String? workingDirectory,
  }) async {
    _prune();
    if (_sessions.length >= kMaxPooledSessions) {
      throw const ProotBackendException(
        '会话数已达上限（$kMaxPooledSessions 个），请先关闭不用的会话',
      );
    }
    final shell = await _backend.startShell(
      columns: 200,
      rows: 50,
      workingDirectory: workingDirectory,
    );
    final id = 's${_nextId++}';
    final session = PooledTerminalSession._(
      id: id,
      name: (name == null || name.trim().isEmpty) ? id : name.trim(),
      shell: shell,
    );
    _sessions[id] = session;
    _ensureReaper();
    return session;
  }

  /// 取默认长驻会话（第一个空闲的），没有就新建——「默认保留 1 个长驻 shell，
  /// 毫秒级复用」。
  Future<PooledTerminalSession> acquireDefault() async {
    _prune();
    for (final session in _sessions.values) {
      if (session.alive && !session.busy) return session;
    }
    return create();
  }

  Future<bool> close(String id) async {
    final session = _sessions.remove(id);
    if (session == null) return false;
    await session.close();
    if (_sessions.isEmpty) _stopReaper();
    return true;
  }

  Future<void> closeAll() async {
    final sessions = _sessions.values.toList();
    _sessions.clear();
    _stopReaper();
    for (final session in sessions) {
      await session.close();
    }
  }

  /// 剔除已退出的会话。
  void _prune() {
    _sessions.removeWhere((_, s) => !s.alive);
    if (_sessions.isEmpty) _stopReaper();
  }

  void _ensureReaper() {
    _reaper ??= Timer.periodic(const Duration(minutes: 1), (_) {
      final now = DateTime.now();
      final expired = _sessions.values
          .where((s) =>
              !s.busy && now.difference(s.lastUsedAt) > kSessionIdleTimeout)
          .map((s) => s.id)
          .toList();
      for (final id in expired) {
        close(id);
      }
      _prune();
    });
  }

  void _stopReaper() {
    _reaper?.cancel();
    _reaper = null;
  }
}

@Riverpod(keepAlive: true)
ProotSessionPool prootSessionPool(Ref ref) =>
    ProotSessionPool(ref.watch(prootLocalBackendProvider));
