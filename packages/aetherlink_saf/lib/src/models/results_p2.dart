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

/// A single matched line of a content search (spec P2 `searchFiles`).
@immutable
class SearchMatchLine {
  const SearchMatchLine({required this.lineNumber, required this.line});

  /// 1-based 行号。
  final int lineNumber;
  final String line;

  factory SearchMatchLine.fromMap(Map<Object?, Object?> map) => SearchMatchLine(
    lineNumber: (map['lineNumber'] as num?)?.toInt() ?? 0,
    line: (map['line'] as String?) ?? '',
  );
}

/// One `searchFiles` hit: the file plus, for content searches, its matched
/// lines. [matchCount] is the file's total matching-line count (can exceed
/// `matches.length` under the per-file cap); null when the native side didn't
/// scan the content (name-only search, unreadable / oversized file).
@immutable
class SearchHit {
  const SearchHit({
    required this.info,
    this.matchCount,
    this.matches = const [],
  });

  final FileInfo info;
  final int? matchCount;
  final List<SearchMatchLine> matches;

  factory SearchHit.fromMap(Map<Object?, Object?> map) {
    final rawMatches = map['matches'];
    return SearchHit(
      info: FileInfo.fromMap(map),
      matchCount: (map['matchCount'] as num?)?.toInt(),
      matches: [
        if (rawMatches is List)
          for (final item in rawMatches)
            if (item is Map)
              SearchMatchLine.fromMap(item.cast<Object?, Object?>()),
      ],
    );
  }
}

/// Result of `searchFiles` (spec P2). [totalFound] equals `hits.length`
/// (the native side caps both at `maxResults`).
@immutable
class SearchResult {
  const SearchResult({required this.hits, required this.totalFound});

  final List<SearchHit> hits;
  final int totalFound;

  List<FileInfo> get files => [for (final h in hits) h.info];

  factory SearchResult.fromMap(Map<Object?, Object?> map) {
    final raw = map['files'];
    final hits = <SearchHit>[
      if (raw is List)
        for (final item in raw)
          if (item is Map) SearchHit.fromMap(item.cast<Object?, Object?>()),
    ];
    return SearchResult(
      hits: hits,
      totalFound: (map['totalFound'] as num?)?.toInt() ?? hits.length,
    );
  }
}

/// Result of `listRecursive` (spec P2): the flattened entries in depth-first
/// pre-order plus whether the `maxEntries` cap cut the walk short.
@immutable
class ListRecursiveResult {
  const ListRecursiveResult({required this.files, required this.truncated});

  final List<FileInfo> files;
  final bool truncated;

  factory ListRecursiveResult.fromMap(Map<Object?, Object?> map) {
    final raw = map['files'];
    return ListRecursiveResult(
      files: [
        if (raw is List)
          for (final item in raw)
            if (item is Map) FileInfo.fromMap(item.cast<Object?, Object?>()),
      ],
      truncated: (map['truncated'] as bool?) ?? false,
    );
  }
}
