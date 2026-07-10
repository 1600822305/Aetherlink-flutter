// 工作区长驻会话池 — 内置终端的会话池抽象（exec 超时后台继续跑 +
// tailOutput 回看）上移到 WorkspaceBackend 层：任何 canExec 的后端（内置
// 终端 / SSH / Termux）都能开长驻 shell 会话，AI 工具（@aether/terminal 的
// terminal_session_*）据此在远端也能跑后台长任务。
//
// 交互式终端页不走这里（那是用户自己的会话，生命周期由页面管理）。

import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_session_protocol.dart';

part 'workspace_session_pool.g.dart';

/// 会话空闲多久后自动释放进程（无任务 N 分钟后自动释放）。
const Duration kSessionIdleTimeout = Duration(minutes: 10);

/// 单个后端的并发会话上限（Agent 并发时按需扩容的上限）。
const int kMaxPooledSessions = 4;

/// 单个会话保留的输出回看缓冲上限（字符）。
const int kSessionBufferLimit = 200 * 1024;

/// Thrown by session operations with a user-facing message.
class WorkspaceSessionException implements Exception {
  const WorkspaceSessionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 在长驻会话里跑一条命令的结果。输出为 PTY 合并流（stdout+stderr+回显）。
class WorkspaceSessionExecResult {
  const WorkspaceSessionExecResult({
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
class PooledWorkspaceSession {
  PooledWorkspaceSession._({
    required this.id,
    required this.name,
    required this.workspaceLabel,
    required this.workspaceId,
    required WorkspaceShellSession shell,
  })  : _shell = shell,
        createdAt = DateTime.now(),
        lastUsedAt = DateTime.now() {
    // cast 到 List<int>：Utf8Decoder 的 StreamTransformer 反化是
    // <List<int>, String>，Stream<Uint8List>.transform 在运行时泛型检查下
    // 会直接抛 type error。
    _outputSub = shell.output
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(_append);
    shell.done.whenComplete(() => _alive = false);
  }

  final String id;
  final String name;

  /// 会话所属工作区的展示名（内置终端会话为「内置终端」）。
  final String workspaceLabel;

  /// 会话所属工作区的 ID；未锚定工作区（裸后端默认池）时为 null。
  /// 双作用域设计稿 §3.1：会话按工作区隔离的过滤键。
  final String? workspaceId;

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
  Future<WorkspaceSessionExecResult> exec(
    String command, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    if (!_alive) {
      throw const WorkspaceSessionException('会话已结束，请新建会话');
    }
    if (_busy) {
      throw const WorkspaceSessionException(
        '会话正忙（上一条命令还没结束），可换一个会话或稍后再试',
      );
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
      return WorkspaceSessionExecResult(
        output: match.output,
        exitCode: match.exitCode,
      );
    } on TimeoutException {
      return WorkspaceSessionExecResult(
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

  /// 往会话的运行中进程写 stdin（交互式程序输入，设计稿 §3.4）。
  /// 不自动追加换行，需要回车确认时由调用方在 [data] 末尾带 `\n`。
  void writeInput(String data) {
    if (!_alive) {
      throw const WorkspaceSessionException('会话已结束，请新建会话');
    }
    lastUsedAt = DateTime.now();
    _shell.write(utf8.encode(data));
  }

  Future<void> close() async {
    _alive = false;
    await _outputSub?.cancel();
    _outputSub = null;
    if (!_chunks.isClosed) await _chunks.close();
    await _shell.close();
  }
}

/// 单个后端的长驻会话池：新建 / 列出 / 关闭 / 复用默认会话，空闲超时自动回收。
class WorkspaceSessionPool {
  WorkspaceSessionPool(
    this._backend, {
    required String Function() nextId,
    this.workspaceLabel = '',
    this.workspaceId,
  }) : _nextId = nextId;

  final WorkspaceBackend _backend;
  final String Function() _nextId;

  /// 池所属工作区的展示名，赋给新建的会话。
  final String workspaceLabel;

  /// 池所属工作区的 ID（双作用域设计稿 §3.1）；裸后端默认池为 null。
  final String? workspaceId;

  final Map<String, PooledWorkspaceSession> _sessions = {};
  Timer? _reaper;

  List<PooledWorkspaceSession> list() {
    _prune();
    return _sessions.values.toList();
  }

  PooledWorkspaceSession? find(String id) {
    _prune();
    return _sessions[id];
  }

  Future<PooledWorkspaceSession> create({
    String? name,
    String? workingDirectory,
    Map<String, String> environment = const {},
  }) async {
    _prune();
    if (_sessions.length >= kMaxPooledSessions) {
      throw const WorkspaceSessionException(
        '会话数已达上限（$kMaxPooledSessions 个），请先关闭不用的会话',
      );
    }
    final shell = await _backend.startShell(
      columns: 200,
      rows: 50,
      workingDirectory: workingDirectory,
    );
    if (environment.isNotEmpty) {
      shell.write(utf8.encode(buildSessionEnvSetup(environment)));
    }
    final id = _nextId();
    final session = PooledWorkspaceSession._(
      id: id,
      name: (name == null || name.trim().isEmpty) ? id : name.trim(),
      workspaceLabel: workspaceLabel,
      workspaceId: workspaceId,
      shell: shell,
    );
    _sessions[id] = session;
    _ensureReaper();
    return session;
  }

  /// 取默认长驻会话（第一个空闲的），没有就新建——「默认保留 1 个长驻 shell，
  /// 毫秒级复用」。
  Future<PooledWorkspaceSession> acquireDefault({
    String? workingDirectory,
    Map<String, String> environment = const {},
  }) async {
    _prune();
    for (final session in _sessions.values) {
      if (session.alive && !session.busy) return session;
    }
    return create(
      workingDirectory: workingDirectory,
      environment: environment,
    );
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

/// 会话池管理器：每个工作区一个池（双作用域设计稿 §3.1：同一后端上的
/// 不同工作区各自隔离；未锚定工作区的裸后端用后端自身做键），
/// 会话 ID 全局唯一，查找 / 关闭可跨池按 ID 直达。
class WorkspaceSessionPoolManager {
  final Map<Object, WorkspaceSessionPool> _pools = {};
  int _nextId = 1;

  /// [backend] 上工作区 [workspaceId] 的会话池；首次访问时创建，
  /// [workspaceLabel] 赋给其新会话。[workspaceId] 为 null 时（未锚定
  /// 工作区的裸后端）退化为按后端实例一个池。
  WorkspaceSessionPool poolFor(
    WorkspaceBackend backend, {
    String workspaceLabel = '',
    String? workspaceId,
  }) =>
      _pools.putIfAbsent(
        workspaceId ?? backend,
        () => WorkspaceSessionPool(
          backend,
          nextId: () => 's${_nextId++}',
          workspaceLabel: workspaceLabel,
          workspaceId: workspaceId,
        ),
      );

  /// 所有池里的所有会话。
  List<PooledWorkspaceSession> allSessions() => [
        for (final pool in _pools.values) ...pool.list(),
      ];

  /// 跨池按 ID 查会话。
  PooledWorkspaceSession? find(String id) {
    for (final pool in _pools.values) {
      final session = pool.find(id);
      if (session != null) return session;
    }
    return null;
  }

  /// 跨池按 ID 关会话；找不到返回 false。
  Future<bool> close(String id) async {
    for (final pool in _pools.values) {
      if (await pool.close(id)) return true;
    }
    return false;
  }
}

@Riverpod(keepAlive: true)
WorkspaceSessionPoolManager workspaceSessionPoolManager(Ref ref) =>
    WorkspaceSessionPoolManager();
