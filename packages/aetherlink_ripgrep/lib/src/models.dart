// native/src/lib.rs 请求 / 响应 JSON 的 Dart 镜像。

/// Search request passed to the native library as JSON.
class RgSearchRequest {
  const RgSearchRequest({
    required this.directory,
    required this.query,
    this.searchNames = false,
    this.searchContent = false,
    this.fileTypes = const [],
    this.skipDirs = const [],
    this.maxResults = 200,
    this.useRegex = false,
    this.maxMatchesPerFile = 5,
    this.maxFileBytes = 10 * 1024 * 1024,
  });

  /// Host filesystem directory to walk (absolute path).
  final String directory;

  /// Query text; a case-insensitive regex when [useRegex] is true, otherwise
  /// a case-insensitive substring.
  final String query;

  final bool searchNames;
  final bool searchContent;

  /// File name suffix filters（如 `.dart`）；空表示不过滤。
  final List<String> fileTypes;

  /// Directory names pruned from the walk.
  final List<String> skipDirs;

  final int maxResults;
  final bool useRegex;

  /// Max matched lines returned per file (content searches).
  final int maxMatchesPerFile;

  /// Files larger than this are skipped by content scans.
  final int maxFileBytes;

  Map<String, dynamic> toJson() => {
    'directory': directory,
    'query': query,
    'searchNames': searchNames,
    'searchContent': searchContent,
    'fileTypes': fileTypes,
    'skipDirs': skipDirs,
    'maxResults': maxResults,
    'useRegex': useRegex,
    'maxMatchesPerFile': maxMatchesPerFile,
    'maxFileBytes': maxFileBytes,
  };
}

/// One matched line of a content search.
class RgMatchLine {
  const RgMatchLine({required this.lineNumber, required this.line});

  factory RgMatchLine.fromJson(Map<String, dynamic> json) => RgMatchLine(
    lineNumber: (json['lineNumber'] as num).toInt(),
    line: json['line'] as String,
  );

  /// 1-based 行号。
  final int lineNumber;
  final String line;
}

/// One search hit. [matchCount] is the file's total number of matching lines
/// (null for name-only hits); [matches] holds at most `maxMatchesPerFile`.
class RgSearchHit {
  const RgSearchHit({
    required this.path,
    required this.isDir,
    required this.size,
    required this.mtimeMs,
    this.matchCount,
    this.matches = const [],
  });

  factory RgSearchHit.fromJson(Map<String, dynamic> json) => RgSearchHit(
    path: json['path'] as String,
    isDir: json['isDir'] as bool? ?? false,
    size: (json['size'] as num?)?.toInt() ?? 0,
    mtimeMs: (json['mtimeMs'] as num?)?.toInt() ?? 0,
    matchCount: (json['matchCount'] as num?)?.toInt(),
    matches: [
      for (final m in (json['matches'] as List? ?? const []))
        RgMatchLine.fromJson(m as Map<String, dynamic>),
    ],
  );

  /// Host filesystem path of the hit.
  final String path;
  final bool isDir;
  final int size;
  final int mtimeMs;
  final int? matchCount;
  final List<RgMatchLine> matches;
}

/// Search response decoded from the native library's JSON.
class RgSearchResponse {
  const RgSearchResponse({
    required this.ok,
    required this.error,
    required this.hits,
    required this.truncated,
  });

  factory RgSearchResponse.fromJson(Map<String, dynamic> json) =>
      RgSearchResponse(
        ok: json['ok'] as bool? ?? false,
        error: json['error'] as String? ?? '',
        hits: [
          for (final h in (json['hits'] as List? ?? const []))
            RgSearchHit.fromJson(h as Map<String, dynamic>),
        ],
        truncated: json['truncated'] as bool? ?? false,
      );

  final bool ok;
  final String error;
  final List<RgSearchHit> hits;

  /// True when `maxResults` cut the walk short.
  final bool truncated;
}
