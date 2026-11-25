import 'package:characters/characters.dart';
import 'package:test/test.dart';
import 'package:xterm3/src/utils/single_cell_text.dart';
import 'package:xterm3/src/utils/unicode_v11.dart';

void main() {
  test('every single-cell printable is width 1 and starts its own grapheme',
      () {
    // The two properties a batched write relies on, checked for every code
    // unit the predicate accepts rather than for the ranges it is written in.
    var accepted = 0;
    for (var codeUnit = 0; codeUnit <= 0xffff; codeUnit++) {
      if (!isSingleCellPrintable(codeUnit)) continue;
      accepted++;
      expect(unicodeV11.wcwidth(codeUnit), 1,
          reason: 'U+${codeUnit.toRadixString(16)}');
      final char = String.fromCharCode(codeUnit);
      for (final previous in ['a', 'é', 'я', '中', '─', '\u{1F600}']) {
        expect((previous + char).characters.length, 2,
            reason: 'U+${codeUnit.toRadixString(16)} after $previous');
      }
    }
    expect(accepted, greaterThan(1500));
  });

  test('box drawing, block elements, braille and dashes are in the set', () {
    for (final codeUnit in [0x2014, 0x2026, 0x2500, 0x256c, 0x2588, 0x28ff]) {
      expect(isSingleCellPrintable(codeUnit), isTrue,
          reason: 'U+${codeUnit.toRadixString(16)}');
    }
  });

  test('zero-width and wide characters stay out of the set', () {
    for (final codeUnit in [0xad, 0x300, 0x200b, 0x200d, 0x2028, 0x4e00]) {
      expect(isSingleCellPrintable(codeUnit), isFalse,
          reason: 'U+${codeUnit.toRadixString(16)}');
    }
  });
}
