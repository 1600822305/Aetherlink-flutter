// PRoot 进程执行（data 层）：全仓库唯一同时接触 aetherlink_terminal 插件与
// dart:io Process 的文件（对齐 SAF 的单文件隔离纪律）。上层
// （TerminalEngineManager / ProotLocalBackend）只依赖这里的中立接口。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:aetherlink_terminal/aetherlink_terminal.dart';

import 'package:aetherlink_flutter/features/terminal/domain/proot_command_builder.dart';

/// 一次性命令的执行结果（与 WorkspaceExecResult 字段一致，由 backend 转换）。
class ProotExecResult {
  const ProotExecResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    this.timedOut = false,
    this.canceled = false,
  });

  final String stdout;
  final String stderr;
  final int exitCode;
  final bool timedOut;
  final bool canceled;
}

class ProotProcessRunner {
  const ProotProcessRunner();

  /// APK 原生库目录（libproot.so 所在，Android 唯一允许执行的位置）。
  Future<String> nativeLibDir() => AetherlinkTerminal.nativeLibDir();

  /// 原生解压 rootfs tar.gz（保留符号链接与权限位）。
  Future<void> extractTarGz({
    required String archivePath,
    required String destPath,
  }) =>
      AetherlinkTerminal.extractTarGz(
        archivePath: archivePath,
        destPath: destPath,
      );

  /// 跑一次 [command]（无 PTY，适合 exec 单命令），收齐 stdout/stderr。
  /// [onOutput] 提供时，每到一块 stdout/stderr 即解码回调（实时输出）。
  Future<ProotExecResult> run(
    ProotCommand command, {
    Duration? timeout,
    Future<void>? cancelSignal,
    void Function(String chunk)? onOutput,
  }) async {
    final process = await Process.start(
      command.executable,
      command.arguments,
      environment: command.environment,
    );

    final out = BytesBuilder(copy: false);
    final err = BytesBuilder(copy: false);
    void collect(BytesBuilder sink, List<int> chunk) {
      sink.add(chunk);
      onOutput?.call(utf8.decode(chunk, allowMalformed: true));
    }

    final outDone = process.stdout.forEach((c) => collect(out, c));
    final errDone = process.stderr.forEach((c) => collect(err, c));

    var timedOut = false;
    var canceled = false;
    var finished = false;
    if (cancelSignal != null) {
      unawaited(cancelSignal.then((_) {
        if (finished) return;
        canceled = true;
        process.kill(ProcessSignal.sigkill);
      }));
    }

    int exitCode;
    if (timeout != null) {
      exitCode = await process.exitCode.timeout(timeout, onTimeout: () {
        timedOut = true;
        process.kill(ProcessSignal.sigkill);
        return process.exitCode;
      });
    } else {
      exitCode = await process.exitCode;
    }
    finished = true;
    await Future.wait([outDone, errDone]);

    return ProotExecResult(
      stdout: utf8.decode(out.takeBytes(), allowMalformed: true),
      stderr: utf8.decode(err.takeBytes(), allowMalformed: true),
      exitCode: exitCode,
      timedOut: timedOut,
      canceled: canceled,
    );
  }

  /// 在真实 PTY 上启动 [command]（交互式 shell 用）。
  Future<ProotPtySession> startPty(
    ProotCommand command, {
    int columns = 80,
    int rows = 24,
  }) async =>
      ProotPtySession._(await AetherlinkTerminal.startPty(
        cmd: command.executable,
        args: command.arguments,
        env: command.environment,
        rows: rows,
        columns: columns,
      ));
}

/// 插件 PTY 会话的中立包装：上层（ProotLocalBackend）不直接 import 插件类型。
class ProotPtySession {
  ProotPtySession._(this._session);

  final TerminalPtySession _session;

  Stream<List<int>> get output => _session.output;

  /// 进程退出时以退出码完成（被信号杀死时为负的信号值）。
  Future<int> get done => _session.done;

  int? get exitCode => _session.exitCode;

  void write(List<int> data) => _session.write(data);

  void resize(int columns, int rows) => _session.resize(columns, rows);

  Future<void> kill() => _session.kill();
}
