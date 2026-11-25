import 'dart:math';
import 'dart:typed_data';

import 'dart:ui' as ui;
import 'package:flutter/widgets.dart'
    show TextDecoration, TextDecorationStyle, TextScaler, TextStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/src/ui/painter.dart';
import 'package:xterm3/xterm.dart';

void main() {
  test('cell size covers a whole number of device pixels', () {
    for (final ratio in [1.0, 1.5, 2.0, 3.0]) {
      final painter = TerminalPainter(
        theme: TerminalThemes.whiteOnBlack,
        textStyle: const TerminalStyle(fontSize: 14.3),
        textScaler: TextScaler.noScaling,
        devicePixelRatio: ratio,
      );

      final cellSize = painter.cellSize;
      expect(cellSize.width * ratio,
          closeTo((cellSize.width * ratio).roundToDouble(), 1e-9),
          reason: 'width at ratio $ratio');
      expect(cellSize.height * ratio,
          closeTo((cellSize.height * ratio).roundToDouble(), 1e-9),
          reason: 'height at ratio $ratio');
      painter.dispose();
    }
  });

  test('changing the device pixel ratio re-snaps the cell size', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 14.3),
      textScaler: TextScaler.noScaling,
      devicePixelRatio: 1,
    );

    final atOne = painter.cellSize;
    painter.devicePixelRatio = 2;
    final atTwo = painter.cellSize;

    expect(atTwo, isNot(atOne));
    expect(atTwo.width * 2, closeTo((atTwo.width * 2).roundToDouble(), 1e-9));
    painter.dispose();
  });

  test('reverse display swaps normal cell backgrounds', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(),
      textScaler: TextScaler.noScaling,
    );
    final cell = CellData.empty();

    expect(painter.resolveCellBackgroundColor(cell), isNull);

    painter.reverseDisplay = true;
    expect(
      painter.resolveCellBackgroundColor(cell),
      TerminalThemes.whiteOnBlack.foreground,
    );

    cell.flags = CellFlags.inverse;
    expect(painter.resolveCellBackgroundColor(cell), isNull);
    painter.dispose();
  });

  test('paintLine hides blinking text during the off phase', () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final terminal = Terminal()..write('\x1b[5mX');
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final hasBlinkingText = painter.paintLine(
      canvas,
      Offset.zero,
      terminal.buffer.lines[0],
      blinkVisible: false,
    );

    expect(hasBlinkingText, isTrue);
    expect(painter.paragraphCacheLength, 0);

    painter.paintLine(canvas, Offset.zero, terminal.buffer.lines[0]);
    expect(painter.paragraphCacheLength, 1);

    recorder.endRecording().dispose();
    painter.dispose();
  });

  test('paintLine splits backgrounds from foreground glyphs', () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final terminal = Terminal()..write('\x1b[48;2;12;34;56mX');
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    painter.paintLineBackgrounds(canvas, Offset.zero, terminal.buffer.lines[0]);
    expect(painter.paragraphCacheLength, 0);

    painter.paintLineForegrounds(canvas, Offset.zero, terminal.buffer.lines[0]);
    expect(painter.paragraphCacheLength, 1);

    recorder.endRecording().dispose();
    painter.dispose();
  });

  test('paintLine renders decorated spaces without glyph layouts', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final terminal = Terminal()..write('   \x1b[4m \x1b[0m ');
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    painter.paintLineForegrounds(canvas, Offset.zero, terminal.buffer.lines[0]);

    expect(painter.paragraphCacheLength, 0);

    recorder.endRecording().dispose();
    painter.dispose();
  });

  test('paintLine skips horizontal tab glyph layouts', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final terminal = Terminal()..write('\t');
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    painter.paintLineForegrounds(canvas, Offset.zero, terminal.buffer.lines[0]);

    expect(painter.paragraphCacheLength, 0);

    recorder.endRecording().dispose();
    painter.dispose();
  });

  test('paintLine foreground override uses separate glyph cache entry', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final terminal = Terminal()..write('X');
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    painter.paintLineForegrounds(canvas, Offset.zero, terminal.buffer.lines[0]);
    expect(painter.paragraphCacheLength, 1);

    painter.paintLineForegrounds(
      canvas,
      Offset.zero,
      terminal.buffer.lines[0],
      cursorColumn: 0,
      cursorForeground: const ui.Color(0xFF000000),
    );
    expect(painter.paragraphCacheLength, 2);

    painter.paintLineForegrounds(
      canvas,
      Offset.zero,
      terminal.buffer.lines[0],
      foregroundOverride: const ui.Color(0xFF00FF00),
    );
    expect(painter.paragraphCacheLength, 3);

    recorder.endRecording().dispose();
    painter.dispose();
  });

  test('TerminalPainter bounds its paragraph cache', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
      paragraphCacheSize: 2,
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final cell = CellData.empty()
      ..content = 0x41 | (1 << CellContent.widthShift);

    for (var color = 1; color <= 3; color++) {
      cell.foreground = CellColor.rgb | color;
      painter.paintCellForeground(canvas, Offset.zero, cell);
    }

    expect(painter.paragraphCacheLength, 2);
    recorder.endRecording().dispose();
    painter.dispose();
  });

  test('TerminalPainter caches rasterised procedural glyphs', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    // 0x253C is BOX DRAWINGS LIGHT VERTICAL AND HORIZONTAL, a procedural
    // (not font-shaped) glyph built from several canvas operations. Block
    // elements deliberately bypass this cache - see the test below.
    final cell = CellData.empty()
      ..content = 0x253c | (1 << CellContent.widthShift)
      ..foreground = CellColor.rgb | 0xff0000;

    for (var i = 0; i < 5; i++) {
      painter.paintCellForeground(canvas, Offset.zero, cell);
    }
    expect(painter.proceduralGlyphCacheLength, 1);

    // A different fill color must not reuse the same rasterised picture.
    cell.foreground = CellColor.rgb | 0x00ff00;
    painter.paintCellForeground(canvas, Offset.zero, cell);
    expect(painter.proceduralGlyphCacheLength, 2);

    recorder.endRecording().dispose();
    painter.dispose();
    expect(painter.proceduralGlyphCacheLength, 0);
  });

  test('TerminalPainter bounds its procedural glyph cache', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
      proceduralGlyphCacheSize: 2,
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final cell = CellData.empty()
      ..content = 0x253c | (1 << CellContent.widthShift);

    for (var color = 1; color <= 3; color++) {
      cell.foreground = CellColor.rgb | color;
      painter.paintCellForeground(canvas, Offset.zero, cell);
    }

    expect(painter.proceduralGlyphCacheLength, 2);
    recorder.endRecording().dispose();
    painter.dispose();
  });

  test('TerminalPainter does not cache block elements', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Block elements (U+2580..U+259F) are one or two `drawRect` calls, so
    // replaying a recorded Picture per cell costs the raster thread more than
    // drawing them costs outright. Measured on the benchmark's `fullscreen`
    // workload, caching U+2588 added 0.4ms of raster per frame at a 100% hit
    // rate and saved nothing on the UI thread.
    final cell = CellData.empty()
      ..content = 0x2588 | (1 << CellContent.widthShift)
      ..foreground = CellColor.rgb | 0xff0000;

    for (var i = 0; i < 5; i++) {
      painter.paintCellForeground(canvas, Offset.zero, cell);
    }

    expect(painter.proceduralGlyphCacheLength, 0);
    recorder.endRecording().dispose();
    painter.dispose();
  });

  test('paintLine reuses glyph layout across background colors', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final terminal = Terminal()..write('\x1b[41mX\x1b[42mX');
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    painter.paintLineForegrounds(canvas, Offset.zero, terminal.buffer.lines[0]);

    expect(painter.paragraphCacheLength, 1);

    recorder.endRecording().dispose();
    painter.dispose();
  });

  test('TerminalPainter resolves OSC color overrides', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final terminal = Terminal()
      ..write(
        '\x1b]4;1;#123456\x1b\\'
        '\x1b]10;#234567;#345678;#456789\x1b\\'
        '\x1b]17;#56789a\x1b\\'
        '\x1b]19;#6789ab\x1b\\',
      );

    painter.updateColorOverrides(
      terminal,
      terminal.colorRevision,
      terminal.indexedColorOverrides,
      terminal.specialColorOverrides,
      terminal.foregroundColorOverride,
      terminal.backgroundColorOverride,
      terminal.cursorColorOverride,
      terminal.selectionColorOverride,
      terminal.selectionForegroundColorOverride,
    );

    expect(
      painter.resolveForegroundColor(CellColor.named | 1),
      const ui.Color(0xff123456),
    );
    expect(
      painter.resolveForegroundColor(CellColor.normal),
      const ui.Color(0xff234567),
    );
    expect(painter.backgroundColor, const ui.Color(0xff345678));
    expect(painter.cursorColor, const ui.Color(0xff456789));
    expect(painter.selectionColor, const ui.Color(0xff56789a));
    expect(painter.selectionForegroundColor, const ui.Color(0xff6789ab));

    painter.dispose();
  });

  test('TerminalPainter falls back for invalid palette colors', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );

    expect(
      painter.resolveForegroundColor(CellColor.palette | 300),
      painter.foregroundColor,
    );
    expect(
      painter.resolveBackgroundColor(CellColor.palette | 300),
      painter.backgroundColor,
    );

    painter.dispose();
  });

  test('TerminalPainter maps bold ANSI colors to bright palette', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final redCell = CellData.empty()
      ..foreground = CellColor.named | 1
      ..flags = CellFlags.bold;
    final brightRedCell = CellData.empty()
      ..foreground = CellColor.named | 9
      ..flags = CellFlags.bold;
    final rgbCell = CellData.empty()
      ..foreground = CellColor.rgb | 0x102030
      ..flags = CellFlags.bold;

    expect(
      painter.resolveCellForegroundColor(redCell),
      TerminalThemes.whiteOnBlack.brightRed,
    );
    expect(
      painter.resolveCellForegroundColor(brightRedCell),
      TerminalThemes.whiteOnBlack.brightRed,
    );
    expect(
      painter.resolveCellForegroundColor(rgbCell),
      const ui.Color(0xff102030),
    );

    painter.dispose();
  });

  test('TerminalPainter lets OSC bold color override bold bright mapping', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final terminal = Terminal()..write('\x1b]5;0;#123456\x1b\\');
    painter.updateColorOverrides(
      terminal,
      terminal.colorRevision,
      terminal.indexedColorOverrides,
      terminal.specialColorOverrides,
      terminal.foregroundColorOverride,
      terminal.backgroundColorOverride,
      terminal.cursorColorOverride,
      terminal.selectionColorOverride,
      terminal.selectionForegroundColorOverride,
    );
    final cell = CellData.empty()
      ..foreground = CellColor.named | 1
      ..flags = CellFlags.bold;

    expect(
      painter.resolveCellForegroundColor(cell),
      const ui.Color(0xff123456),
    );

    painter.dispose();
  });

  test('TerminalPainter dims faint text without making it transparent', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final cell = CellData.empty()
      ..foreground = CellColor.rgb | 0xC86432
      ..flags = CellFlags.faint;

    final color = painter.resolveCellForegroundColor(cell);

    expect(color.a, 1);
    expect(color.r, closeTo((0xC8 / 0xFF) * 0.66, 0.001));
    expect(color.g, closeTo((0x64 / 0xFF) * 0.66, 0.001));
    expect(color.b, closeTo((0x32 / 0xFF) * 0.66, 0.001));
    painter.dispose();
  });

  test('TerminalPainter dims logical foreground before inverse swap', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final cell = CellData.empty()
      ..foreground = CellColor.rgb | 0xC86432
      ..background = CellColor.rgb | 0x102030
      ..flags = CellFlags.faint | CellFlags.inverse;

    final foreground = painter.resolveCellForegroundColor(cell);
    final background = painter.resolveCellBackgroundColor(cell);

    expect(foreground, const ui.Color(0xFF102030));
    expect(background, isNotNull);
    if (background case final color?) {
      expect(color.a, 1);
      expect(color.r, closeTo((0xC8 / 0xFF) * 0.66, 0.001));
      expect(color.g, closeTo((0x64 / 0xFF) * 0.66, 0.001));
      expect(color.b, closeTo((0x32 / 0xFF) * 0.66, 0.001));
    }
    painter.dispose();
  });

  test('TerminalPainter applies OSC special attribute colors', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final terminal = Terminal()
      ..write(
        '\x1b]5;0;#111111;2;#222222;3;#333333;4;#444444\x1b\\',
      );

    painter.updateColorOverrides(
      terminal,
      terminal.colorRevision,
      terminal.indexedColorOverrides,
      terminal.specialColorOverrides,
      terminal.foregroundColorOverride,
      terminal.backgroundColorOverride,
      terminal.cursorColorOverride,
      terminal.selectionColorOverride,
      terminal.selectionForegroundColorOverride,
    );

    final boldCell = CellData.empty()..flags = CellFlags.bold;
    final blinkCell = CellData.empty()..flags = CellFlags.blink;
    final italicCell = CellData.empty()..flags = CellFlags.italic;
    final inverseCell = CellData.empty()..flags = CellFlags.inverse;

    expect(
      painter.resolveCellForegroundColor(boldCell),
      const ui.Color(0xff111111),
    );
    expect(
      painter.resolveCellForegroundColor(blinkCell),
      const ui.Color(0xff222222),
    );
    expect(
      painter.resolveCellForegroundColor(inverseCell),
      const ui.Color(0xff333333),
    );
    expect(
      painter.resolveCellForegroundColor(italicCell),
      const ui.Color(0xff444444),
    );

    painter.dispose();
  });

  test('TerminalPainter invalidates colors when terminal changes', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final first = Terminal()..write('\x1b]4;1;#112233\x1b\\');
    final second = Terminal()..write('\x1b]4;1;#445566\x1b\\');

    void apply(Terminal terminal) {
      painter.updateColorOverrides(
        terminal,
        terminal.colorRevision,
        terminal.indexedColorOverrides,
        terminal.specialColorOverrides,
        terminal.foregroundColorOverride,
        terminal.backgroundColorOverride,
        terminal.cursorColorOverride,
        terminal.selectionColorOverride,
        terminal.selectionForegroundColorOverride,
      );
    }

    apply(first);
    expect(
      painter.resolveForegroundColor(CellColor.named | 1),
      const ui.Color(0xff112233),
    );

    apply(second);
    expect(
      painter.resolveForegroundColor(CellColor.named | 1),
      const ui.Color(0xff445566),
    );

    painter.dispose();
  });

  test('TerminalPainter keeps cursors visible on low-contrast cells', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final cell = CellData.empty()
      ..foreground = CellColor.named
      ..background = CellColor.named;

    final colors = painter.resolveCursorColors(cell);

    expect(colors.background, painter.foregroundColor);
    expect(colors.foreground, painter.backgroundColor);

    painter.dispose();
  });

  test('TerminalPainter reveals low-contrast selected text', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final cell = CellData.empty()..foreground = CellColor.rgb | 0xaeafad;

    final color = painter.resolveSelectionForegroundColor(cell);

    expect(color, painter.backgroundColor);
    painter.dispose();
  });

  test('TerminalPainter preserves contrasting selected text', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final cell = CellData.empty()..foreground = CellColor.rgb | 0xff0000;

    final color = painter.resolveSelectionForegroundColor(cell);

    expect(color, const ui.Color(0xffff0000));
    painter.dispose();
  });

  test('TerminalPainter cell width fits visible ASCII glyphs', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final textStyle = painter.textStyle.toTextStyle();
    final paragraphStyle = textStyle.getParagraphStyle();
    final textStyleRun = textStyle.getTextStyle(
      textScaler: painter.textScaler,
    );

    for (final codePoint in [0x21, 0x4d, 0x57, 0x6d, 0x7e]) {
      final builder = ui.ParagraphBuilder(paragraphStyle);
      builder.pushStyle(textStyleRun);
      builder.addText(String.fromCharCode(codePoint));

      final paragraph = builder.build();
      paragraph.layout(const ui.ParagraphConstraints(width: double.infinity));

      expect(
        painter.cellSize.width,
        greaterThanOrEqualTo(paragraph.maxIntrinsicWidth),
      );
      paragraph.dispose();
    }

    painter.dispose();
  });

  test('block cursor spans the requested cell width', () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );

    final image = await _paintCursor(
      painter,
      Offset.zero,
      TerminalCursorType.block,
      cellWidth: 2,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final byteData = bytes;
    if (byteData == null) {
      fail('Expected cursor image bytes');
    }

    final firstCellX = (painter.cellSize.width / 2).round();
    final secondCellX = (painter.cellSize.width * 1.5).round();
    expect(_alphaAt(byteData, image.width, firstCellX, 1), greaterThan(0));
    expect(_alphaAt(byteData, image.width, secondCellX, 1), greaterThan(0));

    image.dispose();
  });

  test('paintLine shapes combining characters with their base glyph', () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final baseTerminal = Terminal()..write('X');
    final combinedTerminal = Terminal()..write('X\u0338');
    expect(
      combinedTerminal.buffer.lines[0].getCombiningCharacters(0),
      '\u0338',
    );

    final baseImage = await _paintLine(
      painter,
      baseTerminal.buffer.lines[0],
    );
    final combinedImage = await _paintLine(
      painter,
      combinedTerminal.buffer.lines[0],
    );

    expect(painter.paragraphCacheLength, 2);
    expect(combinedTerminal.buffer.cursorX, 1);

    baseImage.dispose();
    combinedImage.dispose();
  });

  test('paintCellForeground clips glyphs to their terminal cell span',
      () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 40, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final cell = CellData.empty()
      ..content = 0x1F600 | (1 << CellContent.widthShift);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    painter.paintCellForeground(canvas, Offset.zero, cell);

    final picture = recorder.endRecording();
    final image = await picture.toImage(120, 60);
    picture.dispose();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final byteData = bytes;
    if (byteData == null) {
      fail('Expected glyph image bytes');
    }

    final clipEnd = painter.cellSize.width.ceil();
    expect(
      _hasAnyAlphaInRect(
        byteData,
        image.width,
        0,
        0,
        clipEnd,
        image.height,
      ),
      isTrue,
    );
    expect(
      _hasAnyAlphaInRect(
        byteData,
        image.width,
        clipEnd,
        0,
        image.width,
        image.height,
      ),
      isFalse,
    );
    expect(painter.paragraphCacheLength, 1);
    image.dispose();
    painter.dispose();
  });

  test('paintCellForeground shrinks an overflowing wide glyph to its cells',
      () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 40, height: 1),
      textScaler: TextScaler.noScaling,
    );
    // The test font draws every glyph as a one-cell square, so no single
    // character overflows two cells here the way a color emoji does on a
    // real system. A four-glyph cluster in a wide cell is twice as wide as
    // its cells and takes the same path.
    final cell = CellData.empty()
      ..content = 0x58 | (2 << CellContent.widthShift);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    painter.paintCellForeground(
      canvas,
      Offset.zero,
      cell,
      combiningCharacters: 'XXX',
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 60);
    picture.dispose();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final byteData = bytes;
    if (byteData == null) {
      fail('Expected glyph image bytes');
    }

    final cellWidth = painter.cellSize.width;
    final cellHeight = painter.cellSize.height;
    final spanEnd = (cellWidth * 2).ceil();
    // The last glyph of the cluster reaches the second cell instead of being
    // clipped away past it.
    expect(
      _hasAnyAlphaInRect(
        byteData,
        image.width,
        (cellWidth * 1.5).round(),
        0,
        spanEnd,
        image.height,
      ),
      isTrue,
    );
    expect(
      _hasAnyAlphaInRect(
        byteData,
        image.width,
        spanEnd,
        0,
        image.width,
        image.height,
      ),
      isFalse,
    );
    // Shrunk to half size and centred, the glyphs leave the top and bottom
    // quarter of the cell empty; clipped at full size they would fill it.
    expect(
      _hasAnyAlphaInRect(
        byteData,
        image.width,
        0,
        0,
        spanEnd,
        (cellHeight / 4).floor() - 1,
      ),
      isFalse,
    );
    expect(
      _alphaAt(
        byteData,
        image.width,
        (cellWidth / 4).round(),
        (cellHeight / 2).round(),
      ),
      greaterThan(0),
    );
    image.dispose();
    painter.dispose();
  });

  test('TerminalStyle combines text decorations', () {
    final style = const TerminalStyle().toTextStyle(
      decorationColor: const ui.Color(0xFFFF0000),
      underline: true,
      decorationStyle: TextDecorationStyle.dashed,
      strikethrough: true,
      overline: true,
    );
    final decoration = style.decoration;
    if (decoration == null) {
      fail('Expected text decoration');
    }

    expect(decoration.contains(TextDecoration.underline), isTrue);
    expect(decoration.contains(TextDecoration.lineThrough), isTrue);
    expect(decoration.contains(TextDecoration.overline), isTrue);
    expect(style.decorationStyle, TextDecorationStyle.dashed);
    expect(style.decorationColor, const ui.Color(0xFFFF0000));
  });

  test('TerminalStyle renders double underline style', () {
    final style = const TerminalStyle().toTextStyle(
      doubleUnderline: true,
      decorationStyle: TextDecorationStyle.dashed,
    );

    expect(style.decoration, TextDecoration.underline);
    expect(style.decorationStyle, TextDecorationStyle.double);
  });

  test('paintLine doubles active hyperlink underline on underlined cells',
      () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final line = BufferLine(1);
    final style = CursorStyle()
      ..setUnderline()
      ..hyperlinkId = 1;
    line.setCell(0, 0x41, 1, style);

    final image = await _paintLine(painter, line, activeHyperlinkId: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final byteData = bytes;
    if (byteData == null) {
      fail('Expected line image bytes');
    }

    final lowerUnderlineY = painter.cellSize.height.round() - 1;
    final upperUnderlineY = painter.cellSize.height.round() - 3;
    expect(_hasAlphaInRow(byteData, image.width, lowerUnderlineY), isTrue);
    expect(_hasAlphaInRow(byteData, image.width, upperUnderlineY), isTrue);

    image.dispose();
    painter.dispose();
  });

  test('TerminalStyle defaults include platform glyph fallbacks', () {
    const style = TerminalStyle();

    expect(
      style.fontFamilyFallback,
      containsAllInOrder([
        'SF Mono',
        'Menlo',
        'Cascadia Mono',
        'DejaVu Sans Mono',
        'Symbols Nerd Font Mono',
        'Symbols Nerd Font',
        'STIX Two Math',
        'Segoe UI Symbol',
        'Noto Sans Symbols 2',
        'Noto Sans Symbols',
        'Apple Color Emoji',
        'Segoe UI Emoji',
        'Noto Color Emoji',
      ]),
    );
  });

  test('TerminalStyle prefers text presentation over color emoji', () {
    // A codepoint like U+23F8 PAUSE defaults to text presentation and is
    // missing from every monospace family in the list. Whichever symbol font
    // supplies it must be consulted before the emoji fonts, or the glyph
    // arrives as a full-color pictograph inside a line of terminal text.
    final fallback = const TerminalStyle().fontFamilyFallback;
    const symbolFamilies = [
      'Symbols Nerd Font Mono',
      'STIX Two Math',
      'Segoe UI Symbol',
      'Noto Sans Symbols 2',
    ];
    const emojiFamilies = [
      'Apple Color Emoji',
      'Segoe UI Emoji',
      'Noto Color Emoji',
    ];

    final firstEmoji =
        emojiFamilies.map(fallback.indexOf).where((i) => i >= 0).reduce(min);
    for (final family in symbolFamilies) {
      expect(
        fallback.indexOf(family),
        allOf(greaterThanOrEqualTo(0), lessThan(firstEmoji)),
        reason: '$family must precede every color emoji family',
      );
    }
  });

  test('TerminalStyle disables ligatures and kerning by default', () {
    final style = const TerminalStyle().toTextStyle();
    final features = style.fontFeatures;
    if (features == null) {
      fail('Expected terminal font features');
    }

    expect(
      features.map((feature) => feature.feature).toSet(),
      containsAll(['calt', 'clig', 'dlig', 'hlig', 'kern', 'liga']),
    );
    expect(features.every((feature) => feature.value == 0), isTrue);
  });

  test('TerminalStyle enables merging features when ligatures are on', () {
    final style = const TerminalStyle(enableLigatures: true).toTextStyle();
    final features = style.fontFeatures;
    if (features == null) {
      fail('Expected terminal font features');
    }

    final values = {
      for (final feature in features) feature.feature: feature.value,
    };
    expect(values['calt'], 1);
    expect(values['clig'], 1);
    expect(values['liga'], 1);
    // Kerning shifts advances without merging glyphs, and discretionary and
    // historical ligatures are not what a terminal asks for.
    expect(values['kern'], 0);
    expect(values['dlig'], 0);
    expect(values['hlig'], 0);
  });

  test('TerminalStyle.fromTextStyle carries a ligature request over', () {
    expect(
      TerminalStyle.fromTextStyle(const TextStyle()).enableLigatures,
      isFalse,
    );
    expect(
      TerminalStyle.fromTextStyle(
        const TextStyle(fontFeatures: [ui.FontFeature.disable('liga')]),
      ).enableLigatures,
      isFalse,
    );
    expect(
      TerminalStyle.fromTextStyle(
        const TextStyle(fontFeatures: [ui.FontFeature.enable('calt')]),
      ).enableLigatures,
      isTrue,
    );
  });

  test('TerminalStyle equality accounts for ligatures', () {
    const plain = TerminalStyle();
    final ligated = plain.copyWith(enableLigatures: true);

    expect(ligated.enableLigatures, isTrue);
    expect(ligated == plain, isFalse);
    expect(ligated.hashCode == plain.hashCode, isFalse);
    expect(ligated.copyWith(), equals(ligated));
  });

  test('ligature runs cover only mergeable neighbouring cells', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(enableLigatures: true),
      textScaler: TextScaler.noScaling,
    );

    final terminal = Terminal()
      ..resize(20, 1)
      ..write('a<=>b ===');
    final line = terminal.buffer.lines[0];

    // Letters never take part in a run, punctuation runs stop at them.
    expect(painter.ligatureRunCellSpan(line, 0), 1);
    expect(painter.ligatureRunCellSpan(line, 1), 3);
    expect(painter.ligatureRunCellSpan(line, 4), 1);
    expect(painter.ligatureRunCellSpan(line, 6), 3);

    // The cursor cell is repainted in an inverted color, so it always splits.
    expect(painter.ligatureRunCellSpan(line, 1, cursorColumn: 1), 1);
    expect(painter.ligatureRunCellSpan(line, 1, cursorColumn: 2), 1);
    expect(painter.ligatureRunCellSpan(line, 1, cursorColumn: 3), 2);

    painter.dispose();
  });

  test('ligature runs stop where cell attributes change', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(enableLigatures: true),
      textScaler: TextScaler.noScaling,
    );

    final recolored = Terminal()
      ..resize(20, 1)
      ..write('=\x1b[31m==');
    expect(painter.ligatureRunCellSpan(recolored.buffer.lines[0], 0), 1);
    expect(painter.ligatureRunCellSpan(recolored.buffer.lines[0], 1), 2);

    final bolded = Terminal()
      ..resize(20, 1)
      ..write('=\x1b[1m==');
    expect(painter.ligatureRunCellSpan(bolded.buffer.lines[0], 0), 1);

    // Blinking cells are skipped during the off phase rather than painted.
    final blinking = Terminal()
      ..resize(20, 1)
      ..write('\x1b[5m===');
    expect(painter.ligatureRunCellSpan(blinking.buffer.lines[0], 0), 1);

    painter.dispose();
  });

  test('ligature runs are bounded in length', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(enableLigatures: true),
      textScaler: TextScaler.noScaling,
    );

    final terminal = Terminal()
      ..resize(40, 1)
      ..write('=' * 30);
    expect(painter.ligatureRunCellSpan(terminal.buffer.lines[0], 0), 8);

    painter.dispose();
  });

  test('ligature runs keep the cell grid when the font has no ligatures',
      () async {
    final terminal = Terminal()
      ..resize(12, 1)
      ..write('a => b != c');

    final plainPainter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final ligaturePainter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(
        fontSize: 20,
        height: 1,
        enableLigatures: true,
      ),
      textScaler: TextScaler.noScaling,
    );

    final plainImage = await _paintLine(
      plainPainter,
      terminal.buffer.lines[0],
    );
    final ligatureImage = await _paintLine(
      ligaturePainter,
      terminal.buffer.lines[0],
    );

    final plainBytes = await plainImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    final ligatureBytes = await ligatureImage.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    plainImage.dispose();
    ligatureImage.dispose();
    if (plainBytes == null || ligatureBytes == null) {
      fail('Expected rendered bytes');
    }

    // The test font ships no ligatures, so shaping a run must land every glyph
    // exactly where the per-cell path puts it, pixel for pixel. A run that does
    // not fill its cells is rejected before it can be drawn, so either way the
    // grid is identical.
    expect(
      ligatureBytes.buffer.asUint8List(),
      equals(plainBytes.buffer.asUint8List()),
    );

    // Runs must never cost more paragraph cache slots than the cells they
    // replace, whether they are drawn or rejected.
    expect(
      ligaturePainter.paragraphCacheLength,
      lessThanOrEqualTo(plainPainter.paragraphCacheLength),
    );

    plainPainter.dispose();
    ligaturePainter.dispose();
  });

  test('TerminalPainter bounds its rejected ligature run set', () {
    // A devicePixelRatio far below 1 makes snapToDevicePixels clamp the
    // measured cell size to a value wildly larger than any real glyph
    // advance (cellSize below), so every multi-cell run is rejected: the
    // shaped paragraph never comes close to filling `cellSize.width *
    // length`. That turns rejection into a deterministic, engine-agnostic
    // way to drive the rejected-run set, instead of relying on incidental
    // font kerning.
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(enableLigatures: true),
      textScaler: TextScaler.noScaling,
      devicePixelRatio: 0.011,
    );
    expect(painter.cellSize.width, greaterThan(50));

    const punctuation = '!#&*+-./:;<=>?\\^_|~';
    final texts = <String>[];
    for (var a = 0; a < punctuation.length; a++) {
      for (var b = 0; b < punctuation.length; b++) {
        texts.add(punctuation[a] + punctuation[b]);
      }
    }
    outer:
    for (var a = 0; a < punctuation.length; a++) {
      for (var b = 0; b < punctuation.length; b++) {
        for (var c = 0; c < punctuation.length; c++) {
          texts.add(punctuation[a] + punctuation[b] + punctuation[c]);
          if (texts.length >= 700) break outer;
        }
      }
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    for (final text in texts) {
      final terminal = Terminal()
        ..resize(9, 1)
        ..write(text);
      painter.paintLineForegrounds(
        canvas,
        Offset.zero,
        terminal.buffer.lines[0],
      );
    }
    recorder.endRecording().dispose();

    // None of the 700 runs shaped into something that fills its cells, so
    // every one of them went through the rejection path rather than adding a
    // run-keyed entry to the paragraph cache: only the single-cell entries
    // for the 20-character punctuation alphabet are present.
    expect(painter.paragraphCacheLength, lessThanOrEqualTo(punctuation.length));

    // 700 distinct run texts (plus the suffix runs the per-cell fallback
    // re-attempts after each rejection) comfortably exceed the 512-entry
    // bound, so without the wholesale clear this would settle at whatever
    // count of distinct rejections that traffic produced. With it, the set
    // never grows past its bound.
    expect(painter.rejectedLigatureRunsLength, lessThanOrEqualTo(512));

    painter.dispose();
  });

  test('symbol glyphs can extend into an adjacent blank cell', () {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(),
      textScaler: TextScaler.noScaling,
    );

    final trailingBlank = Terminal()
      ..resize(2, 1)
      ..write('\uE000 ');
    expect(
      painter.glyphConstraintCellSpan(trailingBlank.buffer.lines[0], 0),
      2,
    );

    final trailingEnSpace = Terminal()
      ..resize(2, 1)
      ..write('\uE000\u2002');
    expect(
      painter.glyphConstraintCellSpan(trailingEnSpace.buffer.lines[0], 0),
      2,
    );

    final trailingText = Terminal()
      ..resize(2, 1)
      ..write('\uE000X');
    expect(
      painter.glyphConstraintCellSpan(trailingText.buffer.lines[0], 0),
      1,
    );

    final finalColumn = Terminal()
      ..resize(2, 1)
      ..write('X\uE000');
    expect(
      painter.glyphConstraintCellSpan(finalColumn.buffer.lines[0], 1),
      1,
    );

    final adjacentSymbols = Terminal()
      ..resize(3, 1)
      ..write('\uE000\uE001 ');
    expect(
      painter.glyphConstraintCellSpan(adjacentSymbols.buffer.lines[0], 0),
      1,
    );
    expect(
      painter.glyphConstraintCellSpan(adjacentSymbols.buffer.lines[0], 1),
      1,
    );

    final afterPowerline = Terminal()
      ..resize(3, 1)
      ..write('\uE0B0\uE000 ');
    expect(
      painter.glyphConstraintCellSpan(afterPowerline.buffer.lines[0], 1),
      2,
    );

    final ordinaryText = Terminal()
      ..resize(2, 1)
      ..write('A ');
    expect(
      painter.glyphConstraintCellSpan(ordinaryText.buffer.lines[0], 0),
      1,
    );

    final wideGlyph = Terminal()
      ..resize(2, 1)
      ..write('😀');
    expect(
      painter.glyphConstraintCellSpan(wideGlyph.buffer.lines[0], 0),
      2,
    );

    painter.dispose();
  });

  test('TerminalStyle compares values deeply', () {
    const style = TerminalStyle(
      fontSize: 14,
      height: 1.1,
      fontFamily: 'Mono',
      fontFamilyFallback: ['A', 'B'],
      drawBoldTextWithBrightColors: false,
    );

    expect(
      style,
      const TerminalStyle(
        fontSize: 14,
        height: 1.1,
        fontFamily: 'Mono',
        fontFamilyFallback: ['A', 'B'],
        drawBoldTextWithBrightColors: false,
      ),
    );
    expect(style.copyWith(fontFamilyFallback: ['A', 'C']), isNot(style));
    expect(style.copyWith(drawBoldTextWithBrightColors: true), isNot(style));
  });

  test('paintLine strikes through procedural glyphs', () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final line = BufferLine(1);
    final style = CursorStyle()..setStrikethrough();
    line.setCell(0, 0x2502, 1, style);

    final image = await _paintLine(painter, line);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final byteData = bytes;
    if (byteData == null) {
      fail('Expected line image bytes');
    }

    final strikeY = (painter.cellSize.height / 2).round();
    expect(_hasAlphaNear(byteData, image.width, 1, strikeY), isTrue);

    image.dispose();
  });

  test('paintLine spans decorations across wide procedural glyphs', () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final line = BufferLine(2);
    final style = CursorStyle()..setStrikethrough();
    line.setCell(0, 0x2500, 2, style);

    final image = await _paintLine(painter, line);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final byteData = bytes;
    if (byteData == null) {
      fail('Expected line image bytes');
    }

    final strikeY = (painter.cellSize.height / 2).round();
    final secondCellX = painter.cellSize.width.floor() + 1;
    expect(_hasAlphaNear(byteData, image.width, secondCellX, strikeY), isTrue);

    image.dispose();
  });

  test('paintLine renders dotted underlines for procedural glyphs', () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final line = BufferLine(1);
    final style = CursorStyle()..setDottedUnderline();
    line.setCell(0, 0x2500, 1, style);

    final image = await _paintLine(painter, line);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final byteData = bytes;
    if (byteData == null) {
      fail('Expected line image bytes');
    }

    final underlineY = painter.cellSize.height.round() - 1;
    final paintedColumns = _paintedColumnCount(
      byteData,
      image.width,
      underlineY,
      painter.cellSize.width.floor(),
    );
    expect(paintedColumns, greaterThan(0));
    expect(paintedColumns, lessThan(painter.cellSize.width.floor()));

    image.dispose();
  });

  test('paintLine skips invisible cell foregrounds', () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final line = BufferLine(1);
    final style = CursorStyle()..setInvisible();
    line.setCell(0, 'X'.codeUnitAt(0), 1, style);

    final image = await _paintLine(painter, line);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final byteData = bytes;
    if (byteData == null) {
      fail('Expected line image bytes');
    }

    expect(_hasAnyAlpha(byteData, image.width, image.height), isFalse);

    image.dispose();
  });

  test('paintLine keeps braille pattern blank invisible', () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final terminal = Terminal()..write('\u2800');

    expect(terminal.buffer.cursorX, 1);
    expect(painter.paragraphCacheLength, 0);

    final image = await _paintLine(painter, terminal.buffer.lines[0]);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final byteData = bytes;
    if (byteData == null) {
      fail('Expected line image bytes');
    }

    expect(_hasAnyAlpha(byteData, image.width, image.height), isFalse);
    expect(painter.paragraphCacheLength, 0);

    image.dispose();
    painter.dispose();
  });

  test('paintLine renders decorations across blank cells', () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final line = BufferLine(3);
    final underlineStyle = CursorStyle()..setUnderline();
    final strikeStyle = CursorStyle()..setStrikethrough();
    final overlineStyle = CursorStyle()..setOverline();
    line.setCell(0, 0x20, 1, underlineStyle);
    line.setCell(1, 0x20, 1, strikeStyle);
    line.setCell(2, 0x2800, 1, overlineStyle);

    final image = await _paintLine(painter, line);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final byteData = bytes;
    if (byteData == null) {
      fail('Expected line image bytes');
    }

    final cellWidth = painter.cellSize.width;
    final underlineX = (cellWidth / 2).round();
    final strikeX = (cellWidth * 1.5).round();
    final overlineX = (cellWidth * 2.5).round();
    expect(
      _hasAlphaNear(
        byteData,
        image.width,
        underlineX,
        painter.cellSize.height.round() - 1,
      ),
      isTrue,
    );
    expect(
      _hasAlphaNear(
        byteData,
        image.width,
        strikeX,
        (painter.cellSize.height / 2).round(),
      ),
      isTrue,
    );
    expect(_alphaAt(byteData, image.width, overlineX, 0), greaterThan(0));
    expect(painter.paragraphCacheLength, 0);

    image.dispose();
    painter.dispose();
  });

  test('paintLine renders framed and encircled SGR decorations', () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final line = BufferLine(2);
    final frameStyle = CursorStyle()..setFramed();
    final circleStyle = CursorStyle()..setEncircled();
    line.setCell(0, 0x20, 1, frameStyle);
    line.setCell(1, 0x20, 1, circleStyle);

    final image = await _paintLine(painter, line);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final byteData = bytes;
    if (byteData == null) {
      fail('Expected line image bytes');
    }

    final cellWidth = painter.cellSize.width.ceil();
    final cellHeight = painter.cellSize.height.ceil();
    expect(
      _hasAnyAlphaInRect(byteData, image.width, 0, 0, cellWidth, cellHeight),
      isTrue,
    );
    expect(
      _hasAnyAlphaInRect(
        byteData,
        image.width,
        cellWidth,
        0,
        cellWidth * 2,
        cellHeight,
      ),
      isTrue,
    );
    expect(painter.paragraphCacheLength, 0);

    image.dispose();
    painter.dispose();
  });

  test('paintLine batches same-color backgrounds without seams', () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final line = BufferLine(4);
    for (var i = 0; i < line.length; i++) {
      line.setBackground(i, CellColor.rgb | 0x123456);
    }

    final image = await _paintLine(painter, line);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final byteData = bytes;
    if (byteData == null) {
      fail('Expected line image bytes');
    }

    final paintedWidth = (painter.cellSize.width * line.length).ceil();
    final y = (painter.cellSize.height / 2).round();
    for (var x = 0; x < paintedWidth; x++) {
      final alpha = _alphaAt(byteData, image.width, x, y);
      expect(alpha, greaterThan(0));
    }

    image.dispose();
  });

  test('paintLine backgrounds do not bleed into transparent cells', () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    final line = BufferLine(2)..setBackground(0, CellColor.rgb | 0x123456);

    final image = await _paintLine(painter, line);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final byteData = bytes;
    if (byteData == null) {
      fail('Expected line image bytes');
    }

    final transparentCellX = painter.cellSize.width.ceil();
    final y = (painter.cellSize.height / 2).round();
    expect(_alphaAt(byteData, image.width, transparentCellX, y), 0);

    image.dispose();
    painter.dispose();
  });

  test('underline cursor is painted at the requested row offset', () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    const offset = ui.Offset(10, 20);

    final image = await _paintCursor(
      painter,
      offset,
      TerminalCursorType.underline,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final byteData = bytes;
    if (byteData == null) {
      fail('Expected cursor image bytes');
    }

    final expectedY = (offset.dy + painter.cellSize.height - 1).round();
    expect(
      _hasAlphaInRow(byteData, image.width, expectedY),
      isTrue,
    );
    expect(
      _hasAlphaInRow(byteData, image.width, expectedY - 1),
      isTrue,
    );
    expect(
      _hasAlphaInRow(
          byteData, image.width, painter.cellSize.height.round() - 1),
      isFalse,
    );

    image.dispose();
  });

  test('vertical bar cursor is painted at the requested row offset', () async {
    final painter = TerminalPainter(
      theme: TerminalThemes.whiteOnBlack,
      textStyle: const TerminalStyle(fontSize: 20, height: 1),
      textScaler: TextScaler.noScaling,
    );
    const offset = ui.Offset(10, 20);

    final image = await _paintCursor(
      painter,
      offset,
      TerminalCursorType.verticalBar,
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final byteData = bytes;
    if (byteData == null) {
      fail('Expected cursor image bytes');
    }

    final expectedX = offset.dx.round();
    expect(
      _hasAlphaInColumn(byteData, image.width, expectedX, offset.dy.round()),
      isTrue,
    );
    expect(
      _hasAlphaInColumn(
          byteData, image.width, expectedX + 1, offset.dy.round()),
      isTrue,
    );
    expect(
      _hasAlphaInColumn(byteData, image.width, expectedX, 0),
      isFalse,
    );

    image.dispose();
  });
}

Future<ui.Image> _paintCursor(
  TerminalPainter painter,
  ui.Offset offset,
  TerminalCursorType cursorType, {
  int cellWidth = 1,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  painter.paintCursor(
    canvas,
    offset,
    cursorType: cursorType,
    cellWidth: cellWidth,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(80, 80);
  picture.dispose();
  return image;
}

Future<ui.Image> _paintLine(TerminalPainter painter, BufferLine line,
    {int? activeHyperlinkId}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  painter.paintLine(
    canvas,
    ui.Offset.zero,
    line,
    activeHyperlinkId: activeHyperlinkId,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(120, 40);
  picture.dispose();
  return image;
}

bool _hasAlphaInRow(ByteData byteData, int width, int y) {
  for (var x = 0; x < width; x++) {
    final alpha = _alphaAt(byteData, width, x, y);
    if (alpha != 0) {
      return true;
    }
  }
  return false;
}

bool _hasAlphaInColumn(ByteData byteData, int width, int x, int startY) {
  for (var y = startY; y < startY + 20; y++) {
    final alpha = _alphaAt(byteData, width, x, y);
    if (alpha != 0) {
      return true;
    }
  }
  return false;
}

int _alphaAt(ByteData byteData, int width, int x, int y) {
  return byteData.getUint8((y * width + x) * 4 + 3);
}

bool _hasAnyAlpha(ByteData byteData, int width, int height) {
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (_alphaAt(byteData, width, x, y) != 0) {
        return true;
      }
    }
  }
  return false;
}

bool _hasAnyAlphaInRect(
  ByteData byteData,
  int imageWidth,
  int left,
  int top,
  int right,
  int bottom,
) {
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      if (_alphaAt(byteData, imageWidth, x, y) != 0) return true;
    }
  }
  return false;
}

bool _hasAlphaNear(ByteData byteData, int width, int x, int y) {
  for (var offsetY = -1; offsetY <= 1; offsetY++) {
    if (_alphaAt(byteData, width, x, y + offsetY) != 0) {
      return true;
    }
  }
  return false;
}

int _paintedColumnCount(ByteData byteData, int width, int y, int endX) {
  var count = 0;
  for (var x = 0; x < endX; x++) {
    if (_alphaAt(byteData, width, x, y) != 0) {
      count++;
    }
  }
  return count;
}
