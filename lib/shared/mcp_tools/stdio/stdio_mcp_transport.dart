// stdio MCP 传输层：把一个工作区后端拉起的无 PTY 子进程
// （[WorkspaceProcessSession]）适配成 [McpTransport]。MCP stdio 框架为
// newline-delimited JSON-RPC（每条消息一行），stdout 按行解帧、stdin 按行
// 写入；stderr 是 server 的启动/运行日志，进环形缓冲供设置页排查。

import 'dart:async';
import 'dart:convert';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/mcp_transport.dart';

/// stderr 日志环形缓冲的行数上限。
const int kStdioLogMaxLines = 200;

/// [McpTransport] over a workspace-spawned child process's stdio.
class StdioMcpTransport implements McpTransport {
  StdioMcpTransport(this._session, {void Function(String line)? onLog})
      : _onLog = onLog;

  final WorkspaceProcessSession _session;
  final void Function(String line)? _onLog;

  final _controller = StreamController<Map<String, Object?>>.broadcast();
  StreamSubscription<String>? _outSub;
  StreamSubscription<String>? _errSub;
  bool _closed = false;

  @override
  Stream<Map<String, Object?>> get messages => _controller.stream;

  @override
  void setProtocolVersion(String version) {
    // stdio 无 header，协商版本只在 initialize 报文里体现，这里无事可做。
  }

  @override
  Future<void> start() async {
    _outSub = _session.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onLine, onError: (_) {});
    _errSub = _session.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _onLog?.call(line), onError: (_) {});
    unawaited(_session.done.whenComplete(() {
      if (_closed) return;
      _closed = true;
      final code = _session.exitCode;
      _onLog?.call('[进程退出${code != null ? '，退出码 $code' : ''}]');
      if (!_controller.isClosed) _controller.close();
    }));
  }

  void _onLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    // npx 安装进度等非 JSON 行可能混进 stdout，按日志处理而不是断流。
    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      _onLog?.call(trimmed);
      return;
    }
    if (decoded is Map<String, dynamic>) {
      _controller.add(decoded.cast<String, Object?>());
    }
  }

  @override
  Future<void> send(Map<String, Object?> message) async {
    if (_closed) {
      throw const McpTransportException('stdio MCP 进程已退出');
    }
    _session.write(utf8.encode('${jsonEncode(message)}\n'));
  }

  @override
  Future<void> close() async {
    if (_closed) {
      await _outSub?.cancel();
      await _errSub?.cancel();
      if (!_controller.isClosed) await _controller.close();
      return;
    }
    _closed = true;
    await _outSub?.cancel();
    await _errSub?.cancel();
    await _session.close();
    if (!_controller.isClosed) await _controller.close();
  }
}
