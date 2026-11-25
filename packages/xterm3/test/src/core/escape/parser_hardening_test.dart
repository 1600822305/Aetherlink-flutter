import 'dart:io';

import 'package:test/test.dart';
import 'package:xterm3/core.dart';

void main() {
  group('CSI numeric parameters', () {
    const huge = '18446744073709551615';

    for (final finalBytes in ['L', 'M', 'S', 'T', '@', 'P', "'}", "'~", 'b']) {
      for (final param in [huge, '20000000']) {
        test('parameter $param for $finalBytes does not throw or stall', () {
          final terminal = Terminal();
          final stopwatch = Stopwatch()..start();

          terminal.write('A\x1b[$param${finalBytes}B-after');

          stopwatch.stop();
          expect(stopwatch.elapsedMilliseconds, lessThan(200));
          final text = terminal.buffer.lines.toList().map((l) => l.getText());
          expect(text.join('\n'), contains('B-after'));
        });
      }
    }
  });

  group('ESC with intermediate bytes', () {
    const sequences = [
      '\x1b%G',
      '\x1b%@',
      '\x1b F',
      '\x1b G',
      '\x1b-A',
      '\x1b.A',
      '\x1b/A',
      '\x1b\$(D',
    ];

    for (final sequence in sequences) {
      final name = sequence.substring(1);

      test('ESC $name is discarded', () {
        final terminal = Terminal();
        terminal.write('<$sequence>');
        expect(terminal.buffer.lines[0].getText(), '<>');
      });

      test('ESC $name is discarded when split byte by byte', () {
        final terminal = Terminal();
        for (final char in '<$sequence>'.split('')) {
          terminal.write(char);
        }
        expect(terminal.buffer.lines[0].getText(), '<>');
      });
    }

    test('charset designation and ESC # still work', () {
      final terminal = Terminal();
      terminal.write('\x1b(0q\x1b(B');
      expect(terminal.buffer.lines[0].getText(), '─');

      terminal.write('\x1b#8');
      expect(terminal.buffer.lines[1].getText(), 'E' * terminal.viewWidth);
    });
  });

  group('SGR colon truecolor', () {
    test('without colour space followed by more parameters', () {
      final terminal = Terminal();

      terminal.write('\x1b[38:2:255:0:0;1mX');

      final line = terminal.buffer.lines[0];
      expect(line.getForeground(0), CellColor.rgb | 0xff0000);
      expect(line.getAttributes(0) & CellAttr.bold, isNot(0));
    });

    test('foreground and background without colour space', () {
      final terminal = Terminal();

      terminal.write('\x1b[38:2:255:0:0;48:2:0:0:255;58:2:1:2:3mX');

      final line = terminal.buffer.lines[0];
      expect(line.getForeground(0), CellColor.rgb | 0xff0000);
      expect(line.getBackground(0), CellColor.rgb | 0x0000ff);
      expect(line.getUnderlineColor(0), CellColor.rgb | 0x010203);
    });

    test('with colour space and semicolon forms stay correct', () {
      final terminal = Terminal();

      terminal.write('\x1b[38:2::255:0:0;1mX\x1b[0;38;2;0;255;0;1mY');

      final line = terminal.buffer.lines[0];
      expect(line.getForeground(0), CellColor.rgb | 0xff0000);
      expect(line.getAttributes(0) & CellAttr.bold, isNot(0));
      expect(line.getForeground(1), CellColor.rgb | 0x00ff00);
      expect(line.getAttributes(1) & CellAttr.bold, isNot(0));
    });
  });

  group('OSC length limit', () {
    for (var length = 8188; length <= 8193; length++) {
      test('terminator after $length payload bytes ends the OSC', () {
        final terminal = Terminal();

        terminal.write('\x1b]2;${'x' * length}\x07HELLO-VISIBLE\r\nnext');

        expect(terminal.buffer.lines[0].getText(), 'HELLO-VISIBLE');
        expect(terminal.buffer.lines[1].getText(), 'next');
      });

      test('ST after $length payload bytes ends the OSC', () {
        final terminal = Terminal();

        terminal.write('\x1b]2;${'x' * length}\x1b\\HELLO-VISIBLE');

        expect(terminal.buffer.lines[0].getText(), 'HELLO-VISIBLE');
      });
    }
  });

  test('XTVERSION reports the pubspec version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(pubspec)!
        .group(1)!;
    final output = <String>[];
    final terminal = Terminal(onOutput: output.add);

    terminal.write('\x1b[>q');

    expect(output.single, contains('xterm3 $version'));
  });
}
