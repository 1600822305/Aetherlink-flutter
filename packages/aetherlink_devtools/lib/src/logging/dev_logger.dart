import 'dart:developer' as developer;

import '../console/console_store.dart';
import '../models/log_entry.dart';

/// Creates a [DevLogger] tagged with [context] (the emitting module, e.g.
/// `ChatController`). The structured-logging façade from devtools-design §4.1-B:
/// business code calls `final _log = createLogger('Foo');` then `_log.info(...)`,
/// and the Console panel gains real level + per-module (context) filtering on top
/// of the zero-touch global capture.
///
/// ```dart
/// final _log = createLogger('BackupService');
/// _log.info('backup started');
/// try { ... } catch (e, s) { _log.error('backup failed', error: e, stackTrace: s); }
/// ```
DevLogger createLogger(String context) => DevLogger(context);

/// A lightweight, context-tagged logger that feeds the [ConsoleStore] (so entries
/// show up in the in-app Console with the right level + context) and mirrors to
/// `dart:developer`'s `log` for the IDE console.
///
/// It deliberately does NOT route through `debugPrint`: that channel is already
/// captured globally by [DevToolsCapture], so going through it would double-log.
class DevLogger {
  const DevLogger(this.context);

  /// The module tag shown in the Console's `[context]` column and usable as a
  /// group/filter key.
  final String context;

  void error(Object? message, {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.error, message, error, stackTrace);

  void warn(Object? message, {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.warn, message, error, stackTrace);

  void info(Object? message) => _log(LogLevel.info, message, null, null);

  void debug(Object? message) => _log(LogLevel.debug, message, null, null);

  void trace(Object? message) => _log(LogLevel.trace, message, null, null);

  void _log(
    LogLevel level,
    Object? message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    final text = error == null ? '$message' : '$message: $error';
    ConsoleStore.instance.add(
      level: level,
      message: text,
      context: context,
      stackTrace: stackTrace?.toString(),
    );
    developer.log(
      text,
      name: context,
      level: _developerLevel(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Maps to `dart:developer` levels (loosely `dart:logging`'s scale).
  static int _developerLevel(LogLevel level) {
    switch (level) {
      case LogLevel.error:
        return 1000;
      case LogLevel.warn:
        return 900;
      case LogLevel.info:
        return 800;
      case LogLevel.debug:
        return 500;
      case LogLevel.trace:
        return 300;
    }
  }
}
