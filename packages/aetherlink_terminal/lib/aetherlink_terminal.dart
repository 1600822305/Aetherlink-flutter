/// Dart API of the Aetherlink built-in PRoot terminal plugin.
///
/// The platform side (Android) bundles the PRoot binaries as jniLibs, exposes
/// a JNI forkpty bridge for interactive PTY sessions, and extracts rootfs
/// tar.gz archives natively (preserving symlinks / permission bits, which the
/// Dart `archive` package can't). See docs/内置终端PRoot-设计文档.md.
library;

import 'dart:async';

import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('aetherlink_terminal');
const EventChannel _events = EventChannel('aetherlink_terminal/events');

/// Broadcast of every PTY session's output / exit events, keyed by session id.
Stream<Map<Object?, Object?>>? _eventStream;

Stream<Map<Object?, Object?>> _sessionEvents() =>
    _eventStream ??= _events
        .receiveBroadcastStream()
        .map((event) => event as Map<Object?, Object?>)
        .asBroadcastStream();

/// Static entry points of the terminal plugin.
class AetherlinkTerminal {
  const AetherlinkTerminal._();

  /// Directory where the APK's native libraries (libproot.so and its loaders)
  /// were extracted — the only place Android allows exec'ing binaries from.
  static Future<String> nativeLibDir() async =>
      (await _channel.invokeMethod<String>('getNativeLibDir'))!;

  /// Extracts a rootfs `.tar.gz` at [archivePath] into [destPath] natively,
  /// restoring symlinks, hardlinks and permission bits.
  static Future<void> extractTarGz({
    required String archivePath,
    required String destPath,
  }) =>
      _channel.invokeMethod<void>('extractTarGz', {
        'archivePath': archivePath,
        'destPath': destPath,
      });

  /// Starts [cmd] (an absolute path, e.g. libproot.so) with [args] / [env] on
  /// a fresh PTY of [rows] x [columns] cells.
  static Future<TerminalPtySession> startPty({
    required String cmd,
    List<String> args = const [],
    Map<String, String> env = const {},
    String? cwd,
    int rows = 24,
    int columns = 80,
  }) async {
    final id = (await _channel.invokeMethod<int>('ptyStart', {
      'cmd': cmd,
      'args': args,
      'env': [for (final e in env.entries) '${e.key}=${e.value}'],
      'cwd': cwd,
      'rows': rows,
      'columns': columns,
    }))!;
    return TerminalPtySession._(id, rows: rows, columns: columns);
  }
}

/// A live PTY session: raw output bytes in [output], keystrokes via [write],
/// window-size changes via [resize]. [done] completes with the exit code
/// (negative = killed by that signal).
class TerminalPtySession {
  TerminalPtySession._(this.id, {required int rows, required int columns}) {
    _subscription = _sessionEvents().listen((event) {
      if (event['id'] != id) return;
      final data = event['data'];
      if (data is Uint8List && !_output.isClosed) {
        _output.add(data);
        return;
      }
      final exitCode = event['exitCode'];
      if (exitCode is int) _finish(exitCode);
    });
  }

  final int id;

  final StreamController<Uint8List> _output =
      StreamController<Uint8List>.broadcast();
  final Completer<int> _done = Completer<int>();
  StreamSubscription<Map<Object?, Object?>>? _subscription;

  Stream<Uint8List> get output => _output.stream;

  /// Completes with the process's exit code when the session ends.
  Future<int> get done => _done.future;

  int? get exitCode => _done.isCompleted ? _exitCode : null;
  int? _exitCode;

  void write(List<int> data) {
    _channel.invokeMethod<void>('ptyWrite', {
      'id': id,
      'data': Uint8List.fromList(data),
    });
  }

  void resize(int columns, int rows) {
    _channel.invokeMethod<void>('ptyResize', {
      'id': id,
      'rows': rows,
      'columns': columns,
    });
  }

  /// SIGKILLs the process group. [done] still completes (with −9).
  Future<void> kill() =>
      _channel.invokeMethod<void>('ptyKill', {'id': id}).catchError((_) {});

  void _finish(int exitCode) {
    _exitCode = exitCode;
    if (!_done.isCompleted) _done.complete(exitCode);
    if (!_output.isClosed) _output.close();
    _subscription?.cancel();
    _subscription = null;
  }
}
