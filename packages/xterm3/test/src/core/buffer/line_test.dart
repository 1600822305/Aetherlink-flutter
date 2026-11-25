import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:xterm3/xterm.dart';

void main() {
  group('BufferLine.getText()', () {
    test('preserves combining characters on the base cell', () {
      final terminal = Terminal();

      terminal.write('e\u0301');

      final line = terminal.buffer.lines[0];
      expect(line.getText(), 'e\u0301');
      expect(line.getCombiningCharacters(0), '\u0301');
      expect(terminal.buffer.cursorX, 1);
    });

    test('preserves zero-width joiner emoji as one terminal glyph', () {
      final terminal = Terminal();
      const family = '👨‍👩‍👧‍👦';

      terminal.write(family);

      final line = terminal.buffer.lines[0];
      expect(line.getText(), family);
      expect(line.getCombiningCharacters(0), '‍👩‍👧‍👦');
      expect(terminal.buffer.cursorX, 2);
    });

    test('preserves emoji modifiers and regional indicator pairs', () {
      final terminal = Terminal();

      terminal.write('👍🏽🇻🇳🇺');

      final line = terminal.buffer.lines[0];
      expect(line.getText(), '👍🏽🇻🇳🇺');
      expect(line.getCombiningCharacters(0), '🏽');
      expect(line.getCombiningCharacters(2), '🇳');
      expect(line.getWidth(2), 2);
      expect(line.getWidth(3), 0);
      expect(terminal.buffer.cursorX, 5);
    });

    test('bounds combining characters per cell', () {
      final terminal = Terminal();

      terminal.write('e${'\u0301' * 20}');

      final combining = terminal.buffer.lines[0].getCombiningCharacters(0);
      expect(combining?.runes.length, 16);
    });

    test('should return the text', () {
      final terminal = Terminal();
      terminal.write('Hello World');
      expect(terminal.buffer.lines[0].getText(), 'Hello World');
    });

    test('getText() should support wide characters', () {
      final text = '😀😁😂🤣😃';
      final terminal = Terminal();
      terminal.write(text);
      expect(terminal.buffer.lines[0].getText(), equals(text));
    });

    test('can specify a range', () {
      final terminal = Terminal();
      terminal.write('Hello World');
      expect(terminal.buffer.lines[0].getText(0, 5), 'Hello');
    });

    test('can handle invalid ranges', () {
      final terminal = Terminal();
      terminal.write('Hello World');
      expect(terminal.buffer.lines[0].getText(0, 100), 'Hello World');
    });

    test('can handle negative ranges', () {
      final terminal = Terminal();
      terminal.write('Hello World');
      expect(terminal.buffer.lines[0].getText(-100, 100), 'Hello World');
    });

    test('can handle reversed ranges', () {
      final terminal = Terminal();
      terminal.write('Hello World');
      expect(terminal.buffer.lines[0].getText(5, 0), '');
    });
  });

  group('BufferLine.getTrimmedLength()', () {
    test('can get trimmed length', () {
      final line = BufferLine(10);

      final text = 'ABCDEF';

      for (var i = 0; i < text.length; i++) {
        line.setCodePoint(i, text.codeUnitAt(i));
      }

      expect(line.getTrimmedLength(), equals(text.length));
    });

    test('can get trimmed length with wide characters', () {
      final terminal = Terminal();
      final text = '😀😁😂🤣😃';

      terminal.write(text);

      expect(terminal.buffer.lines[0].getTrimmedLength(), equals(text.length));
    });

    test('can handle length larger than the line', () {
      final line = BufferLine(10);

      final text = 'ABCDEF';

      for (var i = 0; i < text.length; i++) {
        line.setCodePoint(i, text.codeUnitAt(i));
      }

      expect(line.getTrimmedLength(1000), equals(text.length));
    });

    test('ignores stale cells left behind by a shrinking resize', () {
      final line = BufferLine(10);

      final text = 'ABCDEF';
      for (var i = 0; i < text.length; i++) {
        line.setCodePoint(i, text.codeUnitAt(i));
      }

      // resize() shrinking a line keeps the cell data beyond the new length
      // around (it's revived if the line grows back). getTrimmedLength()
      // must not report those stale cells as content.
      line.resize(3);

      expect(line.getTrimmedLength(), equals(3));
    });

    test('can handle negative start', () {
      final line = BufferLine(10);

      final text = 'ABCDEF';

      for (var i = 0; i < text.length; i++) {
        line.setCodePoint(i, text.codeUnitAt(i));
      }

      expect(line.getTrimmedLength(-1000), equals(0));
    });
  });

  group('BufferLine.eraseRange()', () {
    test('clears the placeholder half of a wide char cut at the boundary', () {
      final line = BufferLine(6);
      final wideStyle = CursorStyle(background: 42);
      // Wide char lead at 2 (width 2), placeholder at 3 (width 0) - mirrors
      // what a real write leaves behind, including on the placeholder cell.
      line.setCell(2, 0x1F600, 2, wideStyle);
      line.setCell(3, 0, 0, wideStyle);

      // end == 3 lands exactly on the placeholder: the lead at end - 1 is
      // inside the erased range and gets cleared, so the placeholder must
      // be cleared too or it's left behind as an orphan still carrying the
      // wide char's background.
      line.eraseRange(0, 3, CursorStyle());

      expect(line.getWidth(3), 0);
      expect(line.getBackground(3), 0,
          reason: 'placeholder must not keep the erased lead\'s background');
    });

    test(
        'leaves an intact wide pair alone on an empty range at its '
        'placeholder', () {
      final line = BufferLine(6);
      final wideStyle = CursorStyle(background: 42);
      line.setCell(2, 0x1F600, 2, wideStyle);
      line.setCell(3, 0, 0, wideStyle);

      // start == end == 3: nothing in [start, end) so the lead at 2 is
      // never touched - the placeholder at 3 must be left alone too,
      // or the lead is left dangling with no placeholder.
      line.eraseRange(3, 3, CursorStyle());

      expect(line.getWidth(2), 2, reason: 'lead must still be intact');
      expect(line.getBackground(3), 42,
          reason: 'placeholder must not be erased when its lead was not');
    });
  });

  group('BufferLine erasing cells nothing was written to', () {
    test('allocates no storage for the default background', () {
      final line = BufferLine(170);
      line.eraseRange(0, 170, CursorStyle());
      // ignore: deprecated_member_use, invalid_use_of_visible_for_testing_member
      expect(line.data, isEmpty);

      line.setAsciiCells(0, 'hello', 0, 5, CursorStyle());
      line.eraseRange(5, 170, CursorStyle());
      // ignore: deprecated_member_use, invalid_use_of_visible_for_testing_member
      expect(line.data.length, 64 * 4, reason: 'still the first-write store');
      expect(line.getText(), 'hello');
      expect(line.writtenLength, 5);
    });

    test('still fills to the end with a background colour', () {
      final line = BufferLine(170);
      line.setAsciiCells(0, 'hello', 0, 5, CursorStyle());
      line.eraseRange(5, 170, CursorStyle(background: 42));

      expect(line.getBackground(5), 42);
      expect(line.getBackground(169), 42);
      expect(line.writtenLength, 170);

      // And a default erase afterwards has to take that colour away again.
      line.eraseRange(3, 170, CursorStyle());
      expect(line.getBackground(5), 0);
      expect(line.getBackground(169), 0);
      expect(line.getText(), 'hel');
      expect(line.writtenLength, 3);
    });

    test('clears what was written past an earlier erase', () {
      final line = BufferLine(80);
      line.setAsciiCells(0, 'abcdef', 0, 6, CursorStyle());
      line.eraseRange(2, 80, CursorStyle());
      line.setCell(40, 0x78, 1, CursorStyle(foreground: 7));
      expect(line.writtenLength, 41);

      line.eraseRange(0, 80, CursorStyle());
      expect(line.getCodePoint(40), 0);
      expect(line.getForeground(40), 0);
      expect(line.getText(), '');
      expect(line.writtenLength, 0);
    });

    test('leaves protected cells and the written extent alone', () {
      final line = BufferLine(20);
      line.setCell(10, 0x78, 1, CursorStyle(attrs: CellAttr.protected));
      line.eraseRange(0, 20, CursorStyle(), respectProtected: true);

      expect(line.getCodePoint(10), 0x78);
      expect(line.writtenLength, 11);
    });
  });

  group('BufferLine.resize', () {
    test('can resize', () {
      final line = BufferLine(10);

      final text = 'ABCDEF';

      for (var i = 0; i < text.length; i++) {
        line.setCodePoint(i, text.codeUnitAt(i));
      }

      line.resize(20);

      expect(line.length, equals(20));
    });

    test('preserves hidden combining characters across shrink and grow', () {
      final line = BufferLine(10);
      line.setCodePoint(5, 'e'.codeUnitAt(0));
      line.addCombiningCharacter(5, 0x0301);

      line.resize(3);
      line.resize(10);

      expect(line.getCombiningCharacters(5), '\u0301');
      expect(line.getText(), '     e\u0301');
    });
  });

  group('BufferLine combining character mutations', () {
    test('moves combining characters when cells are inserted and removed', () {
      final terminal = Terminal();
      terminal.write('e\u0301b');
      final line = terminal.buffer.lines[0];

      line.insertCells(0, 1);
      expect(line.getCombiningCharacters(1), '\u0301');
      expect(line.getText(), ' e\u0301b');

      line.removeCells(0, 1);
      expect(line.getCombiningCharacters(0), '\u0301');
      expect(line.getText(), 'e\u0301b');
    });

    test('clears combining characters when a cell is erased', () {
      final terminal = Terminal();
      terminal.write('e\u0301');
      final line = terminal.buffer.lines[0];

      line.eraseCell(0, CursorStyle.empty);

      expect(line.getCombiningCharacters(0), isNull);
    });
  });

  test('zero-count cell edits preserve content and metadata', () {
    final terminal = Terminal()..resize(5, 1);
    terminal.write('\x1b[58;2;1;2;3me\u0301好');
    final line = terminal.buffer.lines[0];
    final anchor = line.createAnchor(2);
    final before = Uint32List.fromList(line.data);

    line.insertCells(1, 0, CursorStyle.empty, 3);
    line.removeCells(1, 0, CursorStyle.empty, 3);

    expect(line.data, orderedEquals(before));
    expect(line.getCombiningCharacters(0), '\u0301');
    expect(line.getUnderlineColor(0), isNot(0));
    expect(anchor.attached, isTrue);
    expect(anchor.x, 2);
  });

  test('ASCII cell runs clear split wide cells and stale metadata', () {
    final terminal = Terminal()..resize(6, 1);
    terminal.write('\x1b[58;2;1;2;3me\u0301好Z');
    final line = terminal.buffer.lines[0];

    line.setAsciiCells(1, 'abc', 0, 3, CursorStyle.empty);

    expect(line.getText(), 'e\u0301abc');
    expect(line.getWidth(0), 1);
    expect(line.getWidth(1), 1);
    expect(line.getWidth(2), 1);
    expect(line.getWidth(3), 1);
    expect(line.getCombiningCharacters(1), isNull);
    expect(line.getUnderlineColor(1), 0);
    expect(line.getUnderlineColor(2), 0);
    expect(line.getUnderlineColor(3), 0);
  });

  test('semantic content and hyperlink identifiers occupy distinct bits', () {
    final line = BufferLine(1);
    final style = CursorStyle(
      hyperlinkId: 4096,
      semanticAttrs: CellAttr.semanticPrompt,
    );

    line.setCell(0, 0x41, 1, style);

    expect(line.getHyperlinkId(0), 4096);
    expect(line.getSemanticContent(0), CellAttr.semanticPrompt);
  });

  group('BufferLine anchors', () {
    test('move with content shifted by inserted cells', () {
      final terminal = Terminal()..resize(5, 1);
      terminal.write('abcde');
      final line = terminal.buffer.lines[0];
      final startAnchor = line.createAnchor(0);
      final middleAnchor = line.createAnchor(2);
      final droppedAnchor = line.createAnchor(4);

      line.insertCells(0, 1);

      expect(line.getText(), ' abcd');
      expect(startAnchor.attached, isTrue);
      expect(startAnchor.x, 1);
      expect(middleAnchor.attached, isTrue);
      expect(middleAnchor.x, 3);
      expect(droppedAnchor.attached, isFalse);
    });

    test('detach every anchor in content dropped by inserted cells', () {
      final terminal = Terminal()..resize(5, 1);
      terminal.write('abcde');
      final line = terminal.buffer.lines[0];
      final firstDroppedAnchor = line.createAnchor(3);
      final secondDroppedAnchor = line.createAnchor(4);

      line.insertCells(0, 2);

      expect(firstDroppedAnchor.attached, isFalse);
      expect(secondDroppedAnchor.attached, isFalse);
    });

    test('detach every anchor in removed cells', () {
      final terminal = Terminal()..resize(5, 1);
      terminal.write('abcde');
      final line = terminal.buffer.lines[0];
      final firstRemovedAnchor = line.createAnchor(1);
      final secondRemovedAnchor = line.createAnchor(2);
      final shiftedAnchor = line.createAnchor(3);

      line.removeCells(1, 2);

      expect(firstRemovedAnchor.attached, isFalse);
      expect(secondRemovedAnchor.attached, isFalse);
      expect(shiftedAnchor.attached, isTrue);
      expect(shiftedAnchor.x, 1);
    });
  });

  group('Buffer.createAnchor', () {
    test('works', () {
      final terminal = Terminal();
      final line = terminal.buffer.lines[3];
      final anchor = line.createAnchor(5);

      terminal.insertLines(5);
      expect(anchor.x, 5);
      expect(anchor.y, 8);

      terminal.buffer.clear();
      expect(line.attached, false);
      expect(anchor.attached, false);
    });
  });

  test('BufferLine.dispose detaches every anchor', () {
    final line = BufferLine(10);
    final anchors = [line.createAnchor(1), line.createAnchor(2)];

    line.dispose();

    expect(anchors.every((anchor) => anchor.line == null), isTrue);
    expect(line.anchors, isEmpty);
  });

  test('BufferLine keeps existing anchor list views live', () {
    final line = BufferLine(10);
    final anchors = line.anchors;

    final anchor = line.createAnchor(2);

    expect(anchors, [anchor]);
  });

  test('createCellData returns a non-destructive cell snapshot', () {
    final line = BufferLine(2);
    final style = CursorStyle()
      ..foreground = 0x123
      ..background = 0x456
      ..underlineColor = 0x789
      ..setBold();
    line.setCell(0, 0x41, 1, style);

    final cell = line.createCellData(0);

    expect(cell.foreground, 0x123);
    expect(cell.background, 0x456);
    expect(cell.underlineColor, 0x789);
    expect(cell.flags & CellAttr.bold, isNot(0));
    expect(cell.content & CellContent.codepointMask, 0x41);
    expect(line.getCodePoint(0), 0x41);
  });

  test('hasAnchors answers without building the anchors view', () {
    final line = BufferLine(10);
    expect(line.hasAnchors, isFalse);

    final anchor = line.createAnchor(2);
    expect(line.hasAnchors, isTrue);
    expect(line.anchors, hasLength(1));

    anchor.dispose();
    expect(line.hasAnchors, isFalse);
    expect(line.anchors, isEmpty);
  });
}
