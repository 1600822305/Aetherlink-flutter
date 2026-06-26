// P1 result types — advanced reads + the shared {path} write result.

import 'package:flutter/foundation.dart';

/// Result of any write/structure method that returns the new node's URI
/// (`createFile` / `createDirectory` / `renameFile` / `moveFile` /
/// `copyFile`, spec P1). The single field is the `content://` URI of the
/// resulting document (spec §3.1).
@immutable
class PathResult {
  const PathResult({required this.path});

  final String path;

  factory PathResult.fromMap(Map<Object?, Object?> map) =>
      PathResult(path: (map['path'] as String?) ?? '');
}

/// Result of `readFileRange` (spec P1). [rangeHash] is the sha256 of the
/// raw bytes of the returned lines (§3.3) — pass it back as
/// `applyDiff(expectedRangeHash:)` for optimistic-lock writes.
@immutable
class ReadFileRangeResult {
  const ReadFileRangeResult({
    required this.content,
    required this.totalLines,
    required this.startLine,
    required this.endLine,
    required this.rangeHash,
  });

  final String content;
  final int totalLines;
  // Echoed back clamped to the real file bounds (1-based, closed range).
  final int startLine;
  final int endLine;
  final String rangeHash;

  factory ReadFileRangeResult.fromMap(Map<Object?, Object?> map) =>
      ReadFileRangeResult(
        content: (map['content'] as String?) ?? '',
        totalLines: (map['totalLines'] as num?)?.toInt() ?? 0,
        startLine: (map['startLine'] as num?)?.toInt() ?? 0,
        endLine: (map['endLine'] as num?)?.toInt() ?? 0,
        rangeHash: (map['rangeHash'] as String?) ?? '',
      );
}

/// Result of `getFileHash` (spec P1).
@immutable
class FileHashResult {
  const FileHashResult({required this.hash, required this.algorithm});

  final String hash;
  final String algorithm;

  factory FileHashResult.fromMap(Map<Object?, Object?> map) => FileHashResult(
        hash: (map['hash'] as String?) ?? '',
        algorithm: (map['algorithm'] as String?) ?? '',
      );
}
