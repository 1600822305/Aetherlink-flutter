import 'package:flutter/foundation.dart';

/// Result envelope returned by every [DexEditor.execute] call.
///
/// Mirrors the native `{ success, data?, error? }` shape produced by
/// `DexActionDispatcher`. Kept intentionally thin: [data] is the decoded
/// payload (usually a `Map` or `List`) that the higher-level MCP tool layer
/// formats for the model.
@immutable
class DexResult {
  const DexResult({required this.success, this.data, this.error});

  factory DexResult.fromMap(Map<Object?, Object?> map) {
    return DexResult(
      success: map['success'] == true,
      data: map['data'],
      error: map['error'] as String?,
    );
  }

  final bool success;
  final Object? data;
  final String? error;

  @override
  String toString() => 'DexResult(success: $success, error: $error)';
}

/// Thrown when a native call fails at the transport level (bad args, missing
/// activity, platform exception). Business-level failures are instead reported
/// via [DexResult.success] == false + [DexResult.error].
@immutable
class DexException implements Exception {
  const DexException(this.code, this.message, [this.details]);

  final String code;
  final String? message;
  final Object? details;

  @override
  String toString() => 'DexException($code): $message';
}

/// Result of launching one of the native editor activities.
@immutable
class EditorResult {
  const EditorResult({
    required this.success,
    this.content,
    this.modified = false,
    this.cancelled = false,
  });

  factory EditorResult.fromMap(Map<Object?, Object?> map) {
    return EditorResult(
      success: map['success'] == true,
      content: map['content'] as String?,
      modified: map['modified'] == true,
      cancelled: map['cancelled'] == true,
    );
  }

  final bool success;
  final String? content;
  final bool modified;
  final bool cancelled;
}

/// Kinds of events streamed on [DexEditor.progress].
enum DexProgressType { progress, message, title, unknown }

/// A single compile-progress event streamed from the native side while a DEX
/// is being assembled/saved.
@immutable
class DexProgressEvent {
  const DexProgressEvent({
    required this.type,
    this.current = 0,
    this.total = 0,
    this.percent = 0,
    this.message,
    this.title,
  });

  factory DexProgressEvent.fromMap(Map<Object?, Object?> map) {
    final rawType = map['type'] as String?;
    final type = switch (rawType) {
      'progress' => DexProgressType.progress,
      'message' => DexProgressType.message,
      'title' => DexProgressType.title,
      _ => DexProgressType.unknown,
    };
    return DexProgressEvent(
      type: type,
      current: (map['current'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
      percent: (map['percent'] as num?)?.toInt() ?? 0,
      message: map['message'] as String?,
      title: map['title'] as String?,
    );
  }

  final DexProgressType type;
  final int current;
  final int total;
  final int percent;
  final String? message;
  final String? title;
}
