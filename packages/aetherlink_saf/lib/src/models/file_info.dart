// FileInfo / SelectedFileInfo — mirrors spec §2.1 / §2.2.

import 'package:flutter/foundation.dart';

/// Whether an entry is a file or a directory (spec §2.1).
enum FileType { file, directory }

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
