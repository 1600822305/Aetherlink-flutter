import 'dart:typed_data';

import 'package:xterm3/src/core/buffer/buffer.dart';
import 'package:xterm3/src/core/buffer/line.dart';

/// A logical (soft-wrap joined) line of terminal text, with a mapping back
/// to the cells that produced each character. Shared by [terminal_search]
/// and [terminal_url_detection], which both need to run a [RegExp] over
/// buffer text and map matches back to cell ranges.
final class LogicalLine {
  const LogicalLine({
    required this.text,
    required this.cells,
    required this.nextLineIndex,
  });

  final String text;
  final LogicalLineCells cells;
  final int nextLineIndex;
}

final class LogicalLineCell {
  const LogicalLineCell({
    required this.x,
    required this.y,
    required this.width,
  });

  final int x;
  final int y;
  final int width;
}

final class LogicalLineCells {
  var _textStarts = Int32List(256);
  var _columns = Int32List(256);
  var _lines = Int32List(256);
  var length = 0;

  bool get isEmpty => length == 0;

  void clear() {
    length = 0;
  }

  void add({
    required int textStart,
    required int column,
    required int line,
  }) {
    if (length == _textStarts.length) {
      final nextLength = _textStarts.length * 2;
      _textStarts = _grow(_textStarts, nextLength);
      _columns = _grow(_columns, nextLength);
      _lines = _grow(_lines, nextLength);
    }
    _textStarts[length] = textStart;
    _columns[length] = column;
    _lines[length] = line;
    length++;
  }

  /// Returns the cell that produced the character at [textOffset].
  LogicalLineCell? cellAt(Buffer buffer, int textOffset) {
    var low = 0;
    var high = length - 1;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      if (_textStarts[middle] <= textOffset) {
        low = middle + 1;
        continue;
      }
      high = middle - 1;
    }
    if (high < 0) return null;

    final x = _columns[high];
    final y = _lines[high];
    final width = buffer.lines[y].getWidth(x);
    return LogicalLineCell(
      x: x,
      y: y,
      width: switch (width) {
        0 => 1,
        _ => width,
      },
    );
  }

  /// Returns the text offset of the character produced by cell ([x], [y]).
  int? textOffsetFor(int x, int y) {
    for (var i = 0; i < length; i++) {
      if (_columns[i] == x && _lines[i] == y) {
        return _textStarts[i];
      }
    }
    return null;
  }

  Int32List _grow(Int32List source, int length) {
    final result = Int32List(length);
    result.setRange(0, source.length, source);
    return result;
  }
}

/// Finds the first physical row of the logical (soft-wrap joined) line that
/// contains row [y].
int logicalLineStart(Buffer buffer, int y) {
  var start = y;
  while (start > 0 && buffer.lines[start].isWrapped) {
    start--;
  }
  return start;
}

/// Builds the logical line starting at physical row [firstLineIndex],
/// joining any soft-wrapped continuation rows into a single string.
LogicalLine buildLogicalLine(
  Buffer buffer,
  int firstLineIndex,
  StringBuffer text,
  LogicalLineCells cells,
) {
  text.clear();
  cells.clear();
  var lineIndex = firstLineIndex;

  while (lineIndex < buffer.lines.length) {
    final line = buffer.lines[lineIndex];
    final nextLineIndex = lineIndex + 1;
    final continuesToNext = nextLineIndex < buffer.lines.length &&
        buffer.lines[nextLineIndex].isWrapped;
    _appendLogicalLineText(
      text,
      cells,
      line,
      lineIndex,
      includeFullWidth: continuesToNext,
      skipWideCharPadding: continuesToNext &&
          _endsWithWideCharPadding(line, buffer.viewWidth) &&
          buffer.lines[nextLineIndex].getWidth(0) == 2,
      viewWidth: buffer.viewWidth,
    );
    lineIndex = nextLineIndex;
    if (!continuesToNext) break;
  }

  return LogicalLine(
    text: text.toString(),
    cells: cells,
    nextLineIndex: lineIndex,
  );
}

/// Whether the last cell of [line] is the empty cell left behind when a wide
/// character did not fit at the end of the row and wrapped to the next one.
bool _endsWithWideCharPadding(BufferLine line, int viewWidth) {
  final last = viewWidth - 1;
  if (last < 1) return false;
  return line.getCodePoint(last) == 0 && line.getWidth(last - 1) != 2;
}

void _appendLogicalLineText(
  StringBuffer text,
  LogicalLineCells cells,
  BufferLine line,
  int lineIndex, {
  required bool includeFullWidth,
  required bool skipWideCharPadding,
  required int viewWidth,
}) {
  final end = switch (includeFullWidth) {
    true => skipWideCharPadding ? viewWidth - 1 : viewWidth,
    false => line.getTrimmedLength(viewWidth),
  };
  for (var column = 0; column < end; column++) {
    final codePoint = line.getCodePoint(column);
    final width = line.getWidth(column);
    final isWideSpacer =
        width == 0 && column > 0 && line.getWidth(column - 1) == 2;
    if (isWideSpacer) continue;

    final textStart = text.length;
    text.writeCharCode(switch (codePoint) {
      0 => 0x20,
      _ => codePoint,
    });
    final combiningCharacters = line.getCombiningCharacters(column);
    if (combiningCharacters != null) {
      text.write(combiningCharacters);
    }
    cells.add(
      textStart: textStart,
      column: column,
      line: lineIndex,
    );
  }
}
