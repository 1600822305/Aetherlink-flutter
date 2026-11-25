import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/src/ui/render.dart';
import 'package:xterm3/xterm.dart';

Widget _app(Terminal t) => MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 400, height: 200, child: TerminalView(t)),
      ),
    );

RenderTerminal _render(WidgetTester tester) =>
    tester.state<TerminalViewState>(find.byType(TerminalView)).renderTerminal;

ScrollPosition _pos(WidgetTester tester) => tester
    .state<TerminalViewState>(find.byType(TerminalView))
    .scrollableState!
    .position;

void main() {
  group('mouse reports with scrollback', () {
    Future<void> clickScreenCell(
      WidgetTester tester,
      Terminal t, {
      required int col,
      required int row,
    }) async {
      final render = _render(tester);
      final p = render.getOffset(CellOffset(col, t.buffer.scrollBack + row)) +
          const Offset(1, 8);
      render.mouseEvent(
        TerminalMouseButton.left,
        TerminalMouseButtonState.down,
        p,
      );
    }

    testWidgets('report the screen row under the pointer', (tester) async {
      final out = <String>[];
      final t = Terminal(maxLines: 10000, onOutput: out.add);
      await tester.pumpWidget(_app(t));
      t.write('\x1b[?1000h\x1b[?1006h');

      await clickScreenCell(tester, t, col: 2, row: 3);
      expect(out.last, '\x1b[<0;3;4M');

      for (var i = 0; i < 100; i++) {
        t.write('line $i\r\n');
      }
      await tester.pump();
      expect(t.buffer.scrollBack, greaterThan(0));

      await clickScreenCell(tester, t, col: 2, row: 3);
      expect(out.last, '\x1b[<0;3;4M');

      await clickScreenCell(tester, t, col: 0, row: 0);
      expect(out.last, '\x1b[<0;1;1M');

      await clickScreenCell(tester, t, col: 0, row: t.viewHeight - 1);
      expect(out.last, '\x1b[<0;1;${t.viewHeight}M');
    });

    testWidgets('SGR pixel reports are measured from the screen top',
        (tester) async {
      final out = <String>[];
      final t = Terminal(maxLines: 10000, onOutput: out.add);
      await tester.pumpWidget(_app(t));
      t.write('\x1b[?1000h\x1b[?1016h');
      for (var i = 0; i < 100; i++) {
        t.write('line $i\r\n');
      }
      await tester.pump();

      final render = _render(tester);
      final h = render.lineHeight;
      final w = render.cellSize.width;
      final p = render.getOffset(CellOffset(2, t.buffer.scrollBack + 3)) +
          const Offset(1, 5);
      render.mouseEvent(
        TerminalMouseButton.left,
        TerminalMouseButtonState.down,
        p,
      );
      expect(
        out.last,
        '\x1b[<0;${(2 * w).floor() + 1 + 1};${(3 * h).floor() + 5 + 1}M',
      );
    });

    testWidgets('scrolled up into scrollback, reports stay on screen',
        (tester) async {
      final out = <String>[];
      final t = Terminal(maxLines: 10000, onOutput: out.add);
      await tester.pumpWidget(_app(t));
      t.write('\x1b[?1000h\x1b[?1006h');
      for (var i = 0; i < 100; i++) {
        t.write('line $i\r\n');
      }
      await tester.pump();
      _pos(tester).jumpTo(0);
      await tester.pump();

      // Every visible row is scrollback, above the screen: clamp to row 1.
      final render = _render(tester);
      render.mouseEvent(
        TerminalMouseButton.left,
        TerminalMouseButtonState.down,
        const Offset(30, 100),
      );
      expect(out.last, '\x1b[<0;3;1M');
    });
  });

  testWidgets('scrolling back to the bottom while streaming resumes following',
      (tester) async {
    final t = Terminal(maxLines: 10000);
    await tester.pumpWidget(_app(t));
    for (var i = 0; i < 50; i++) {
      t.write('line $i\r\n');
    }
    await tester.pump();
    final pos = _pos(tester);
    pos.jumpTo(pos.maxScrollExtent - 60);
    await tester.pump();

    for (var f = 0; f < 5; f++) {
      t.write('more $f\r\n');
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pump();
    }
    for (var i = 0; i < 5; i++) {
      t.write('tail $i\r\n');
      await tester.pump();
    }

    expect(pos.pixels, pos.maxScrollExtent);
  });

  group('full scrollback while scrolled up', () {
    String topRow(WidgetTester tester, Terminal t) {
      final y = _render(tester).getCellOffset(const Offset(1, 12)).y;
      return t.buffer.lines[y].toString().trim();
    }

    Future<Terminal> setUp(WidgetTester tester) async {
      final t = Terminal(maxLines: 40);
      await tester.pumpWidget(_app(t));
      for (var i = 0; i < 60; i++) {
        t.write('line $i\r\n');
      }
      await tester.pump();
      _pos(tester).jumpTo(_render(tester).lineHeight * 10);
      await tester.pump();
      expect(topRow(tester, t), 'line 31');
      return t;
    }

    testWidgets('keeps the text under the reader in place', (tester) async {
      final t = await setUp(tester);
      for (var i = 0; i < 5; i++) {
        t.write('new $i\r\n');
      }
      await tester.pump();
      expect(topRow(tester, t), 'line 31');
      expect(_pos(tester).pixels, _render(tester).lineHeight * 5);
    });

    testWidgets('clamps at the top once the text is trimmed', (tester) async {
      final t = await setUp(tester);
      for (var i = 0; i < 15; i++) {
        t.write('new $i\r\n');
      }
      await tester.pump();
      expect(_pos(tester).pixels, 0);
      expect(topRow(tester, t), 'line 36');
    });

    testWidgets('follow mode at the bottom is unaffected', (tester) async {
      final t = Terminal(maxLines: 40);
      await tester.pumpWidget(_app(t));
      for (var i = 0; i < 60; i++) {
        t.write('line $i\r\n');
      }
      await tester.pump();
      final pos = _pos(tester);
      expect(pos.pixels, pos.maxScrollExtent);
      for (var i = 0; i < 5; i++) {
        t.write('new $i\r\n');
        await tester.pump();
      }
      expect(pos.pixels, pos.maxScrollExtent);
    });

    testWidgets('alt buffer switch does not shift the main view',
        (tester) async {
      final t = await setUp(tester);
      final pixels = _pos(tester).pixels;
      t.write('\x1b[?1049h');
      await tester.pump();
      // Scroll the alt screen so its own trim counter moves.
      for (var i = 0; i < 50; i++) {
        t.write('alt $i\r\n');
      }
      await tester.pump();
      t.write('\x1b[?1049l');
      await tester.pump();
      // The alt buffer's trim counter must not be applied to the main view.
      final pos = _pos(tester);
      expect(pos.pixels, anyOf(pixels, pos.maxScrollExtent));
    });

    testWidgets('swapping terminals does not shift the view', (tester) async {
      final t = await setUp(tester);
      final pixels = _pos(tester).pixels;
      final other = Terminal(maxLines: 40);
      for (var i = 0; i < 200; i++) {
        other.write('other $i\r\n');
      }
      await tester.pumpWidget(_app(other));
      await tester.pumpWidget(_app(t));
      final pos = _pos(tester);
      expect(pos.pixels, anyOf(pixels, pos.maxScrollExtent));
    });
  });

  group('TerminalTheme equality', () {
    const colors = [
      Color(0xff000001),
      Color(0xff000002),
      Color(0xff000003),
      Color(0xff000004),
      Color(0xff000005),
      Color(0xff000006),
      Color(0xff000007),
      Color(0xff000008),
      Color(0xff000009),
      Color(0xff00000a),
      Color(0xff00000b),
      Color(0xff00000c),
      Color(0xff00000d),
      Color(0xff00000e),
      Color(0xff00000f),
      Color(0xff000010),
      Color(0xff000011),
      Color(0xff000012),
      Color(0xff000013),
      Color(0xff000014),
      Color(0xff000015),
      Color(0xff000016),
      Color(0xff000017),
    ];

    TerminalTheme build(List<Color> c) => TerminalTheme(
          cursor: c[0],
          selection: c[1],
          foreground: c[2],
          background: c[3],
          black: c[4],
          red: c[5],
          green: c[6],
          yellow: c[7],
          blue: c[8],
          magenta: c[9],
          cyan: c[10],
          white: c[11],
          brightBlack: c[12],
          brightRed: c[13],
          brightGreen: c[14],
          brightYellow: c[15],
          brightBlue: c[16],
          brightMagenta: c[17],
          brightCyan: c[18],
          brightWhite: c[19],
          searchHitBackground: c[20],
          searchHitBackgroundCurrent: c[21],
          searchHitForeground: c[22],
        );

    test('equal fields are equal with equal hashCodes', () {
      final a = build(List.of(colors));
      final b = build(List.of(colors));
      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('changing any single field breaks equality', () {
      final base = build(colors);
      for (var i = 0; i < colors.length; i++) {
        final changed = List.of(colors)..[i] = const Color(0xffabcdef);
        expect(build(changed), isNot(base), reason: 'field $i');
      }
    });
  });
}
