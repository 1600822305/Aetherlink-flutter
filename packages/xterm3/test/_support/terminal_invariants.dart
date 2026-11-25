import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/xterm.dart';

/// Checks a set of structural invariants that must hold for [terminal] no
/// matter what byte soup it has been fed.
///
/// [random] is used to pick which line/column to sample (checking every cell
/// of every line on every call would be far too slow for a fuzz-style loop).
/// [context] is included in failure messages so a violation can be traced
/// back to the exact input that produced it.
void checkTerminalInvariants(
  Terminal terminal,
  Random random, {
  required String context,
}) {
  final buffer = terminal.buffer;

  // Cursor must always stay within the visible viewport.
  expect(
    buffer.cursorX,
    inInclusiveRange(0, terminal.viewWidth - 1),
    reason: 'cursorX escaped the viewport ($context)',
  );
  expect(
    buffer.cursorY,
    inInclusiveRange(0, terminal.viewHeight - 1),
    reason: 'cursorY escaped the viewport ($context)',
  );

  // The scrollback buffer can only grow the line count, never shrink it
  // below what's needed to fill the viewport.
  final lineCount = buffer.lines.length;
  expect(
    lineCount,
    greaterThanOrEqualTo(terminal.viewHeight),
    reason: 'line count dropped below the viewport height ($context)',
  );

  if (lineCount == 0) return;

  // Sample a single line and validate every cell's width, plus the
  // wide-char/placeholder pairing convention used by BufferLine: a width-2
  // cell at index `i` must be followed by a placeholder cell at `i + 1` with
  // width 0 and code point 0 (see Buffer.writeChar, which does
  // `line.setCell(_cursorX, codePoint, 2, ...)` followed by
  // `line.setCell(_cursorX + 1, 0, 0, ...)`).
  final lineIndex = random.nextInt(lineCount);
  final line = buffer.lines[lineIndex];

  for (var col = 0; col < line.length; col++) {
    final width = line.getWidth(col);
    expect(
      width,
      anyOf(0, 1, 2),
      reason: 'cell width outside {0, 1, 2} at line $lineIndex col $col '
          '($context)',
    );

    if (width == 2) {
      expect(
        col + 1 < line.length,
        isTrue,
        reason: 'wide cell at line $lineIndex col $col has no room for its '
            'placeholder cell ($context)',
      );
      if (col + 1 < line.length) {
        expect(
          line.getWidth(col + 1),
          0,
          reason: 'cell following wide char at line $lineIndex col $col is '
              'not a width-0 placeholder ($context)',
        );
        expect(
          line.getCodePoint(col + 1),
          0,
          reason: 'placeholder cell after wide char at line $lineIndex '
              'col $col has a non-zero code point ($context)',
        );
      }
    }
  }

  // hyperlinkIdAt must either report "no hyperlink" (0) or an id that is
  // still resolvable through the terminal's hyperlink table.
  final row = random.nextInt(lineCount);
  final column = random.nextInt(terminal.viewWidth);
  final offset = CellOffset(column, row);
  final hyperlinkId = terminal.hyperlinkIdAt(offset);
  expect(
    hyperlinkId,
    anyOf(0, predicate<int>((_) => terminal.hyperlinkAt(offset) != null)),
    reason: 'hyperlinkIdAt returned a dangling hyperlink id $hyperlinkId at '
        '($column, $row) ($context)',
  );
}
