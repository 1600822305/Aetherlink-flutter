import 'dart:math';

import 'package:test/test.dart';
import 'package:xterm3/xterm.dart';

String row(Terminal t, int y) => t.buffer.lines[y].toString().trimRight();

void main() {
  group('reflow keeps the cursor when content exactly fills the width', () {
    test('cursor follows text that now fills one row', () {
      final t = Terminal(maxLines: 100);
      t.resize(5, 4);
      t.write('abcdefgh');
      t.resize(8, 4);

      expect(row(t, 0), 'abcdefgh');
      expect(t.buffer.cursorY, 0);

      t.write('Z');
      expect(row(t, 0), 'abcdefgh');
      expect(row(t, 1), 'Z');
      expect(t.buffer.lines[1].isWrapped, isTrue);
    });

    test('next write does not overwrite the last character', () {
      final t = Terminal(maxLines: 100);
      t.resize(20, 4);
      t.write('abcdefgh');
      t.resize(8, 4);
      t.write('Z');

      expect(row(t, 0), 'abcdefgh');
      expect(row(t, 1), 'Z');
    });

    test('shrinking to an exact fill keeps the cursor after the text', () {
      final t = Terminal(maxLines: 100);
      t.resize(10, 4);
      t.write('abcdefgh');
      t.resize(4, 4);
      t.write('Z');

      expect(t.buffer.getText().trimRight(), 'abcdefghZ');
      expect(row(t, 2), 'Z');
    });

    test('a later height shrink does not drop the text', () {
      final t = Terminal(maxLines: 100);
      t.resize(5, 4);
      t.write('abcdefgh');
      t.resize(8, 4);
      t.resize(8, 1);

      expect(t.buffer.lines[t.buffer.absoluteCursorY].toString(), 'abcdefgh');
      expect(t.buffer.getText().trimRight(), 'abcdefgh');
    });

    test('random resizes preserve text and the logical cursor offset', () {
      final random = Random(42);
      for (var round = 0; round < 500; round++) {
        // Text below the cursor is dropped by a height shrink (as in
        // xterm.js), so rounds that move the cursor into the text keep a
        // screen tall enough for all of it.
        final moveBack = random.nextBool();
        int nextHeight() => moveBack ? 50 : 1 + random.nextInt(6);

        final width = 1 + random.nextInt(12);
        final t = Terminal(maxLines: 100);
        t.resize(width, nextHeight());

        final length = 1 + random.nextInt(40);
        final text = String.fromCharCodes(
          List.generate(length, (_) => 0x20 + random.nextInt(95)),
        );
        t.write(text);

        // Move the cursor back within its row; CUB first cancels a pending
        // wrap, so the logical offset is length - back either way.
        final rowColumn = length % width == 0 ? width : length % width;
        final back = moveBack ? random.nextInt(rowColumn + 1) : 0;
        if (back > 0) t.write('\x1b[${back}D');
        final offset = length - back;

        final steps = <String>[];
        for (var i = 0; i < 1 + random.nextInt(6); i++) {
          final newWidth = random.nextBool()
              ? 1 + random.nextInt(12)
              // Exact multiples of the cursor offset hit the exact-fill path.
              : max(1, offset ~/ (1 + random.nextInt(4)));
          final newHeight = nextHeight();
          steps.add('${newWidth}x$newHeight');
          t.resize(newWidth, newHeight);
          expect(
            t.buffer.getText().trimRight(),
            text.trimRight(),
            reason: 'round $round w$width "$text" back $back steps $steps',
          );
        }

        t.write('█');
        final expected = offset == length
            ? '$text█'
            : text.replaceRange(offset, offset + 1, '█');
        expect(
          t.buffer.getText().trimRight(),
          expected.trimRight(),
          reason: 'round $round w$width "$text" back $back steps $steps',
        );
      }
    });
  });

  group('EL keeps isWrapped unless the erase starts at column 0', () {
    test('EL 0 mid-row keeps the row a continuation', () {
      final t = Terminal(maxLines: 100);
      t.resize(10, 5);
      t.write('0123456789ABCDE\x1b[K');

      expect(t.buffer.lines[1].isWrapped, isTrue);
      expect(t.buffer.getText().trimRight(), '0123456789ABCDE');

      t.resize(20, 5);
      expect(row(t, 0), '0123456789ABCDE');
    });

    test('EL 0 at column 0 clears the flag', () {
      final t = Terminal(maxLines: 100);
      t.resize(10, 5);
      t.write('0123456789ABCDE\r\x1b[K');

      expect(t.buffer.lines[1].isWrapped, isFalse);
    });

    test('EL 1 keeps the flag, EL 2 clears it', () {
      final t = Terminal(maxLines: 100);
      t.resize(10, 5);
      t.write('0123456789ABCDE\x1b[1K');
      expect(t.buffer.lines[1].isWrapped, isTrue);

      t.write('\x1b[2K');
      expect(t.buffer.lines[1].isWrapped, isFalse);
    });

    test('ED 0 mid-row keeps the flag, ED 1 clears it', () {
      final t = Terminal(maxLines: 100);
      t.resize(10, 5);
      t.write('0123456789ABCDE\x1b[J');
      expect(t.buffer.lines[1].isWrapped, isTrue);

      t.write('\x1b[1J');
      expect(t.buffer.lines[1].isWrapped, isFalse);
    });
  });

  group('erased text does not reappear after shrink and widen', () {
    test('main buffer', () {
      final t = Terminal(maxLines: 100);
      t.resize(20, 6);
      t.write('\r\n\r\nABCDEFGHIJKLMNOPQRS');
      t.resize(10, 6);
      t.write('\x1b[H\x1b[J> ');
      t.resize(20, 6);

      final top = t.buffer.scrollBack;
      expect(row(t, top), '>');
      for (var y = top + 1; y < t.buffer.height; y++) {
        expect(row(t, y), isEmpty, reason: 'row $y');
      }
    });

    test('cells moved by reflow do not linger in the hidden tail', () {
      final t = Terminal(maxLines: 100);
      t.resize(20, 4);
      t.write('ABCDEFGHIJKLMNOPQRS');
      t.resize(10, 4);
      t.write('\rxyz\x1b[K');
      t.resize(20, 4);

      expect(t.buffer.getText().trimRight(), 'ABCDEFGHIJxyz');
    });

    test('alt buffer', () {
      final t = Terminal(maxLines: 100);
      t.resize(20, 4);
      t.write('\x1b[?1049hABCDEFGHIJKLMNOPQRS');
      t.resize(10, 4);
      t.write('\x1b[H\x1b[2Jhi');
      t.resize(20, 4);

      expect(row(t, 0), 'hi');
    });

    test('EL 0 to the end of the row also clears hidden cells', () {
      final t = Terminal(maxLines: 100, reflowEnabled: false);
      t.resize(20, 4);
      t.write('ABCDEFGHIJKLMNOPQRS');
      t.resize(10, 4);
      t.write('\x1b[1;4H\x1b[K');
      t.resize(20, 4);

      expect(row(t, 0), 'ABC');
    });

    test('DCH and ICH at the right edge clear hidden cells', () {
      final t = Terminal(maxLines: 100, reflowEnabled: false);
      t.resize(20, 4);
      t.write('ABCDEFGHIJKLMNOPQRS\r\nABCDEFGHIJKLMNOPQRS');
      t.resize(10, 4);
      t.write('\x1b[1;1H\x1b[P\x1b[2;1H\x1b[@');
      t.resize(20, 4);

      expect(row(t, 0), 'BCDEFGHIJ');
      expect(row(t, 1), ' ABCDEFGHI');
    });

    test('DECCOLM clears hidden cells', () {
      final t = Terminal(maxLines: 100, reflowEnabled: false);
      t.resize(20, 4);
      t.write('ABCDEFGHIJKLMNOPQRS');
      t.resize(10, 4);
      t.write('\x1b[?40h\x1b[?3h');
      t.resize(20, 4);

      expect(row(t, 0), isEmpty);
    });

    test('hidden cells still come back when nothing erased them', () {
      final t = Terminal(maxLines: 100, reflowEnabled: false);
      t.write('Hello World');
      t.resize(5, 5);
      t.resize(20, 5);

      expect(row(t, 0), 'Hello World');
    });
  });

  group('getText keeps blank cells inside the row', () {
    test('erased cell between words becomes a space', () {
      final t = Terminal(maxLines: 100);
      t.write('hello world\r\x1b[5C\x1b[1X');

      expect(t.buffer.getText().trimRight(), 'hello world');
    });

    test('skipped cells become spaces', () {
      final t = Terminal(maxLines: 100);
      t.write('a\x1b[5Cb');

      expect(t.buffer.getText().trimRight(), 'a     b');
      expect(t.buffer.lines[0].toString(), 'a     b');
    });

    test('wide characters gain no space and trailing blanks are trimmed', () {
      final t = Terminal(maxLines: 100);
      t.write('界\x1b[2C界');

      expect(t.buffer.lines[0].toString(), '界  界');
    });
  });

  group('scroll region starting at the top feeds scrollback', () {
    test('status line stays put and scrolled lines go to scrollback', () {
      final t = Terminal(maxLines: 100);
      t.resize(10, 5);
      t.write('\x1b[1;4r\x1b[5;1Hstatus\x1b[1;1H');
      for (var i = 0; i < 12; i++) {
        t.write('line$i\r\n');
      }

      expect(t.buffer.scrollBack, 9);
      for (var i = 0; i < 9; i++) {
        expect(row(t, i), 'line$i');
      }
      final top = t.buffer.scrollBack;
      expect(row(t, top + 0), 'line9');
      expect(row(t, top + 1), 'line10');
      expect(row(t, top + 2), 'line11');
      expect(row(t, top + 3), isEmpty);
      expect(row(t, top + 4), 'status');
    });

    test('maxLines still trims the oldest lines', () {
      // maxLines is at least the initial 24-row height of a Terminal.
      final t = Terminal(maxLines: 30);
      t.resize(10, 5);
      t.write('\x1b[1;4r\x1b[5;1Hstatus\x1b[1;1H');
      for (var i = 0; i < 40; i++) {
        t.write('line$i\r\n');
      }

      expect(t.buffer.height, 30);
      expect(row(t, 0), 'line12');
      expect(row(t, 29), 'status');
    });

    test('alt buffer and regions below the top keep discarding', () {
      final alt = Terminal(maxLines: 100);
      alt.resize(10, 5);
      alt.write('\x1b[?1049h\x1b[1;4r\x1b[1;1H');
      for (var i = 0; i < 12; i++) {
        alt.write('line$i\r\n');
      }
      expect(alt.buffer.scrollBack, 0);

      final main = Terminal(maxLines: 100);
      main.resize(10, 5);
      main.write('\x1b[2;4r\x1b[2;1H');
      for (var i = 0; i < 12; i++) {
        main.write('line$i\r\n');
      }
      expect(main.buffer.scrollBack, 0);
    });
  });

  group('BufferRangeBlock dragged from top-right to bottom-left', () {
    test('yields segments and contains inner cells', () {
      final range = BufferRangeBlock(CellOffset(5, 2), CellOffset(3, 4));
      final segments = range.toSegments().toList();

      expect(segments, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(segments[i].line, 2 + i);
        expect(segments[i].start, 3);
        expect(segments[i].end, 5);
      }
      expect(range.contains(CellOffset(4, 3)), isTrue);
      expect(range.contains(CellOffset(6, 3)), isFalse);
    });
  });

  test('saved cursor follows a height shrink and regrow', () {
    final t = Terminal(maxLines: 100);
    t.resize(10, 5);
    t.write('\x1b[3;1H\x1b7\x1b[5;1H');
    t.resize(10, 3);
    t.resize(10, 5);
    t.write('\x1b8');

    expect(t.buffer.cursorY, 2);
  });
}
