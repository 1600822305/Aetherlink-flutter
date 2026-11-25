import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/src/ui/paragraph_cache.dart';
import 'package:xterm3/xterm.dart';

void main() {
  setUp(TerminalRenderStats.reset);
  tearDown(TerminalRenderStats.reset);

  test('reset zeroes every counter', () {
    TerminalRenderStats.paints = 3;
    TerminalRenderStats.paintedLines = 90;
    TerminalRenderStats.paragraphCacheHits = 5;
    TerminalRenderStats.paragraphCacheMisses = 1;
    TerminalRenderStats.glyphCacheHits = 2;
    TerminalRenderStats.glyphCacheMisses = 4;

    TerminalRenderStats.reset();

    expect(TerminalRenderStats.paints, 0);
    expect(TerminalRenderStats.paintedLines, 0);
    expect(TerminalRenderStats.paragraphCacheHits, 0);
    expect(TerminalRenderStats.paragraphCacheMisses, 0);
    expect(TerminalRenderStats.glyphCacheHits, 0);
    expect(TerminalRenderStats.glyphCacheMisses, 0);
  });

  test('derived ratios are null until something has been measured', () {
    expect(TerminalRenderStats.paragraphCacheHitRatio, isNull);
    expect(TerminalRenderStats.glyphCacheHitRatio, isNull);
    expect(TerminalRenderStats.linesPerPaint, isNull);
  });

  test('derived ratios divide by the totals they describe', () {
    TerminalRenderStats.paragraphCacheHits = 3;
    TerminalRenderStats.paragraphCacheMisses = 1;
    TerminalRenderStats.glyphCacheHits = 1;
    TerminalRenderStats.glyphCacheMisses = 3;
    TerminalRenderStats.paints = 4;
    TerminalRenderStats.paintedLines = 100;

    expect(TerminalRenderStats.paragraphCacheHitRatio, 0.75);
    expect(TerminalRenderStats.glyphCacheHitRatio, 0.25);
    expect(TerminalRenderStats.linesPerPaint, 25);
  });

  testWidgets('a screen with a colour per cell is drawn from the cache', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1700, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final terminal = Terminal();
    await tester.pumpWidget(MaterialApp(home: TerminalView(terminal)));
    await tester.pump();

    // More distinct (character, colour) pairs than the 2048 entries the cache
    // used to stop at. Below that size every frame evicted what the next one
    // needed, and each repaint laid the whole screen out again.
    final cells = terminal.viewWidth * terminal.viewHeight;
    expect(cells, greaterThan(4096));
    final screen = StringBuffer('\x1b[?1049h\x1b[H');
    for (var row = 0; row < terminal.viewHeight; row++) {
      for (var column = 0; column < terminal.viewWidth; column++) {
        screen.write('\x1b[38;2;${column % 256};${row % 256};${column ~/ 256}m'
            '${String.fromCharCode(0x21 + (column * 7 + row * 3) % 90)}');
      }
    }
    terminal.write(screen.toString());
    await tester.pump(const Duration(milliseconds: 16));

    TerminalRenderStats.reset();
    for (var frame = 0; frame < 3; frame++) {
      terminal.write('\x1b[H${frame.isEven ? 'x' : 'y'}');
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(TerminalRenderStats.paints, 3);
    expect(TerminalRenderStats.paragraphCacheHits, greaterThan(cells * 2));
    // One cell changes per frame, and nothing else may miss.
    expect(TerminalRenderStats.paragraphCacheMisses, lessThanOrEqualTo(3));
  });

  test('ParagraphCache lookups are counted as hits and misses', () {
    final cache = ParagraphCache(8);
    const style = TextStyle();

    expect(cache.getLayoutFromCache(1), isNull);
    expect(TerminalRenderStats.paragraphCacheMisses, 1);
    expect(TerminalRenderStats.paragraphCacheHits, 0);

    cache.performAndCacheLayout('a', style, TextScaler.noScaling, 1);
    expect(cache.getLayoutFromCache(1), isNotNull);
    expect(TerminalRenderStats.paragraphCacheHits, 1);
    expect(TerminalRenderStats.paragraphCacheMisses, 1);

    cache.dispose();
  });
}
