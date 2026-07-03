import 'package:flutter/services.dart';

import 'models.dart';

/// Entry point for the DEX/APK editing plugin.
///
/// Transport contract with the native side:
///  - method channel `com.aetherlink.dexeditor/methods`
///    * `execute(action, params)` -> `{ success, data?, error? }`
///    * `openSmaliEditor` / `openXmlEditor` / `openCodeEditor` -> editor result
///  - event channel `com.aetherlink.dexeditor/events` -> compile progress
///
/// All operations are dispatched by action name so the whole native operation
/// catalogue is reachable without a bespoke Dart method per action; the
/// higher-level MCP tool layer builds on top of [execute].
class DexEditor {
  DexEditor._();

  /// Shared instance. The plugin is inherently stateful on the native side
  /// (open sessions), so a singleton avoids channel duplication.
  static final DexEditor instance = DexEditor._();

  static const MethodChannel _methods =
      MethodChannel('com.aetherlink.dexeditor/methods');
  static const EventChannel _events =
      EventChannel('com.aetherlink.dexeditor/events');

  Stream<DexProgressEvent>? _progress;

  /// Compile/save progress events streamed from native. Broadcast so multiple
  /// listeners (UI + logging) can observe the same run.
  Stream<DexProgressEvent> get progress {
    return _progress ??= _events
        .receiveBroadcastStream()
        .map((event) => DexProgressEvent.fromMap(
              (event as Map).cast<Object?, Object?>(),
            ));
  }

  /// Runs a native [action] (see `DexActionDispatcher`) with [params].
  ///
  /// Never throws for business errors — those come back as
  /// [DexResult.success] == false with [DexResult.error]. A [DexException] is
  /// thrown only for transport-level failures.
  Future<DexResult> execute(
    String action, [
    Map<String, Object?> params = const {},
  ]) async {
    try {
      final raw = await _methods.invokeMapMethod<Object?, Object?>('execute', {
        'action': action,
        'params': params,
      });
      return DexResult.fromMap(raw ?? const {'success': false});
    } on PlatformException catch (e) {
      throw DexException(e.code, e.message, e.details);
    }
  }

  Future<EditorResult> openSmaliEditor({
    required String content,
    String? title,
    String? className,
    bool readOnly = false,
  }) {
    return _openEditor('openSmaliEditor', {
      'content': content,
      'title': title,
      'className': className,
      'readOnly': readOnly,
    });
  }

  Future<EditorResult> openXmlEditor({
    required String content,
    String? title,
    String? filePath,
    bool readOnly = false,
  }) {
    return _openEditor('openXmlEditor', {
      'content': content,
      'title': title,
      'filePath': filePath,
      'readOnly': readOnly,
    });
  }

  Future<EditorResult> openCodeEditor({
    required String content,
    String? title,
    String? filePath,
    String? syntaxFile,
    bool readOnly = false,
  }) {
    return _openEditor('openCodeEditor', {
      'content': content,
      'title': title,
      'filePath': filePath,
      'syntaxFile': syntaxFile,
      'readOnly': readOnly,
    });
  }

  Future<EditorResult> _openEditor(
    String method,
    Map<String, Object?> args,
  ) async {
    try {
      final raw = await _methods.invokeMapMethod<Object?, Object?>(method, args);
      return EditorResult.fromMap(raw ?? const {'success': false});
    } on PlatformException catch (e) {
      throw DexException(e.code, e.message, e.details);
    }
  }
}
