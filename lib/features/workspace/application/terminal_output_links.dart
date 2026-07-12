// 终端输出中 `path:line` 形式文件引用的纯 Dart 提取（编译错误、grep -n、
// 堆栈跟踪等），供终端页「跳转到文件」用；UI 负责把相对路径解析成
// 后端条目并打开编辑器。

/// One `path:line` reference found in terminal output.
class TerminalFileLink {
  const TerminalFileLink({required this.path, required this.line});

  final String path;
  final int line;
}

/// Matches `some/path/file.ext:123` — the path needs a file extension so
/// prompts like `host:22` or timestamps don't false-positive.
final RegExp _fileLinkPattern = RegExp(
  r'((?:~|\.{1,2})?/?[\w.+@-]+(?:/[\w.+@-]+)*\.[A-Za-z][A-Za-z0-9_]{0,9}):(\d{1,6})',
);

/// Scans [lines] (oldest → newest) and returns the distinct `path:line`
/// references, most recent first, capped at [max].
List<TerminalFileLink> extractFileLinks(List<String> lines, {int max = 20}) {
  final seen = <String>{};
  final links = <TerminalFileLink>[];
  for (var i = lines.length - 1; i >= 0 && links.length < max; i--) {
    for (final m in _fileLinkPattern.allMatches(lines[i])) {
      final path = m.group(1)!;
      final line = int.tryParse(m.group(2)!);
      if (line == null || line < 1) continue;
      if (!seen.add('$path:$line')) continue;
      links.add(TerminalFileLink(path: path, line: line));
      if (links.length >= max) break;
    }
  }
  return links;
}
