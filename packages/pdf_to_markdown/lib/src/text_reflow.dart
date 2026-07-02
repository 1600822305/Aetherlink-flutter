/// 把 PDFium 结构化文本（逐页、带行断）重排成适合摄取/阅读的段落文本。
///
/// PDFium 的文本层只有行级断行，没有段落/标题语义，这里用启发式做还原：
/// - 行尾连字符（`fo-\nbar`）在下一行以小写字母开头时去连字符拼接；
/// - 列表行（`-`/`*`/`•`/`1.`/`1)` 开头）保持独立行，`•` 归一为 `-`；
/// - 以句末标点（中英文）结尾的行视为段落结束；
/// - 其余相邻行合并进同一段：两侧都是 CJK 时直接拼接，否则以空格连接；
/// - 页与页之间以空行分隔，空页跳过。
library;

final _bulletLine = RegExp(r'^\s*([-*•‣▪]|\d{1,3}[.)、])\s+');
final _terminalPunctuation = RegExp(r'[.!?:;。！？：；…"' r"'）)】》」』]\s*$");
final _cjk = RegExp(
  r'[\u3000-\u303f\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff00-\uffef]',
);

bool _isCjk(String char) => _cjk.hasMatch(char);

/// 重排多页文本，返回合并后的整篇文本；全部为空页时返回空字符串。
String reflowPdfPages(List<String> pageTexts) {
  final pages = <String>[];
  for (final pageText in pageTexts) {
    final reflowed = _reflowPage(pageText);
    if (reflowed.isNotEmpty) pages.add(reflowed);
  }
  return pages.join('\n\n');
}

String _reflowPage(String pageText) {
  final lines = pageText
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) => line.trimRight())
      .toList();

  final paragraphs = <String>[];
  var current = StringBuffer();

  void flush() {
    final text = current.toString().trim();
    if (text.isNotEmpty) paragraphs.add(text);
    current = StringBuffer();
  }

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      flush();
      continue;
    }
    final bulletMatch = _bulletLine.firstMatch(line);
    if (bulletMatch != null) {
      flush();
      final marker = bulletMatch.group(1)!;
      final normalized = RegExp(r'^[-*•‣▪]$').hasMatch(marker)
          ? line.replaceFirst(marker, '-')
          : line;
      paragraphs.add(normalized);
      continue;
    }
    if (current.isEmpty) {
      current.write(line);
    } else {
      final joined = current.toString();
      if (joined.endsWith('-') &&
          line.isNotEmpty &&
          line[0].toLowerCase() == line[0] &&
          line[0].toUpperCase() != line[0]) {
        // 英文断词连字符：去掉连字符直接拼接。
        current = StringBuffer(joined.substring(0, joined.length - 1))
          ..write(line);
      } else if (_isCjk(joined[joined.length - 1]) && _isCjk(line[0])) {
        current.write(line);
      } else {
        current
          ..write(' ')
          ..write(line);
      }
    }
    if (_terminalPunctuation.hasMatch(line)) flush();
  }
  flush();
  return paragraphs.join('\n\n');
}
