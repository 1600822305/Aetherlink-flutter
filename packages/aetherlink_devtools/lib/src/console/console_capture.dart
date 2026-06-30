import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/log_entry.dart';
import '../network/network_panel.dart';
import '../panel.dart';
import 'console_panel.dart';
import 'console_store.dart';

/// Installs the zero-touch global capture hooks that feed the [ConsoleStore], so
/// the Console panel shows useful data without any logging calls in the app:
///
///  * [FlutterError.onError]            → framework / build / layout errors
///  * [PlatformDispatcher.instance.onError] → uncaught async (zone) errors
///  * [debugPrint]                      → every `debugPrint` / `print`-via-debugPrint
///
/// Each original handler is chained, never replaced, so existing behaviour
/// (red-screen errors, console output) is preserved. Call once, early — wrap the
/// app with [runZonedGuarded] using [zoneErrorHandler] to also catch errors
/// thrown outside Flutter's own handlers.
///
/// Idempotent: a second call is a no-op (guards against hot-restart re-wiring).
class DevToolsCapture {
  DevToolsCapture._();

  static bool _installed = false;

  static void install() {
    if (_installed) return;
    _installed = true;

    // Register the built-in panels so [DevToolsPage] has its tabs. Later phases
    // register their own panels alongside these. The Network panel is fed by
    // [DioDevInterceptor] (installed on Dio via the app's `buildAppDio` factory).
    DevToolsRegistry.register(const ConsolePanel());
    DevToolsRegistry.register(const NetworkPanel());

    final prevFlutterOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      ConsoleStore.instance.add(
        level: LogLevel.error,
        message: details.exceptionAsString(),
        context: details.library ?? 'flutter',
        stackTrace: details.stack?.toString(),
      );
      prevFlutterOnError?.call(details);
    };

    final prevPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      ConsoleStore.instance.add(
        level: LogLevel.error,
        message: error.toString(),
        context: 'uncaught',
        stackTrace: stack.toString(),
      );
      return prevPlatformOnError?.call(error, stack) ?? false;
    };

    final prevDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        ConsoleStore.instance.add(level: LogLevel.debug, message: message);
      }
      prevDebugPrint(message, wrapWidth: wrapWidth);
    };
  }

  /// The handler to pass to [runZonedGuarded] so synchronous/async errors that
  /// escape Flutter's own handlers are still captured.
  static void zoneErrorHandler(Object error, StackTrace stack) {
    ConsoleStore.instance.add(
      level: LogLevel.error,
      message: error.toString(),
      context: 'zone',
      stackTrace: stack.toString(),
    );
  }
}
