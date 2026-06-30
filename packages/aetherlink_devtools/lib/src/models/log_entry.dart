/// Immutable value types for the Console panel. Plain Dart (no codegen) so the
/// package stays dependency-free, mirroring `aetherlink_perf`.
library;

/// Severity of a captured console entry, ordered most → least severe.
///
/// Mirrors the original web's `LogLevelName` (`ERROR/WARN/INFO/DEBUG/TRACE`) so
/// the UI, filters and exports line up 1:1 across the two apps.
enum LogLevel {
  error('ERROR'),
  warn('WARN'),
  info('INFO'),
  debug('DEBUG'),
  trace('TRACE');

  const LogLevel(this.label);

  /// Upper-case wire/display name, e.g. `ERROR`.
  final String label;
}

/// A single line in the Console panel: a level + message, optionally tagged with
/// a [context] (the emitting module, e.g. `ChatController`) and a [stackTrace]
/// for errors. Captured globally (Flutter/zone errors + `debugPrint`) and held
/// in the [ConsoleStore] ring buffer.
class LogEntry {
  LogEntry({
    required this.id,
    required this.level,
    required this.message,
    DateTime? timestamp,
    this.context,
    this.stackTrace,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Monotonic identifier (assigned by the store) — stable for selection/keys.
  final int id;
  final LogLevel level;
  final String message;
  final DateTime timestamp;

  /// Emitting module / tag, or `null` for un-tagged captures (raw `print`).
  final String? context;

  /// Present for errors/exceptions captured from `FlutterError.onError` and the
  /// zone error handler.
  final String? stackTrace;

  /// A flat, copy/share-friendly line: `[HH:mm:ss] [LEVEL] [ctx] message`.
  String toLine() {
    final t = timestamp;
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    final time = '${two(t.hour)}:${two(t.minute)}:${two(t.second)}'
        '.${three(t.millisecond)}';
    final ctx = context != null ? ' [$context]' : '';
    final stack = stackTrace != null ? '\n$stackTrace' : '';
    return '[$time] [${level.label}]$ctx $message$stack';
  }
}
