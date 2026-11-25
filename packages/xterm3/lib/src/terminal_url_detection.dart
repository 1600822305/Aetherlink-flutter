import 'package:xterm3/src/core/buffer/cell_offset.dart';
import 'package:xterm3/src/core/buffer/range_line.dart';
import 'package:xterm3/src/terminal.dart';
import 'package:xterm3/src/terminal_logical_line.dart';
import 'package:xterm3/src/terminal_search.dart';

/// Matches `http(s)://` and bare `www.` URLs in plain terminal output (as
/// opposed to OSC 8 hyperlinks, which carry their own explicit URI and are
/// matched via [Terminal.hyperlinkAt]).
final _urlPattern = RegExp(
  r'(https?://|www\.)[^\s<>\x22\x27`]+',
  caseSensitive: false,
);

/// Trailing characters that are almost never intentionally part of a URL
/// when they terminate a run of non-whitespace, such as the closing
/// punctuation of a sentence or a wrapping bracket.
const _trimmableTrailing = '.,;:!?\'"`*_~';

/// Plain-text URL detection support, distinct from OSC 8 hyperlinks.
extension TerminalUrlDetection on Terminal {
  /// Returns the URL at [position], if any, along with the cell range it
  /// occupies. Returns null if [position] is not inside a detected URL.
  TerminalSearchMatch? urlAt(CellOffset position) {
    final buffer = this.buffer;
    if (position.y < 0 || position.y >= buffer.lines.length) return null;

    final firstLineIndex = logicalLineStart(buffer, position.y);
    final textBuffer = StringBuffer();
    final cells = LogicalLineCells();
    final logicalLine = buildLogicalLine(
      buffer,
      firstLineIndex,
      textBuffer,
      cells,
    );
    if (logicalLine.text.isEmpty) return null;

    final textOffset = cells.textOffsetFor(position.x, position.y);
    if (textOffset == null) return null;

    for (final match in _urlPattern.allMatches(logicalLine.text)) {
      if (textOffset < match.start || textOffset >= match.end) continue;

      final trimmedEnd = _trimTrailingPunctuation(
        logicalLine.text,
        match.start,
        match.end,
      );
      if (textOffset >= trimmedEnd) return null;

      final startCell = cells.cellAt(buffer, match.start);
      final endCell = cells.cellAt(buffer, trimmedEnd - 1);
      if (startCell == null || endCell == null) return null;

      return TerminalSearchMatch(
        range: BufferRangeLine(
          CellOffset(startCell.x, startCell.y),
          CellOffset(endCell.x + endCell.width, endCell.y),
        ),
        text: logicalLine.text.substring(match.start, trimmedEnd),
      );
    }

    return null;
  }
}

int _trimTrailingPunctuation(String text, int start, int end) {
  var trimmedEnd = end;
  while (
      trimmedEnd > start && _trimmableTrailing.contains(text[trimmedEnd - 1])) {
    trimmedEnd--;
  }
  // A trailing ')' is kept when it closes an earlier '(' inside the match
  // (e.g. a wiki URL like `.../Foo_(bar)`), and trimmed otherwise (e.g. a
  // URL wrapped in parentheses by the surrounding prose).
  while (trimmedEnd > start && text[trimmedEnd - 1] == ')') {
    // Scan everything before this candidate ')' — excluding itself — for an
    // '(' that it would balance.
    var unclosedOpens = 0;
    for (var i = start; i < trimmedEnd - 1; i++) {
      if (text[i] == '(') unclosedOpens++;
      if (text[i] == ')') unclosedOpens--;
    }
    if (unclosedOpens > 0) break;
    trimmedEnd--;
  }
  return trimmedEnd;
}
