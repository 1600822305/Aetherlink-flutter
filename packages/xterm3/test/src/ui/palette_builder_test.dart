import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/src/ui/palette_builder.dart';
import 'package:xterm3/xterm.dart';

/// Every field gets a distinct color so a wrong index shows up as a wrong
/// value rather than an accidental match.
const _theme = TerminalTheme(
  cursor: Color(0xff000001),
  selection: Color(0xff000002),
  foreground: Color(0xff000003),
  background: Color(0xff000004),
  black: Color(0xff010101),
  red: Color(0xff020202),
  green: Color(0xff030303),
  yellow: Color(0xff040404),
  blue: Color(0xff050505),
  magenta: Color(0xff060606),
  cyan: Color(0xff070707),
  white: Color(0xff080808),
  brightBlack: Color(0xff090909),
  brightRed: Color(0xff0a0a0a),
  brightGreen: Color(0xff0b0b0b),
  brightYellow: Color(0xff0c0c0c),
  brightBlue: Color(0xff0d0d0d),
  brightMagenta: Color(0xff0e0e0e),
  brightCyan: Color(0xff0f0f0f),
  brightWhite: Color(0xff101010),
  searchHitBackground: Color(0xff111111),
  searchHitBackgroundCurrent: Color(0xff121212),
  searchHitForeground: Color(0xff131313),
);

void main() {
  group('PaletteBuilder.build', () {
    test('returns exactly 256 colors', () {
      final palette = PaletteBuilder(_theme).build();
      expect(palette, hasLength(256));
    });

    test('maps indices 0-15 to the theme\'s named ANSI colors in order', () {
      final palette = PaletteBuilder(_theme).build();
      expect(palette.sublist(0, 16), [
        _theme.black,
        _theme.red,
        _theme.green,
        _theme.yellow,
        _theme.blue,
        _theme.magenta,
        _theme.cyan,
        _theme.white,
        _theme.brightBlack,
        _theme.brightRed,
        _theme.brightGreen,
        _theme.brightYellow,
        _theme.brightBlue,
        _theme.brightMagenta,
        _theme.brightCyan,
        _theme.brightWhite,
      ]);
    });

    test('is deterministic: rebuilding the same theme yields an equal list',
        () {
      final builder = PaletteBuilder(_theme);
      expect(builder.build(), builder.build());
      expect(PaletteBuilder(_theme).build(), PaletteBuilder(_theme).build());
    });

    test(
      'is deterministic across distinct theme instances with the same '
      'values',
      () {
        const otherInstance = TerminalTheme(
          cursor: Color(0xff000001),
          selection: Color(0xff000002),
          foreground: Color(0xff000003),
          background: Color(0xff000004),
          black: Color(0xff010101),
          red: Color(0xff020202),
          green: Color(0xff030303),
          yellow: Color(0xff040404),
          blue: Color(0xff050505),
          magenta: Color(0xff060606),
          cyan: Color(0xff070707),
          white: Color(0xff080808),
          brightBlack: Color(0xff090909),
          brightRed: Color(0xff0a0a0a),
          brightGreen: Color(0xff0b0b0b),
          brightYellow: Color(0xff0c0c0c),
          brightBlue: Color(0xff0d0d0d),
          brightMagenta: Color(0xff0e0e0e),
          brightCyan: Color(0xff0f0f0f),
          brightWhite: Color(0xff101010),
          searchHitBackground: Color(0xff111111),
          searchHitBackgroundCurrent: Color(0xff121212),
          searchHitForeground: Color(0xff131313),
        );

        expect(
          PaletteBuilder(_theme).build(),
          PaletteBuilder(otherInstance).build(),
        );
      },
    );
  });

  group('PaletteBuilder.paletteColor', () {
    test('reproduces the standard xterm 216-color cube at its corners', () {
      final builder = PaletteBuilder(_theme);

      // https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit — the 6x6x6
      // color cube uses step values {0, 95, 135, 175, 215, 255} and index
      // 16 + 36*r + 6*g + b.
      expect(builder.paletteColor(16), const Color.fromARGB(0xFF, 0, 0, 0));
      expect(
        builder.paletteColor(21),
        const Color.fromARGB(0xFF, 0, 0, 255),
      ); // r=0 g=0 b=5 (pure blue)
      expect(
        builder.paletteColor(46),
        const Color.fromARGB(0xFF, 0, 255, 0),
      ); // r=0 g=5 b=0 (pure green)
      expect(
        builder.paletteColor(196),
        const Color.fromARGB(0xFF, 255, 0, 0),
      ); // r=5 g=0 b=0 (pure red)
      expect(
        builder.paletteColor(231),
        const Color.fromARGB(0xFF, 255, 255, 255),
      ); // r=5 g=5 b=5 (white corner)
    });

    test('reproduces the 24-step grayscale ramp at its boundaries', () {
      final builder = PaletteBuilder(_theme);

      expect(builder.paletteColor(232), const Color(0xff080808));
      expect(builder.paletteColor(255), const Color(0xffeeeeee));
      // A value picked from the middle of the published ramp table.
      expect(builder.paletteColor(243), const Color(0xff767676));
    });
  });
}
