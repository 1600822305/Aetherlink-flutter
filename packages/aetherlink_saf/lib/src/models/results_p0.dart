// P0 result types — echo, permissions, picker, list, read.

import 'package:flutter/foundation.dart';

import 'file_info.dart';

/// Result of `echo` (spec P0 connectivity self-test).
@immutable
class EchoResult {
  const EchoResult({required this.value});

  final String value;

  factory EchoResult.fromMap(Map<Object?, Object?> map) =>
      EchoResult(value: (map['value'] as String?) ?? '');
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
