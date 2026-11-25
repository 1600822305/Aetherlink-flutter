import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/xterm.dart';

void main() {
  test('urlAt detects a plain https URL and maps it to a cell range', () {
    final terminal = Terminal()..resize(40, 2);
    terminal.write('see https://example.com/foo for details');

    final match = terminal.urlAt(const CellOffset(10, 0));

    expect(match, isNotNull);
    expect(match!.text, 'https://example.com/foo');
    expect(match.range.begin, const CellOffset(4, 0));
    expect(match.range.end, const CellOffset(27, 0));
  });

  test('urlAt detects bare www. URLs', () {
    final terminal = Terminal()..resize(40, 2);
    terminal.write('visit www.example.com now');

    final match = terminal.urlAt(const CellOffset(8, 0));

    expect(match, isNotNull);
    expect(match!.text, 'www.example.com');
  });

  test('urlAt returns null outside of any URL', () {
    final terminal = Terminal()..resize(40, 2);
    terminal.write('see https://example.com/foo for details');

    expect(terminal.urlAt(const CellOffset(0, 0)), isNull);
    expect(terminal.urlAt(const CellOffset(39, 0)), isNull);
  });

  test('urlAt trims trailing sentence punctuation', () {
    final terminal = Terminal()..resize(40, 2);
    terminal.write('Go to https://example.com/foo, thanks.');

    final match = terminal.urlAt(const CellOffset(10, 0));

    expect(match!.text, 'https://example.com/foo');
  });

  test('urlAt keeps a balanced trailing paren but trims wrapping ones', () {
    final terminal = Terminal()..resize(60, 2);
    terminal.write(
      'wiki https://en.wikipedia.org/wiki/Dart_(programming_language) end',
    );
    final wiki = terminal.urlAt(const CellOffset(10, 0));
    expect(wiki!.text,
        'https://en.wikipedia.org/wiki/Dart_(programming_language)');

    final wrapped = Terminal()..resize(60, 2);
    wrapped.write('(see https://example.com/foo) end');
    final match = wrapped.urlAt(const CellOffset(10, 0));
    expect(match!.text, 'https://example.com/foo');
  });

  test('urlAt spans soft-wrapped rows', () {
    final terminal = Terminal()..resize(15, 3);
    terminal.write('see https://example.com/foo end');

    final match = terminal.urlAt(const CellOffset(2, 1));

    expect(match, isNotNull);
    expect(match!.text, 'https://example.com/foo');
  });

  test('urlAt does not span hard line breaks', () {
    final terminal = Terminal()..resize(40, 3);
    terminal.write('https://example.com/foo\r\nbar');

    expect(terminal.urlAt(const CellOffset(1, 1)), isNull);
  });
}
