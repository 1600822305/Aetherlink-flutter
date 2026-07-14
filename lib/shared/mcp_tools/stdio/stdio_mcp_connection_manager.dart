// stdio MCP 连接管理：每个配置的 stdio server 缓存一个活连接（对齐
// RemoteMcpConnectionManager），进程经 McpServer.workspaceId 指定的工作区
// 后端拉起（proot 容器 / SSH）。额外维护 UI 需要的运行状态与 stderr
// 日志环形缓冲（设置页 stdio 面板消费）。

import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/mcp_transport.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/remote_mcp_client.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/stdio/stdio_mcp_transport.dart';

/// 一个 stdio server 的运行状态（设置页状态点）。
enum StdioMcpStatus { stopped, starting, running, error }

/// stdio server 的可观测运行信息：状态 + 最近日志。
class StdioMcpServerState {
  const StdioMcpServerState({
    required this.status,
    this.error,
    this.logs = const [],
  });

  final StdioMcpStatus status;
  final String? error;
  final List<String> logs;
}

/// Caches one live [RemoteMcpClient] per configured **stdio** server. The
/// JSON-RPC layer is shared with the HTTP transports ([RemoteMcpClient]);
/// only the transport differs — a workspace-spawned child process.
class StdioMcpConnectionManager {
  StdioMcpConnectionManager(this._ref);

  final Ref _ref;
  final _clients = <String, RemoteMcpClient>{};
  final _pending = <String, Future<RemoteMcpClient>>{};
  final _status = <String, StdioMcpStatus>{};
  final _errors = <String, String>{};
  final _logs = <String, Queue<String>>{};
  final _changes = StreamController<String>.broadcast();

  /// Whether [server] runs over stdio.
  static bool isStdio(McpServer server) => server.type == McpServerType.stdio;

  /// 状态变化通知（值为 server id），设置页面板订阅后拉取 [stateOf]。
  Stream<String> get changes => _changes.stream;

  /// [serverId] 的当前运行状态 + 日志尾部快照。
  StdioMcpServerState stateOf(String serverId) => StdioMcpServerState(
        status: _status[serverId] ?? StdioMcpStatus.stopped,
        error: _errors[serverId],
        logs: List.unmodifiable(_logs[serverId] ?? const <String>[]),
      );

  /// Discovers [server]'s tools over a live connection, filtering out any in
  /// `disabledTools`.
  Future<List<RemoteMcpTool>> listTools(McpServer server) async {
    final client = await _clientFor(server);
    final tools = await client.listTools(server.name);
    final disabled = server.disabledTools?.toSet() ?? const <String>{};
    if (disabled.isEmpty) return tools;
    return tools.where((t) => !disabled.contains(t.toolName)).toList();
  }

  /// Calls [toolName] on [server], honouring the configured timeout.
  Future<McpToolResult> callTool(
    McpServer server,
    String toolName,
    Map<String, Object?> arguments,
  ) async {
    final client = await _clientFor(server);
    return client.callTool(
      toolName,
      arguments,
      timeout: Duration(seconds: server.timeout ?? 60),
    );
  }

  /// Stops [server]'s process and drops it from the cache.
  Future<void> closeServer(McpServer server) async {
    final client = _clients.remove(server.id);
    await client?.close();
    _setStatus(server.id, StdioMcpStatus.stopped);
  }

  /// 停掉再重新拉起（设置页「重启」按钮）。
  Future<void> restartServer(McpServer server) async {
    await closeServer(server);
    _logs.remove(server.id);
    await _clientFor(server);
  }

  /// Closes every cached connection (owning provider disposes).
  Future<void> dispose() async {
    final clients = _clients.values.toList();
    _clients.clear();
    _pending.clear();
    for (final client in clients) {
      await client.close();
    }
    await _changes.close();
  }

  Future<RemoteMcpClient> _clientFor(McpServer server) {
    final existing = _clients[server.id];
    if (existing != null) return Future.value(existing);
    final pending = _pending[server.id];
    if (pending != null) return pending;
    final future = _connect(server);
    _pending[server.id] = future;
    return future.whenComplete(() => _pending.remove(server.id));
  }

  Future<RemoteMcpClient> _connect(McpServer server) async {
    final command = server.command?.trim();
    if (command == null || command.isEmpty) {
      throw const McpTransportException('stdio MCP 服务器缺少启动命令');
    }
    final workspaceId = server.workspaceId?.trim();
    if (workspaceId == null || workspaceId.isEmpty) {
      throw const McpTransportException('stdio MCP 服务器未选择运行环境（工作区）');
    }
    _setStatus(server.id, StdioMcpStatus.starting);
    try {
      final backend = await resolveWorkspaceById(_ref, workspaceId);
      if (!backend.capabilities.canExec) {
        throw const McpTransportException('所选工作区后端不支持执行命令（如 SAF）');
      }
      final args = server.args ?? const <String>[];
      // 参数逐个单引号转义（后端会经 shell 组合命令行），命令本身保持原样
      // 以允许 `npx` 这类 PATH 查找。
      final full = [command, ...args.map(_shellQuote)].join(' ');
      final session = await backend.startProcess(
        full,
        workingDirectory:
            (server.cwd?.trim().isNotEmpty ?? false) ? server.cwd!.trim() : null,
        environment: server.env,
      );
      final transport = StdioMcpTransport(
        session,
        onLog: (line) => _appendLog(server.id, line),
      );
      final client = RemoteMcpClient(
        transport: transport,
        requestTimeout: Duration(seconds: server.timeout ?? 60),
      );
      try {
        await client.connect();
      } on Object {
        await client.close();
        rethrow;
      }
      _clients[server.id] = client;
      _setStatus(server.id, StdioMcpStatus.running);
      // 进程意外退出（被系统杀掉、npx 报错）→ 状态回落，下次调用重连。
      unawaited(session.done.whenComplete(() {
        if (_clients[server.id] != client) return;
        _clients.remove(server.id);
        if (_status[server.id] == StdioMcpStatus.running) {
          _setStatus(server.id, StdioMcpStatus.stopped);
        }
      }));
      return client;
    } on Object catch (e) {
      _errors[server.id] = e.toString();
      _setStatus(server.id, StdioMcpStatus.error);
      rethrow;
    }
  }

  void _appendLog(String serverId, String line) {
    final queue = _logs.putIfAbsent(serverId, Queue.new);
    queue.addLast(line);
    while (queue.length > kStdioLogMaxLines) {
      queue.removeFirst();
    }
    if (!_changes.isClosed) _changes.add(serverId);
  }

  static String _shellQuote(String value) =>
      "'${value.replaceAll("'", "'\\''")}'";

  void _setStatus(String serverId, StdioMcpStatus status) {
    _status[serverId] = status;
    if (status != StdioMcpStatus.error) _errors.remove(serverId);
    if (!_changes.isClosed) _changes.add(serverId);
  }
}
