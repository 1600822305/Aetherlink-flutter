// Models and error codes for the Aetherlink local SAF workspace plugin.
//
// Mirrors docs/本地SAF工作区插件-方法规格.md §2 (data structures) and §3.2
// (error codes). When the spec doc and these files disagree, the spec doc
// wins — fix the code, not the doc.

import 'package:flutter/foundation.dart';

/// File metadata returned by `listDirectory` / `getFileInfo` (spec §2.1).
///
/// On Android, `path` and `uri` are both the full `content://` URI for the
/// document — see spec §3.1 for the URI rules. Some fields are best-effort:
/// `ctime` and `permissions` are routinely `null` because SAF providers
/// don't expose them.
@immutable
class FileInfo {
  const FileInfo({
    required this.name,
    required this.path,
    required this.uri,
    required this.size,
    required this.type,
    required this.mtime,
    required this.isHidden,
    this.ctime,
    this.mimeType,
    this.permissions,
  });

  final String name;
  // §3.1: full `content://` URI on Android.
  final String path;
  // Same value as [path]; kept as a separate field so upstream code can
  // express semantic intent (a "URI handle" vs. a "path-shaped string").
  final String uri;
  // Bytes; 0 for directories.
  final int size;
  final FileType type;
  // epoch ms; 0 means the provider didn't supply it.
  final int mtime;
  // epoch ms; nullable — most SAF providers don't expose creation time.
  final int? ctime;
  final String? mimeType;
  final bool isHidden;
  // Always `null` on Android (SAF has no unix mode bits); kept for iOS.
  final String? permissions;

  factory FileInfo.fromMap(Map<Object?, Object?> map) {
    return FileInfo(
      name: (map['name'] as String?) ?? '',
      path: (map['path'] as String?) ?? '',
      uri: (map['uri'] as String?) ?? (map['path'] as String?) ?? '',
      size: (map['size'] as num?)?.toInt() ?? 0,
      type: map['type'] == 'directory' ? FileType.directory : FileType.file,
      mtime: (map['mtime'] as num?)?.toInt() ?? 0,
      ctime: (map['ctime'] as num?)?.toInt(),
      mimeType: map['mimeType'] as String?,
      isHidden: (map['isHidden'] as bool?) ?? false,
      permissions: map['permissions'] as String?,
    );
  }

  Map<String, Object?> toMap() => {
        'name': name,
        'path': path,
        'uri': uri,
        'size': size,
        'type': type == FileType.directory ? 'directory' : 'file',
        'mtime': mtime,
        if (ctime != null) 'ctime': ctime,
        if (mimeType != null) 'mimeType': mimeType,
        'isHidden': isHidden,
        if (permissions != null) 'permissions': permissions,
      };

  @override
  String toString() =>
      'FileInfo(${type == FileType.directory ? 'd' : 'f'} $name @ $path)';
}

/// What the system picker returns, plus a UI-friendly path (spec §2.2).
///
/// `displayPath` is **display-only**; don't pass it back to any API — pass the
/// `uri` / `path` instead (§3.1).
@immutable
class SelectedFileInfo extends FileInfo {
  const SelectedFileInfo({
    required super.name,
    required super.path,
    required super.uri,
    required super.size,
    required super.type,
    required super.mtime,
    required super.isHidden,
    super.ctime,
    super.mimeType,
    super.permissions,
    this.displayPath,
  });

  final String? displayPath;

  factory SelectedFileInfo.fromMap(Map<Object?, Object?> map) {
    final base = FileInfo.fromMap(map);
    return SelectedFileInfo(
      name: base.name,
      path: base.path,
      uri: base.uri,
      size: base.size,
      type: base.type,
      mtime: base.mtime,
      isHidden: base.isHidden,
      ctime: base.ctime,
      mimeType: base.mimeType,
      permissions: base.permissions,
      displayPath: map['displayPath'] as String?,
    );
  }
}

/// Whether an entry is a file or a directory (spec §2.1).
enum FileType { file, directory }

/// Sort key for [listDirectory] (spec P0). `wireValue` is the string sent
/// to the native side; the spelling is fixed by the spec doc.
///
/// (Value names are prefixed `by*` because `name` would shadow the
/// `Enum.name` getter that produces the wire value otherwise.)
enum FileSortBy {
  byName('name'),
  bySize('size'),
  byMtime('mtime'),
  byType('type');

  const FileSortBy(this.wireValue);

  final String wireValue;
}

/// Sort order for [listDirectory] (spec P0).
enum FileSortOrder {
  asc('asc'),
  desc('desc');

  const FileSortOrder(this.wireValue);

  final String wireValue;
}

/// Picker target for `openSystemFilePicker` (spec P0).
///
/// Android cannot combine the two intents, so `'both'` is intentionally
/// absent (spec §3.4). Callers that need both should call twice.
enum PickerType {
  file('file'),
  directory('directory');

  const PickerType(this.wireValue);

  final String wireValue;
}

/// Error codes raised as `PlatformException.code` from the native side
/// (spec §3.2). Kept as constants instead of an enum so callers can
/// switch on `PlatformException.code` directly without parsing.
abstract final class AetherlinkSafErrorCode {
  static const String noPermission = 'E_NO_PERMISSION';
  static const String uriStale = 'E_URI_STALE';
  static const String notFound = 'E_NOT_FOUND';
  static const String invalidArg = 'E_INVALID_ARG';
  static const String io = 'E_IO';
  static const String outOfSpace = 'E_OUT_OF_SPACE';
  static const String tooLarge = 'E_TOO_LARGE';
  static const String rangeConflict = 'E_RANGE_CONFLICT';
  static const String notSupported = 'E_NOT_SUPPORTED';
  static const String userCancelled = 'E_USER_CANCELLED';
}

/// Result of `requestPermissions` / `checkPermissions` (spec P0).
@immutable
class PermissionResult {
  const PermissionResult({required this.granted, this.message});

  final bool granted;
  final String? message;

  factory PermissionResult.fromMap(Map<Object?, Object?> map) =>
      PermissionResult(
        granted: (map['granted'] as bool?) ?? false,
        message: map['message'] as String?,
      );
}

/// Result of `openSystemFilePicker` (spec P0).
@immutable
class PickerResult {
  const PickerResult({
    required this.files,
    required this.directories,
    required this.cancelled,
  });

  final List<SelectedFileInfo> files;
  final List<SelectedFileInfo> directories;
  final bool cancelled;

  static List<SelectedFileInfo> _decodeList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) SelectedFileInfo.fromMap(item.cast<Object?, Object?>()),
    ];
  }

  factory PickerResult.fromMap(Map<Object?, Object?> map) => PickerResult(
        files: _decodeList(map['files']),
        directories: _decodeList(map['directories']),
        cancelled: (map['cancelled'] as bool?) ?? false,
      );
}

/// Result of `listDirectory` (spec P0).
@immutable
class ListDirectoryResult {
  const ListDirectoryResult({required this.files, required this.totalCount});

  final List<FileInfo> files;
  final int totalCount;

  factory ListDirectoryResult.fromMap(Map<Object?, Object?> map) {
    final raw = map['files'];
    final files = <FileInfo>[
      if (raw is List)
        for (final item in raw)
          if (item is Map) FileInfo.fromMap(item.cast<Object?, Object?>()),
    ];
    return ListDirectoryResult(
      files: files,
      totalCount: (map['totalCount'] as num?)?.toInt() ?? files.length,
    );
  }
}

/// Result of `readFile` (spec P0). [size] is the underlying file size in
/// bytes (not the encoded `content` length).
@immutable
class ReadFileResult {
  const ReadFileResult({
    required this.content,
    required this.encoding,
    required this.size,
  });

  final String content;
  final String encoding;
  final int size;

  factory ReadFileResult.fromMap(Map<Object?, Object?> map) => ReadFileResult(
        content: (map['content'] as String?) ?? '',
        encoding: (map['encoding'] as String?) ?? 'utf8',
        size: (map['size'] as num?)?.toInt() ?? 0,
      );
}

/// Result of `echo` (spec P0 connectivity self-test).
@immutable
class EchoResult {
  const EchoResult({required this.value});

  final String value;

  factory EchoResult.fromMap(Map<Object?, Object?> map) =>
      EchoResult(value: (map['value'] as String?) ?? '');
}
