// P2 result types — replace, applyDiff, search.

import 'package:flutter/foundation.dart';

import 'file_info.dart';

/// Result of `replaceInFile` (spec P2).
@immutable
class ReplaceResult {
  const ReplaceResult({required this.replacements, required this.modified});

  final int replacements;
  final bool modified;

  factory ReplaceResult.fromMap(Map<Object?, Object?> map) => ReplaceResult(
        replacements: (map['replacements'] as num?)?.toInt() ?? 0,
        modified: (map['modified'] as bool?) ?? false,
      );
}

/// Result of `applyDiff` (spec P2). [backupPath] is non-null only when the
/// call was made with `createBackup: true`.
@immutable
class ApplyDiffResult {
  const ApplyDiffResult({
    required this.success,
    required this.linesChanged,
    required this.linesAdded,
    required this.linesDeleted,
    this.backupPath,
  });

  final bool success;
  final int linesChanged;
  final int linesAdded;
  final int linesDeleted;
  final String? backupPath;

  factory ApplyDiffResult.fromMap(Map<Object?, Object?> map) => ApplyDiffResult(
        success: (map['success'] as bool?) ?? false,
        linesChanged: (map['linesChanged'] as num?)?.toInt() ?? 0,
        linesAdded: (map['linesAdded'] as num?)?.toInt() ?? 0,
        linesDeleted: (map['linesDeleted'] as num?)?.toInt() ?? 0,
        backupPath: map['backupPath'] as String?,
      );
}

/// Result of `searchFiles` (spec P2). [totalFound] equals `files.length`
/// (the native side caps both at `maxResults`).
@immutable
class SearchResult {
  const SearchResult({required this.files, required this.totalFound});

  final List<FileInfo> files;
  final int totalFound;

  factory SearchResult.fromMap(Map<Object?, Object?> map) {
    final raw = map['files'];
    final files = <FileInfo>[
      if (raw is List)
        for (final item in raw)
          if (item is Map) FileInfo.fromMap(item.cast<Object?, Object?>()),
    ];
    return SearchResult(
      files: files,
      totalFound: (map['totalFound'] as num?)?.toInt() ?? files.length,
    );
  }
}
