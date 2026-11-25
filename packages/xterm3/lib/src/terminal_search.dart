import 'package:xterm3/src/core/buffer/cell_offset.dart';
import 'package:xterm3/src/core/buffer/range_line.dart';
import 'package:xterm3/src/terminal.dart';
import 'package:xterm3/src/terminal_logical_line.dart';

const _defaultSearchResultLimit = 1000;

final _wordCodePoint = RegExp(
  r'^[\p{L}\p{M}\p{N}\p{Pc}\u200C\u200D]$',
  unicode: true,
);

/// A terminal buffer search match.
final class TerminalSearchMatch {
  const TerminalSearchMatch({
    required this.range,
    required this.text,
  });

  /// The matched cell range. The end offset is exclusive.
  final BufferRangeLine range;

  /// The text matched in the terminal buffer.
  final String text;
}

/// Search support for terminal scrollback and the active viewport.
extension TerminalSearch on Terminal {
  /// Finds [query] in the active buffer.
  ///
  /// Soft-wrapped physical rows are searched as one logical line. Search
  /// results are capped by [maxResults] so repeated output cannot cause
  /// unbounded result allocation.
  List<TerminalSearchMatch> search(
    String query, {
    bool caseSensitive = false,
    bool wholeWord = false,
    bool useRegex = false,
    int maxResults = _defaultSearchResultLimit,
  }) {
    if (query.isEmpty || maxResults <= 0) {
      return const [];
    }

    final pattern = switch (useRegex) {
      true => query,
      false => RegExp.escape(query),
    };
    final expression = RegExp(
      pattern,
      caseSensitive: caseSensitive,
      unicode: true,
    );
    final results = <TerminalSearchMatch>[];
    final buffer = this.buffer;
    final textBuffer = StringBuffer();
    final logicalLineCells = LogicalLineCells();
    var lineIndex = 0;

    while (lineIndex < buffer.lines.length && results.length < maxResults) {
      final logicalLine = buildLogicalLine(
        buffer,
        lineIndex,
        textBuffer,
        logicalLineCells,
      );
      lineIndex = logicalLine.nextLineIndex;
      if (logicalLine.text.isEmpty || logicalLine.cells.isEmpty) continue;

      for (final match in expression.allMatches(logicalLine.text)) {
        if (match.start == match.end) continue;
        if (wholeWord && !_isWholeWord(logicalLine.text, match)) continue;

        final startCell = logicalLine.cells.cellAt(buffer, match.start);
        final endCell = logicalLine.cells.cellAt(buffer, match.end - 1);
        if (startCell == null || endCell == null) continue;

        results.add(
          TerminalSearchMatch(
            range: BufferRangeLine(
              CellOffset(startCell.x, startCell.y),
              CellOffset(endCell.x + endCell.width, endCell.y),
            ),
            text: logicalLine.text.substring(match.start, match.end),
          ),
        );
        if (results.length >= maxResults) break;
      }
    }

    return results;
  }
}

bool _isWholeWord(String text, RegExpMatch match) {
  final before = _codePointBefore(text, match.start);
  final after = _codePointAt(text, match.end);
  return !_isWordCodePoint(before) && !_isWordCodePoint(after);
}

int? _codePointBefore(String text, int offset) {
  if (offset <= 0) return null;
  final trailing = text.codeUnitAt(offset - 1);
  if (trailing < 0xdc00 || trailing > 0xdfff || offset < 2) {
    return trailing;
  }
  final leading = text.codeUnitAt(offset - 2);
  if (leading < 0xd800 || leading > 0xdbff) return trailing;
  return 0x10000 + ((leading - 0xd800) << 10) + trailing - 0xdc00;
}

int? _codePointAt(String text, int offset) {
  if (offset >= text.length) return null;
  final leading = text.codeUnitAt(offset);
  if (leading < 0xd800 || leading > 0xdbff || offset + 1 >= text.length) {
    return leading;
  }
  final trailing = text.codeUnitAt(offset + 1);
  if (trailing < 0xdc00 || trailing > 0xdfff) return leading;
  return 0x10000 + ((leading - 0xd800) << 10) + trailing - 0xdc00;
}

bool _isWordCodePoint(int? value) {
  if (value == null) return false;

  // ASCII covers the overwhelming majority of what a terminal search runs
  // against, and every ASCII answer is decidable by range. Taking it here
  // keeps `String.fromCharCode` and a Unicode regex off the path: a
  // `wholeWord` search runs this twice per candidate match, so on output
  // where matches abut word characters it was doubling search time.
  if (value < 0x80) {
    return (value >= 0x30 && value <= 0x39) || // 0-9
        (value >= 0x41 && value <= 0x5a) || // A-Z
        (value >= 0x61 && value <= 0x7a) || // a-z
        value == 0x5f; // _
  }

  return _wordCodePoint.hasMatch(String.fromCharCode(value));
}
