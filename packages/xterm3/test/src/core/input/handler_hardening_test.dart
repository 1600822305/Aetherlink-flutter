import 'package:test/test.dart';
import 'package:xterm3/xterm.dart';

void main() {
  group('modifyOtherKeys mode 2', () {
    late List<String> output;
    late Terminal terminal;

    setUp(() {
      output = <String>[];
      terminal = Terminal(onOutput: output.add)..write('\x1b[>4;2m');
    });

    test('leaves unmodified and shift-only text keys to text input', () {
      expect(terminal.keyInput(TerminalKey.keyA, text: 'a'), isFalse);
      expect(
          terminal.keyInput(TerminalKey.keyA, shift: true, text: 'A'), isFalse);
      expect(terminal.keyInput(TerminalKey.bracketLeft, text: '['), isFalse);
      expect(
        terminal.keyInput(TerminalKey.bracketLeft, shift: true, text: '{'),
        isFalse,
      );
      expect(terminal.keyInput(TerminalKey.keyA), isFalse);

      expect(output, isEmpty);
    });

    test('still encodes Ctrl, Alt, Meta and Shift+Space', () {
      terminal.keyInput(TerminalKey.keyA, ctrl: true, text: 'a');
      terminal.keyInput(TerminalKey.keyA, alt: true, text: 'a');
      terminal.keyInput(TerminalKey.keyA, superKey: true, text: 'a');
      terminal.keyInput(TerminalKey.keyA, shift: true, ctrl: true, text: 'A');
      terminal.keyInput(TerminalKey.space, shift: true, text: ' ');

      expect(output, [
        '\x1b[27;5;97~',
        '\x1b[27;3;97~',
        '\x1b[27;9;97~',
        '\x1b[27;6;65~',
        '\x1b[27;2;32~',
      ]);
    });

    test('keeps Shift+Enter distinct', () {
      terminal.keyInput(TerminalKey.enter, shift: true);

      expect(output, ['\x1b[27;2;13~']);
    });
  });
}
