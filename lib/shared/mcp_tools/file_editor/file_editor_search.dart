// `search_files` 的纯逻辑：行匹配（正则/字面量 × 大小写开关）、glob 路径
// 过滤、命中行 + 上下文提取。与后端无关，便于单测。

/// Caps: per-file / overall hit counts and per-line snippet length, so a hot
/// query can't flood the model context.
const int kMaxMatchesPerFile = 5;
const int kMaxTotalMatches = 100;
const int kMaxMatchLineChars = 200;

/// 一行是否命中 query（正则或字面量，含大小写开关）。构造失败（非法正则）
/// 时 [tryCreate] 返回 null。
class SearchLineMatcher {
  SearchLineMatcher._(this._regex, this._literal, this._caseSensitive);

  final RegExp? _regex;
  final String? _literal;
  final bool _caseSensitive;

  static SearchLineMatcher? tryCreate(
    String query, {
    bool useRegex = false,
    bool caseSensitive = false,
  }) {
    if (useRegex) {
      try {
        return SearchLineMatcher._(
          RegExp(query, caseSensitive: caseSensitive),
          null,
          caseSensitive,
        );
      } on FormatException {
        return null;
      }
    }
    return SearchLineMatcher._(
      null,
      caseSensitive ? query : query.toLowerCase(),
      caseSensitive,
    );
  }

  bool matches(String line) {
    final regex = _regex;
    if (regex != null) return regex.hasMatch(line);
    return (_caseSensitive ? line : line.toLowerCase()).contains(_literal!);
  }
}

/// 把 glob（`*` 不跨目录、`**` 跨目录、`?` 单字符）编译为全匹配正则；
/// 非法模式返回 null。
RegExp? globToRegExp(String glob) {
  final buf = StringBuffer(r'^');
  for (var i = 0; i < glob.length; i++) {
    final c = glob[i];
    if (c == '*') {
      if (i + 1 < glob.length && glob[i + 1] == '*') {
        // `**/` 也匹配零层目录（`**/*.dart` 能命中根下的文件）。
        if (i + 2 < glob.length && glob[i + 2] == '/') {
          buf.write(r'(?:.*/)?');
          i += 2;
        } else {
          buf.write('.*');
          i += 1;
        }
      } else {
        buf.write('[^/]*');
      }
    } else if (c == '?') {
      buf.write('[^/]');
    } else {
      buf.write(RegExp.escape(c));
    }
  }
  buf.write(r'$');
  try {
    return RegExp(buf.toString());
  } on FormatException {
    return null;
  }
}

/// glob 是否命中一个文件：模式含 `/` 时按 [relPath]（相对搜索目录）匹配，
/// 否则按文件名匹配。
bool globHits(RegExp pattern, String glob, {
  required String name,
  required String relPath,
}) =>
    glob.contains('/') ? pattern.hasMatch(relPath) : pattern.hasMatch(name);

/// 从 [path] 推出相对 [directory] 的路径（POSIX 风格）。SAF 的
/// `content://` URI 会先做 URL 解码再取后缀；推不出来时退回文件名。
String relativePathOf(String directory, String path, String name) {
  String? strip(String dir, String p) {
    if (!p.startsWith(dir)) return null;
    var rest = p.substring(dir.length);
    // SAF URI 的子路径以 %2F 编码分隔，先解码再去掉开头的分隔符。
    if (rest.contains('%')) {
      try {
        rest = Uri.decodeComponent(rest);
      } on ArgumentError {
        // 非法转义序列——按原样处理。
      }
    }
    while (rest.startsWith('/')) {
      rest = rest.substring(1);
    }
    return rest.isEmpty ? null : rest;
  }

  final direct = strip(directory, path);
  if (direct != null) return direct;
  try {
    final decoded =
        strip(Uri.decodeComponent(directory), Uri.decodeComponent(path));
    if (decoded != null) return decoded;
  } on ArgumentError {
    // 非法转义序列——按原样处理。
  }
  return name;
}

/// 单个命中行及其上下文。
class LineMatch {
  const LineMatch({required this.line, required this.text, this.context});

  /// 1-based 行号。
  final int line;
  final String text;

  /// 上下文窗口（含命中行本身），仅当 contextLines > 0。
  final List<({int line, String text})>? context;

  Map<String, Object?> toJson() => {
        'line': line,
        'text': text,
        if (context != null)
          'context': [
            for (final c in context!) {'line': c.line, 'text': c.text},
          ],
      };
}

/// [content] 中所有命中 [matcher] 的行。[maxMatches] 限制返回条数
/// （countOnly 场景传大值）；[contextLines] > 0 时每条命中带前后 N 行。
List<LineMatch> findMatchingLines(
  String content,
  SearchLineMatcher matcher, {
  int maxMatches = kMaxMatchesPerFile,
  int contextLines = 0,
}) {
  final lines = content.split('\n');
  final matches = <LineMatch>[];
  for (var i = 0; i < lines.length; i++) {
    if (!matcher.matches(lines[i])) continue;
    List<({int line, String text})>? context;
    if (contextLines > 0) {
      final start = (i - contextLines).clamp(0, lines.length - 1);
      final end = (i + contextLines).clamp(0, lines.length - 1);
      context = [
        for (var j = start; j <= end; j++)
          (line: j + 1, text: _snip(lines[j])),
      ];
    }
    matches.add(LineMatch(line: i + 1, text: _snip(lines[i]), context: context));
    if (matches.length >= maxMatches) break;
  }
  return matches;
}

/// [content] 中命中 [matcher] 的行数（count 模式，不受条数上限约束）。
int countMatchingLines(String content, SearchLineMatcher matcher) {
  var count = 0;
  for (final line in content.split('\n')) {
    if (matcher.matches(line)) count++;
  }
  return count;
}

String _snip(String line) => line.length > kMaxMatchLineChars
    ? '${line.substring(0, kMaxMatchLineChars)}…'
    : line;
