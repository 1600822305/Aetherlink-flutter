import 'package:test/test.dart';
import 'package:xterm3/xterm.dart';

void main() {
  group('remote resize', () {
    const sequences = {
      'CSI 8 t': '\x1b[8;1;1t',
      'CSI Ps t (DECSLPP)': '\x1b[30t',
      'DECSCPP': '\x1b[100\$|',
      'DECSNLS': '\x1b[36*|',
    };

    for (final entry in sequences.entries) {
      test('${entry.key} is ignored by default', () {
        final resizes = <(int, int)>[];
        final terminal =
            Terminal(onResize: (w, h, _, __) => resizes.add((w, h)))
              ..resize(80, 24);
        resizes.clear();

        terminal.write(entry.value);

        expect((terminal.viewWidth, terminal.viewHeight), (80, 24));
        expect(resizes, isEmpty);
      });
    }

    test('works when opted in', () {
      final terminal = Terminal(allowRemoteResize: true)..resize(80, 24);

      terminal.write('\x1b[8;10;20t');
      expect((terminal.viewWidth, terminal.viewHeight), (20, 10));

      terminal.write('\x1b[100\$|\x1b[36*|');
      expect((terminal.viewWidth, terminal.viewHeight), (100, 36));

      terminal.write('\x1b[30t');
      expect(terminal.viewHeight, 30);
    });

    test('is clamped when opted in', () {
      final terminal = Terminal(allowRemoteResize: true)..resize(80, 24);

      terminal.write('\x1b[8;5000;4000t');
      expect((terminal.viewWidth, terminal.viewHeight), (1000, 1000));

      terminal.write('\x1b[8;0;0t');
      expect((terminal.viewWidth, terminal.viewHeight), (1, 1));

      terminal.write('\x1b[4000\$|\x1b[3000*|');
      expect((terminal.viewWidth, terminal.viewHeight), (1000, 1000));
    });

    test('embedder resize stays unrestricted', () {
      final terminal = Terminal()..resize(1200, 1100);
      expect((terminal.viewWidth, terminal.viewHeight), (1200, 1100));
    });
  });

  test('REP is bounded by the screen size', () {
    final terminal = Terminal()..resize(10, 5);

    terminal.write('a\x1b[100000b');

    // 1 + 50 characters: a full screen plus one wrapped character.
    expect(terminal.buffer.height, 6);
    expect(terminal.buffer.lines[4].getText(), 'aaaaaaaaaa');
    expect(terminal.buffer.lines[5].getText(), 'a');
  });

  test('REP repeats up to a screenful', () {
    final terminal = Terminal()..resize(10, 5);
    terminal.write('a\x1b[12b');
    expect(terminal.buffer.lines[0].getText(), 'aaaaaaaaaa');
    expect(terminal.buffer.lines[1].getText(), 'aaa');
  });

  test('CSI 21 t never echoes the window title', () {
    final output = <String>[];
    final terminal = Terminal(onOutput: output.add);

    terminal.write('\x1b]2;rm -rf ~ #\x07\x1b[21t');

    expect(output, ['\x1b]l\x1b\\']);
  });

  group('DECAUPSS', () {
    String reportAfter(String assignment) {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      terminal.write('$assignment\x1b[&u');
      return output.single;
    }

    test('ignores designators with control characters', () {
      expect(reportAfter('\x1bP0!u\r\r\x1b\\'), '\x1bP0!u%5\x1b\\');
    });

    test('ignores designators with an invalid shape', () {
      expect(reportAfter('\x1bP0!uA%\x1b\\'), '\x1bP0!u%5\x1b\\');
      expect(reportAfter('\x1bP0!u\x7f\x1b\\'), '\x1bP0!u%5\x1b\\');
    });

    test('accepts valid designators', () {
      expect(reportAfter('\x1bP1!uA\x1b\\'), '\x1bP1!uA\x1b\\');
      expect(reportAfter('\x1bP0!u%6\x1b\\'), '\x1bP0!u%6\x1b\\');
    });
  });

  group('write does not throw on malformed input', () {
    test('OSC 133 with invalid cmdline_url encoding', () {
      expect(
        () => Terminal().write('\x1b]133;A;cmdline_url=%ZZ\x07'),
        returnsNormally,
      );
      expect(
        () => Terminal().write('\x1b]133;C;cmdline_url=ls%\x07'),
        returnsNormally,
      );
    });

    test('XTGETTCAP with a signed hex byte', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);
      expect(() => terminal.write('\x1bP+q-1\x1b\\'), returnsNormally);
      expect(() => terminal.write('\x1bP+q+1\x1b\\'), returnsNormally);
    });
  });

  test('OSC colour components reject signs', () {
    final terminal = Terminal();
    terminal.write('\x1b]10;#-ff-ff-ff\x07');
    terminal.write('\x1b]11;rgb:+f/ff/ff\x07');
    expect(terminal.foregroundColorOverride, isNull);
    expect(terminal.backgroundColorOverride, isNull);
  });

  group('paste', () {
    test('normalises line endings to a single CR', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      terminal.paste('a\r\nb');
      terminal.paste('a\nb\rc\r\n\r\nd');

      expect(output, ['a\rb', 'a\rb\rc\r\rd']);
    });

    test('bracketed paste keeps line endings', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      terminal.write('\x1b[?2004h');
      terminal.paste('a\r\nb\nc');

      expect(output, ['\x1b[200~a\r\nb\nc\x1b[201~']);
    });
  });

  group('RIS', () {
    test('clears OSC colour overrides', () {
      final terminal = Terminal();
      terminal.write('\x1b]10;#00ff00\x07\x1b]11;#ff0000\x07');
      terminal.write('\x1b]4;1;#00ff00\x07\x1b]5;0;#0000ff\x07');
      terminal.write('\x1b]12;#0000ff\x07\x1b]13;#0000ff\x07');
      terminal.write('\x1b]17;#0000ff\x07\x1b]19;#0000ff\x07');
      final revision = terminal.colorRevision;

      terminal.write('\x1bc');

      expect(terminal.foregroundColorOverride, isNull);
      expect(terminal.backgroundColorOverride, isNull);
      expect(terminal.cursorColorOverride, isNull);
      expect(terminal.selectionColorOverride, isNull);
      expect(terminal.selectionForegroundColorOverride, isNull);
      expect(terminal.indexedColorOverrides, isEmpty);
      expect(terminal.specialColorOverrides, isEmpty);
      expect(terminal.colorRevision, greaterThan(revision));
    });

    test('clears DECAC assigned colours', () {
      final terminal = Terminal();
      terminal.write('\x1b[1;1;2,|\x1bc\x1b[0mhello');

      expect(terminal.buffer.lines[0].getForeground(0), CellColor.normal);
      expect(terminal.buffer.lines[0].getBackground(0), CellColor.normal);
    });

    test('clears saved DEC modes', () {
      final terminal = Terminal();
      terminal.write('\x1b[?7l\x1b[?7s\x1bc\x1b[?7r');

      expect(terminal.autoWrapMode, isTrue);
    });
  });

  group('origin mode with a left margin', () {
    Terminal setUp() {
      return Terminal()..write('\x1b[?69h\x1b[10;40s\x1b[?6h\x1b[1;1H');
    }

    test('VPA keeps the cursor column', () {
      final terminal = setUp();
      expect(terminal.buffer.cursorX, 9);

      terminal.write('\x1b[3d');
      expect(terminal.buffer.cursorX, 9);
      expect(terminal.buffer.cursorY, 2);

      terminal.write('\x1b[5d');
      expect(terminal.buffer.cursorX, 9);
      expect(terminal.buffer.cursorY, 4);
    });

    test('VPA keeps the cursor column without origin mode', () {
      final terminal = Terminal()..write('\x1b[1;7H\x1b[3d');
      expect(terminal.buffer.cursorX, 6);
      expect(terminal.buffer.cursorY, 2);
    });

    test('CHA and HPA are relative to the left margin', () {
      final terminal = setUp()..write('\x1b[3;1H');

      terminal.write('\x1b[5G');
      expect(terminal.buffer.cursorX, 13);
      expect(terminal.buffer.cursorY, 2);

      terminal.write('\x1b[7`');
      expect(terminal.buffer.cursorX, 15);
      expect(terminal.buffer.cursorY, 2);
    });
  });

  group('wide character at a soft wrap', () {
    test('search does not see the padding cell', () {
      final terminal = Terminal()..resize(5, 5);
      terminal.write('abcd中文');

      final matches = terminal.search('abcd中');
      expect(matches, hasLength(1));
      expect(matches.single.range.begin, const CellOffset(0, 0));
      expect(matches.single.range.end, const CellOffset(2, 1));
      expect(terminal.search('d 中'), isEmpty);

      final wide = terminal.search('中文').single;
      expect(wide.range.begin, const CellOffset(0, 1));
      expect(wide.range.end, const CellOffset(4, 1));
    });

    test('a real trailing space is kept', () {
      final terminal = Terminal()..resize(5, 5);
      terminal.write('abcd a');
      expect(terminal.search('d a'), hasLength(1));
    });
  });
}
