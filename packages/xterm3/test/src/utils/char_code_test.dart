import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/src/utils/char_code.dart';

void main() {
  group('singleCodePoint', () {
    test('returns the code point of a one-unit string', () {
      expect(singleCodePoint('a'), 0x61);
      expect(singleCodePoint('ç'), 0xe7);
    });

    test('decodes a surrogate pair as one code point', () {
      expect(singleCodePoint('\u{1F600}'), 0x1F600);
      expect(singleCodePoint('\u{10437}'), 0x10437);
    });

    test('returns null for anything that is not exactly one code point', () {
      expect(singleCodePoint(''), isNull);
      expect(singleCodePoint('ab'), isNull);
      expect(singleCodePoint('\u{1F600}a'), isNull);
    });

    test('treats a lone surrogate as one code unit, matching runes', () {
      // Two units that are not a valid pair are two runes, not one.
      expect(singleCodePoint('\ud83d\ud83d'), isNull);
      // A lone high surrogate on its own is a single rune.
      expect(singleCodePoint('\ud83d'), 0xd83d);
    });

    test('agrees with the runes it replaces', () {
      for (final text in [
        'a',
        'Z',
        '9',
        'ç',
        '\u{1F600}',
        '',
        'ab',
        'abc',
        '\ud83d',
      ]) {
        final expected = switch (text.runes.length == 1) {
          true => text.runes.first,
          false => null,
        };
        expect(singleCodePoint(text), expected, reason: 'for "$text"');
      }
    });
  });
}
