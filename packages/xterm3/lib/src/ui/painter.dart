import 'dart:math' show max, min;
import 'dart:ui';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart';

import 'package:xterm3/src/ui/palette_builder.dart';
import 'package:xterm3/src/ui/paragraph_cache.dart';
import 'package:xterm3/src/ui/procedural_glyph_cache.dart';
import 'package:xterm3/src/ui/procedural_glyphs.dart';
import 'package:xterm3/xterm.dart';

const _dimColorFactor = 0.66;
const _specialBoldColor = 0;
const _specialUnderlineColor = 1;
const _specialBlinkColor = 2;
const _specialReverseColor = 3;
const _specialItalicColor = 4;
const _defaultParagraphCacheSize = 2048;

/// Entries in the procedural glyph cache.
///
/// Keys are (codepoint, cell size, colour), so a screen that draws box lines
/// in many colours multiplies the glyph count by the palette in use - the
/// benchmark's `boxdraw` workload alone reaches 3840 live keys. This has to
/// stay comfortably above what one screen can reference, because a miss is
/// strictly more expensive than not caching at all: it pays for the recording
/// and the insert on top of the drawing. At 512 the cache thrashed at 8500
/// cells and cost 1.9ms of UI time per frame *over* painting uncached.
const _defaultProceduralGlyphCacheSize = 4096;

/// Upper bound on the number of cells a single shaped ligature run may cover.
///
/// No programming ligature is longer than this, and the bound matters because
/// run cache keys carry the run text: without it the key space, and therefore
/// the paragraph cache turnover, would be unbounded.
const _maxLigatureRunLength = 8;

/// Tolerance, in logical pixels, when checking a shaped run against the width
/// of the cells it covers. Shaping is exact for the fonts this path targets;
/// the epsilon only absorbs accumulated floating point error.
///
/// Cell width is snapped to the device pixel grid, so it can sit up to half a
/// device pixel away from the font's natural advance. A run is drawn as one
/// paragraph at the font's own advances, so that difference accumulates across
/// the run: keeping the tolerance tight means a long run whose glyphs would
/// drift off the cell grid is rejected here and painted cell by cell instead.
const _ligatureAdvanceEpsilon = 0.5;

/// Upper bound on the number of entries in [TerminalPainter._rejectedLigatureRuns].
///
/// The key space is nominally huge — up to 8 punctuation characters drawn
/// from the ~20 accepted by [_isLigatureCandidate], times 4 face-flag
/// combinations — but real content only ever produces a few dozen distinct
/// runs (operators like `->`, `=>`, `==`, `&&`, comment borders, and the
/// like). 512 sits comfortably above that working set while still being
/// small enough that a wholesale clear, on the rare content that keeps
/// generating new runs, is cheap and rare. Overflow is never a correctness
/// issue: an evicted rejection is rediscovered the next time its run is
/// shaped, which costs exactly the one extra layout the entry existed to
/// avoid.
const _maxRejectedLigatureRuns = 512;

/// Whether [codePoint] may take part in a ligature.
///
/// Restricted to the ASCII punctuation that programming ligatures are built
/// from. Letters and digits are excluded, so ordinary text never leaves the
/// per-cell painting path.
bool _isLigatureCandidate(int codePoint) {
  return switch (codePoint) {
    0x21 || // !
    0x23 || // #
    0x26 || // &
    0x2a || // *
    0x2b || // +
    0x2d || // -
    0x2e || // .
    0x2f || // /
    0x3a || // :
    0x3b || // ;
    0x3c || // <
    0x3d || // =
    0x3e || // >
    0x3f || // ?
    0x5c || // \
    0x5e || // ^
    0x5f || // _
    0x7c || // |
    0x7e // ~
      =>
      true,
    _ => false,
  };
}

bool _isSymbolLike(int codePoint) {
  return switch (codePoint) {
    >= 0x2190 && <= 0x21FF => true,
    >= 0x2460 && <= 0x24FF => true,
    >= 0x2600 && <= 0x27BF => true,
    >= 0xE000 && <= 0xF8FF => true,
    >= 0x1F100 && <= 0x1F1FF => true,
    >= 0x1F300 && <= 0x1F6FF => true,
    >= 0xF0000 && <= 0xFFFFD => true,
    >= 0x100000 && <= 0x10FFFD => true,
    _ => false,
  };
}

bool _isGraphicsElement(int codePoint) {
  return switch (codePoint) {
    >= 0x2500 && <= 0x259F => true,
    >= 0xE0B0 && <= 0xE0D7 => true,
    >= 0x1FB00 && <= 0x1FBFF => true,
    >= 0x1CC00 && <= 0x1CEBF => true,
    _ => false,
  };
}

/// Encapsulates the logic for painting various terminal elements.
class TerminalPainter {
  TerminalPainter({
    required TerminalTheme theme,
    required TerminalStyle textStyle,
    required TextScaler textScaler,
    double devicePixelRatio = 1.0,
    int paragraphCacheSize = _defaultParagraphCacheSize,
    int proceduralGlyphCacheSize = _defaultProceduralGlyphCacheSize,
  })  : _textStyle = textStyle,
        _theme = theme,
        _textScaler = textScaler,
        _devicePixelRatio = devicePixelRatio,
        _minParagraphCacheSize = paragraphCacheSize,
        _paragraphCache = ParagraphCache(paragraphCacheSize),
        _proceduralGlyphCache = ProceduralGlyphCache(proceduralGlyphCacheSize);

  /// A lookup table from terminal colors to Flutter colors.
  late var _colorPalette = PaletteBuilder(_theme).build();

  /// Size of each character in the terminal.
  late var _cellSize = _measureCharSize();

  /// The cached for cells in the terminal. Should be cleared when the same
  /// cell no longer produces the same visual output. For example, when
  /// [_textStyle] is changed, or when the system font changes.
  final ParagraphCache _paragraphCache;

  final int _minParagraphCacheSize;

  /// Sizes the paragraph cache so that one screen of [columns] x [rows] fits.
  ///
  /// Keys carry the cell's colour, so a screen where most cells differ in
  /// colour - a truecolor gradient, 256-colour output - needs about one entry
  /// per cell. A cache smaller than that does not degrade, it stops working:
  /// cells are looked up in the same order every frame, so each frame evicts
  /// what the next one needs, and at a fixed 2048 entries an 8060-cell screen
  /// laid out 8060 paragraphs on every repaint, cursor blink included. The
  /// quarter on top keeps the eviction batch from cutting into a full screen.
  void fitParagraphCacheToGrid(int columns, int rows) {
    final cells = columns * (rows + 1);
    final size = max(_minParagraphCacheSize, cells + (cells >> 2));
    if (size != _paragraphCache.maximumSize) {
      _paragraphCache.maximumSize = size;
    }
  }

  /// Cache of rasterised procedural glyphs (box-drawing, Powerline, Braille).
  /// Should be invalidated at the same points as [_paragraphCache]: anything
  /// that changes the cell size or the resolved fill color changes what a
  /// given (codepoint, cell size, color) key should rasterise to.
  final ProceduralGlyphCache _proceduralGlyphCache;

  /// Reused during cell painting to avoid allocating objects per visible cell.
  ///
  /// Cell rectangles are snapped to the device pixel grid through [_cellSize],
  /// so antialiasing on those fills would only produce half covered pixels at
  /// cell boundaries. Procedural glyphs are already drawn without it; keeping
  /// backgrounds, highlights and the cursor aliased as well makes both sides of
  /// every cell boundary land on the same pixel.
  final _foregroundPaint = Paint();
  final _backgroundPaint = Paint()..isAntiAlias = false;
  final _decorationPaint = Paint();
  final _highlightPaint = Paint()..isAntiAlias = false;
  final _cursorPaint = Paint()..isAntiAlias = false;

  /// Scratch cell shared by [paintLineBackgrounds] and [paintLineForegrounds].
  /// Both fully overwrite every field through [BufferLine.getCellData] before
  /// reading it and consume the result before advancing, so one instance is
  /// enough. Those two methods must therefore never be nested inside one
  /// another.
  final _scratchCellData = CellData.empty();

  /// Scratch cell used only to look ahead while measuring a ligature run.
  /// Kept separate from [_scratchCellData] because the lookahead happens while
  /// the painting loop still holds the current cell there.
  final _scratchLookaheadCellData = CellData.empty();

  /// Run texts already known not to shape into a grid-aligned ligature, keyed
  /// together with the attributes that select a font face.
  ///
  /// Without this a font that ships no ligatures would insert one paragraph
  /// per rejected run into [_paragraphCache], where it would never be drawn
  /// yet keep competing with the single-cell entries for slots. Validity
  /// depends on the resolved font, so this is cleared wherever the cache is.
  ///
  /// Bounded by [_maxRejectedLigatureRuns] at the one add site: unlike
  /// [_paragraphCache], which is bounded by a per-key LRU because a cache
  /// miss there is expensive, a dropped rejection here only costs one
  /// re-layout of that run — precisely what the entry was avoiding — so a
  /// plain wholesale clear on overflow is enough.
  final _rejectedLigatureRuns = <(String, int)>{};

  final Map<int, Color> _indexedColorOverrides = {};
  final Map<int, Color> _specialColorOverrides = {};

  int _colorRevision = -1;

  Object? _colorSource;

  Color? _foregroundColorOverride;

  Color? _backgroundColorOverride;

  Color? _cursorColorOverride;

  Color? _selectionColorOverride;

  Color? _selectionForegroundColorOverride;

  TerminalStyle get textStyle => _textStyle;
  TerminalStyle _textStyle;
  set textStyle(TerminalStyle value) {
    if (value == _textStyle) return;
    _textStyle = value;
    _cellSize = _measureCharSize();
    _clearParagraphCache();
  }

  TextScaler get textScaler => _textScaler;
  TextScaler _textScaler = TextScaler.linear(1.0);
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _cellSize = _measureCharSize();
    _clearParagraphCache();
  }

  /// Ratio between logical pixels and physical device pixels. Used to snap
  /// [cellSize] onto the device pixel grid so that every cell occupies the
  /// exact same number of physical pixels.
  double get devicePixelRatio => _devicePixelRatio;
  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
    _proceduralGlyphCache.clear();
  }

  /// Rounds [value] to a whole number of device pixels, expressed back in
  /// logical pixels. Never returns less than a single device pixel.
  double snapToDevicePixels(double value) {
    final ratio = _devicePixelRatio;
    if (!ratio.isFinite || ratio <= 0) return value;
    return max(1.0, (value * ratio).roundToDouble()) / ratio;
  }

  TerminalTheme get theme => _theme;
  TerminalTheme _theme;
  set theme(TerminalTheme value) {
    if (value == _theme) return;
    _theme = value;
    _colorPalette = PaletteBuilder(value).build();
    _clearParagraphCache();
  }

  bool get reverseDisplay => _reverseDisplay;
  bool _reverseDisplay = false;
  set reverseDisplay(bool value) {
    if (value == _reverseDisplay) return;
    _reverseDisplay = value;
    _clearParagraphCache();
  }

  /// Drops everything derived from the current font and colors. The rejected
  /// run set is invalidated together with the paragraph cache: a run rejected
  /// under one font may well ligate under the next.
  void _clearParagraphCache() {
    _paragraphCache.clear();
    _proceduralGlyphCache.clear();
    _rejectedLigatureRuns.clear();
  }

  Size _measureCharSize() {
    final textStyle = _textStyle.toTextStyle();
    final paragraphStyle = textStyle.getParagraphStyle();
    final textStyleRun = textStyle.getTextStyle(textScaler: _textScaler);

    // Width comes from '0' alone, not the max advance over the whole ASCII
    // range. On a true monospace font every glyph has the same advance, so
    // it made no difference which one we asked for; on a proportional font
    // (e.g. a user-selected UI font like Inter) the widest glyphs ('@', 'W',
    // 'M') are dramatically wider than the rest, and sizing the cell to fit
    // them produces a grid with far too few columns. '0' is the reference
    // glyph other terminals key off for the same reason: it is present in
    // (near-)every font and monospace fonts deliberately give digits the
    // same advance as the rest of the glyph set. Height still takes the max
    // over a small sample: the row must be tall enough for the tallest
    // glyph a line can contain, and ascenders/descenders vary far less than
    // horizontal advance does.
    const widthGlyph = '0';
    const heightSampleGlyphs = [widthGlyph, 'M', 'g'];
    var width = 0.0;
    var height = 0.0;
    for (final glyph in heightSampleGlyphs) {
      final builder = ParagraphBuilder(paragraphStyle);
      builder.pushStyle(textStyleRun);
      builder.addText(glyph);

      final paragraph = builder.build();
      paragraph.layout(ParagraphConstraints(width: double.infinity));
      if (glyph == widthGlyph) width = paragraph.maxIntrinsicWidth;
      height = max(height, paragraph.height);
      paragraph.dispose();
    }

    // Measured advances are almost never a whole number of device pixels. Left
    // unsnapped, `column * cellWidth` lands on a different subpixel phase in
    // every column: aliased fills (procedural block glyphs) then round each
    // column differently and neighbouring blocks end up one device pixel apart,
    // while glyphs get rasterized at a different phase per cell. Snapping the
    // metrics makes every cell cover an identical pixel run.
    return Size(snapToDevicePixels(width), snapToDevicePixels(height));
  }

  /// The size of each character in the terminal.
  Size get cellSize => _cellSize;

  int get paragraphCacheLength => _paragraphCache.length;

  int get proceduralGlyphCacheLength => _proceduralGlyphCache.length;

  /// Exposed for tests: the number of run texts currently remembered as not
  /// shaping into a grid-aligned ligature.
  @visibleForTesting
  int get rejectedLigatureRunsLength => _rejectedLigatureRuns.length;

  int glyphConstraintCellSpan(BufferLine line, int column) {
    final gridWidth = line.getWidth(column);
    if (gridWidth > 1) return gridWidth;

    final codePoint = line.getCodePoint(column);
    if (!_isSymbolLike(codePoint)) return 1;
    if (column + 1 >= line.length) return 1;

    if (column > 0) {
      final previous = line.getCodePoint(column - 1);
      if (_isSymbolLike(previous) && !_isGraphicsElement(previous)) return 1;
    }

    final next = line.getCodePoint(column + 1);
    if (next == 0 || next == 0x20 || next == 0x2002) return 2;
    return 1;
  }

  Color get foregroundColor => _foregroundColorOverride ?? _theme.foreground;

  Color get backgroundColor => _backgroundColorOverride ?? _theme.background;

  Color get cursorColor => _cursorColorOverride ?? _theme.cursor;

  Color get selectionColor => _selectionColorOverride ?? _theme.selection;

  Color? get selectionForegroundColor => _selectionForegroundColorOverride;

  Color get searchHitBackgroundColor => _theme.searchHitBackground;

  Color get searchHitBackgroundCurrentColor =>
      _theme.searchHitBackgroundCurrent;

  Color get searchHitForegroundColor => _theme.searchHitForeground;

  Color get cursorLineHighlightColor => selectionColor.withValues(alpha: 0.18);

  Color? get backgroundColorOverride => _backgroundColorOverride;

  void updateColorOverrides(
    Object source,
    int revision,
    Iterable<MapEntry<int, int>> indexedColors,
    Iterable<MapEntry<int, int>> specialColors,
    int? foreground,
    int? background,
    int? cursor,
    int? selection,
    int? selectionForeground,
  ) {
    if (identical(_colorSource, source) && _colorRevision == revision) return;
    _colorSource = source;
    _colorRevision = revision;
    _indexedColorOverrides
      ..clear()
      ..addEntries(indexedColors.map(
        (entry) => MapEntry(entry.key, Color(0xff000000 | entry.value)),
      ));
    _specialColorOverrides
      ..clear()
      ..addEntries(specialColors.map(
        (entry) => MapEntry(entry.key, Color(0xff000000 | entry.value)),
      ));
    _foregroundColorOverride = switch (foreground) {
      final value? => Color(0xff000000 | value),
      null => null,
    };
    _backgroundColorOverride = switch (background) {
      final value? => Color(0xff000000 | value),
      null => null,
    };
    _cursorColorOverride = switch (cursor) {
      final value? => Color(0xff000000 | value),
      null => null,
    };
    _selectionColorOverride = switch (selection) {
      final value? => Color(0xff000000 | value),
      null => null,
    };
    _selectionForegroundColorOverride = switch (selectionForeground) {
      final value? => Color(0xff000000 | value),
      null => null,
    };
    _clearParagraphCache();
  }

  /// When the set of font available to the system changes, call this method to
  /// clear cached state related to font rendering.
  void clearFontCache() {
    _cellSize = _measureCharSize();
    _clearParagraphCache();
  }

  void dispose() {
    _clearParagraphCache();
    _paragraphCache.dispose();
    _proceduralGlyphCache.dispose();
  }

  /// Paints the cursor based on the current cursor type.
  void paintCursor(
    Canvas canvas,
    Offset offset, {
    required TerminalCursorType cursorType,
    bool hasFocus = true,
    int cellWidth = 1,
    Color? color,
  }) {
    final cursorSize = Size(_cellSize.width * cellWidth, _cellSize.height);
    final paint = _cursorPaint
      ..color = color ?? cursorColor
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;

    if (!hasFocus) {
      paint.style = PaintingStyle.stroke;
      canvas.drawRect(offset & cursorSize, paint);
      return;
    }

    switch (cursorType) {
      case TerminalCursorType.block:
        paint.style = PaintingStyle.fill;
        canvas.drawRect(offset & cursorSize, paint);
        return;
      case TerminalCursorType.underline:
        final underlineHeight = max(2.0, _cellSize.height * 0.12);
        return canvas.drawRect(
          Rect.fromLTWH(
            offset.dx,
            offset.dy + _cellSize.height - underlineHeight,
            cursorSize.width,
            underlineHeight,
          ),
          paint,
        );
      case TerminalCursorType.verticalBar:
        final barWidth = max(2.0, _cellSize.width * 0.2);
        return canvas.drawRect(
          Rect.fromLTWH(offset.dx, offset.dy, barWidth, _cellSize.height),
          paint,
        );
    }
  }

  @pragma('vm:prefer-inline')
  void paintHighlight(Canvas canvas, Offset offset, int length, Color color) {
    final endOffset =
        offset.translate(length * _cellSize.width, _cellSize.height);

    final paint = _highlightPaint
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromPoints(offset, endOffset),
      paint,
    );
  }

  /// Paints [line] to [canvas] at [offset]. The x offset of [offset] is usually
  /// 0, and the y offset is the top of the line.
  bool paintLine(
    Canvas canvas,
    Offset offset,
    BufferLine line, {
    bool blinkVisible = true,
    int? activeHyperlinkId,
  }) {
    paintLineBackgrounds(canvas, offset, line);
    return paintLineForegrounds(
      canvas,
      offset,
      line,
      blinkVisible: blinkVisible,
      activeHyperlinkId: activeHyperlinkId,
    );
  }

  void paintLineBackgrounds(
    Canvas canvas,
    Offset offset,
    BufferLine line,
  ) {
    final cellData = _scratchCellData;

    var backgroundRunStart = 0;
    var backgroundRunEnd = 0;
    Color? backgroundRunColor;

    for (var i = 0; i < line.length; i++) {
      line.getCellData(i, cellData, includeUnderlineColor: false);

      final charWidth = cellData.content >> CellContent.widthShift;
      final cellSpan = switch (charWidth == 2) {
        true => 2,
        false => 1,
      };
      final color = resolveCellBackgroundColor(cellData);
      final runColor = backgroundRunColor;

      if (color == null) {
        if (runColor != null) {
          paintBackgroundRun(
            canvas,
            offset,
            backgroundRunStart,
            backgroundRunEnd,
            runColor,
          );
        }
        backgroundRunColor = null;
        backgroundRunStart = i + cellSpan;
        backgroundRunEnd = backgroundRunStart;

        if (charWidth == 2) {
          i++;
        }
        continue;
      }

      if (runColor != null && runColor == color && backgroundRunEnd == i) {
        backgroundRunEnd += cellSpan;

        if (charWidth == 2) {
          i++;
        }
        continue;
      }

      if (runColor != null) {
        paintBackgroundRun(
          canvas,
          offset,
          backgroundRunStart,
          backgroundRunEnd,
          runColor,
        );
      }

      backgroundRunColor = color;
      backgroundRunStart = i;
      backgroundRunEnd = i + cellSpan;

      if (charWidth == 2) {
        i++;
      }
    }

    final runColor = backgroundRunColor;
    if (runColor != null) {
      paintBackgroundRun(
        canvas,
        offset,
        backgroundRunStart,
        backgroundRunEnd,
        runColor,
      );
    }
  }

  bool paintLineForegrounds(
    Canvas canvas,
    Offset offset,
    BufferLine line, {
    bool blinkVisible = true,
    int? activeHyperlinkId,
    int? cursorColumn,
    Color? cursorForeground,
    Color? foregroundOverride,
    bool ensureSelectionContrast = false,
  }) {
    final cellData = _scratchCellData;
    final cellWidth = _cellSize.width;
    final hasCombiningCharacters = line.hasCombiningCharacters;
    var hasBlinkingText = false;
    for (var i = 0; i < line.length; i++) {
      line.getCellData(i, cellData);

      final charWidth = cellData.content >> CellContent.widthShift;
      if (cellData.content & CellContent.codepointMask == 0) {
        if (charWidth == 2) {
          i++;
        }
        continue;
      }

      final cellOffset = offset.translate(i * cellWidth, 0);
      if (cellData.flags & CellFlags.blink != 0) {
        hasBlinkingText = true;
      }

      if (_textStyle.enableLigatures) {
        final runLength = _ligatureRunLength(
          line,
          i,
          cellData,
          cursorColumn: cursorColumn,
          hasCombiningCharacters: hasCombiningCharacters,
        );
        if (runLength > 1 &&
            _paintLigatureRun(
              canvas,
              cellOffset,
              line,
              i,
              runLength,
              cellData,
              activeHyperlinkId: activeHyperlinkId,
              foregroundOverride: foregroundOverride,
              ensureSelectionContrast: ensureSelectionContrast,
            )) {
          i += runLength - 1;
          continue;
        }
      }

      paintCellForeground(
        canvas,
        cellOffset,
        cellData,
        combiningCharacters: switch (hasCombiningCharacters) {
          true => line.getCombiningCharacters(i),
          false => null,
        },
        glyphCellSpan: glyphConstraintCellSpan(line, i),
        blinkVisible: blinkVisible,
        activeHyperlinkId: activeHyperlinkId,
        foregroundOverride: switch (i == cursorColumn) {
          true => cursorForeground,
          false => foregroundOverride,
        },
        ensureSelectionContrast: ensureSelectionContrast && i != cursorColumn,
      );

      if (charWidth == 2) {
        i++;
      }
    }
    return hasBlinkingText;
  }

  /// Number of consecutive cells starting at [column] that may be shaped as a
  /// single ligature run. Exposed for tests; the painting loop uses the private
  /// form directly so it can reuse the cell it already read.
  @visibleForTesting
  int ligatureRunCellSpan(BufferLine line, int column, {int? cursorColumn}) {
    final cellData = CellData.empty();
    line.getCellData(column, cellData);
    return _ligatureRunLength(
      line,
      column,
      cellData,
      cursorColumn: cursorColumn,
      hasCombiningCharacters: line.hasCombiningCharacters,
    );
  }

  /// Number of consecutive cells starting at [start] that may be shaped as one
  /// run. Returns 1 when the run would be a single cell, which is the signal to
  /// take the regular per-cell path.
  ///
  /// A run may only cover cells that paint identically under the per-cell path,
  /// because the whole run is drawn with one color in one call. Attributes,
  /// colors and the hyperlink id (carried in the flags) must therefore match
  /// across the run, and the cursor cell — which the caller repaints in an
  /// inverted color — always terminates it.
  int _ligatureRunLength(
    BufferLine line,
    int start,
    CellData first, {
    required int? cursorColumn,
    required bool hasCombiningCharacters,
  }) {
    if (start == cursorColumn) return 1;

    final flags = first.flags;
    // Blinking and invisible cells are skipped rather than painted, and framed
    // cells draw one box per cell. None of those survive being merged.
    if (flags & (CellFlags.invisible | CellFlags.blink) != 0) return 1;
    if (flags & CellAttr.frameMask != 0) return 1;

    if (first.content >> CellContent.widthShift != 1) return 1;
    if (!_isLigatureCandidate(first.content & CellContent.codepointMask)) {
      return 1;
    }
    if (hasCombiningCharacters && line.getCombiningCharacters(start) != null) {
      return 1;
    }

    final limit = min(line.length, start + _maxLigatureRunLength);
    final probe = _scratchLookaheadCellData;
    var end = start + 1;
    while (end < limit) {
      if (end == cursorColumn) break;

      line.getCellData(end, probe);
      if (probe.flags != flags) break;
      if (probe.foreground != first.foreground) break;
      if (probe.background != first.background) break;
      if (probe.underlineColor != first.underlineColor) break;
      if (probe.content >> CellContent.widthShift != 1) break;
      if (!_isLigatureCandidate(probe.content & CellContent.codepointMask)) {
        break;
      }
      if (hasCombiningCharacters && line.getCombiningCharacters(end) != null) {
        break;
      }
      end++;
    }
    return end - start;
  }

  /// Shapes [length] cells starting at [start] as a single run and paints it at
  /// [offset].
  ///
  /// Returns false without painting when the shaped run does not fill exactly
  /// the cells it covers, which happens whenever the font produces no ligature
  /// or produces one that would break the cell grid. The caller then falls back
  /// to painting the cells individually.
  bool _paintLigatureRun(
    Canvas canvas,
    Offset offset,
    BufferLine line,
    int start,
    int length,
    CellData cellData, {
    int? activeHyperlinkId,
    Color? foregroundOverride,
    bool ensureSelectionContrast = false,
  }) {
    final cellFlags = cellData.flags;
    final isActiveHyperlink =
        cellData.hyperlinkId != 0 && cellData.hyperlinkId == activeHyperlinkId;
    final color = switch (ensureSelectionContrast) {
      true => resolveSelectionForegroundColor(
          cellData,
          foregroundOverride: foregroundOverride,
        ),
      false => resolveCellForegroundColor(
          cellData,
          foregroundOverride: foregroundOverride,
        ),
    };
    final decorationColor = switch (cellData.underlineColor) {
      0 => _underlineDecorationColor(cellFlags, color),
      _ => resolveForegroundColor(cellData.underlineColor),
    };

    final text = _ligatureRunText(line, start, length);
    // Only bold and italic select a different font face, so they alone decide
    // whether an earlier rejection of this run text still applies.
    final faceFlags = cellFlags & (CellFlags.bold | CellFlags.italic);
    final rejectionKey = (text, faceFlags);
    if (_rejectedLigatureRuns.contains(rejectionKey)) return false;

    final hyperlinkFlag = switch (isActiveHyperlink) {
      true => CellAttr.hyperlinkMarker,
      false => 0,
    };
    // Shaped runs share the paragraph cache with single cells. Their key holds
    // the run text instead of a packed cell content, so the two key shapes are
    // distinct values and cannot collide.
    final cacheKey = (
      color.toARGB32(),
      decorationColor.toARGB32(),
      cellFlags & CellAttr.visualMask | hyperlinkFlag,
      text,
      _textScaler,
    );
    final runWidth = _cellSize.width * length;
    var paragraph = _paragraphCache.getLayoutFromCache(cacheKey);

    if (paragraph == null) {
      final style = _textStyle.toTextStyle(
        color: color,
        decorationColor: decorationColor,
        bold: cellFlags & CellFlags.bold != 0,
        italic: cellFlags & CellFlags.italic != 0,
        underline: _hasUnderline(cellFlags) || isActiveHyperlink,
        doubleUnderline: _hasDoubleUnderline(cellFlags, isActiveHyperlink),
        decorationStyle: _decorationStyle(cellFlags),
        strikethrough: cellFlags & CellAttr.strikethrough != 0,
        overline: cellFlags & CellAttr.overline != 0,
      );

      // Shape once outside the cache so a run that turns out not to fit never
      // occupies a slot. Rejections are remembered instead, which costs one
      // layout per run text and face rather than one per frame.
      final candidate = _layoutRun(text, style);
      if (!_runFillsCells(candidate, runWidth)) {
        candidate.dispose();
        // Real content only ever produces a few dozen distinct rejected
        // runs; reaching the bound means something pathological is feeding
        // this path, and a full clear is cheaper than tracking which entry
        // to evict for a case that is not expected to occur.
        if (_rejectedLigatureRuns.length >= _maxRejectedLigatureRuns) {
          _rejectedLigatureRuns.clear();
        }
        _rejectedLigatureRuns.add(rejectionKey);
        return false;
      }
      candidate.dispose();

      paragraph = _paragraphCache.performAndCacheLayout(
        text,
        style,
        _textScaler,
        cacheKey,
      );
    }

    if (!_runFillsCells(paragraph, runWidth)) return false;

    canvas.drawParagraph(paragraph, offset);
    return true;
  }

  Paragraph _layoutRun(String text, TextStyle style) {
    final builder = ParagraphBuilder(style.getParagraphStyle())
      ..pushStyle(style.getTextStyle(textScaler: _textScaler))
      ..addText(text);
    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: double.infinity));
    return paragraph;
  }

  /// Whether a shaped run fills exactly the cells it covers.
  ///
  /// The grid is only preserved when the shaped advance matches those cells.
  /// Both the cell size and the run advance come from the same font at the same
  /// size, so a ligature font hits this exactly; anything else is rejected here
  /// rather than allowed to shift the row.
  @pragma('vm:prefer-inline')
  bool _runFillsCells(Paragraph paragraph, double runWidth) {
    return (paragraph.maxIntrinsicWidth - runWidth).abs() <=
            _ligatureAdvanceEpsilon &&
        paragraph.height <= _cellSize.height;
  }

  String _ligatureRunText(BufferLine line, int start, int length) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.writeCharCode(line.getCodePoint(start + i));
    }
    return buffer.toString();
  }

  @pragma('vm:prefer-inline')
  void paintCell(Canvas canvas, Offset offset, CellData cellData) {
    paintCellBackground(canvas, offset, cellData);
    paintCellForeground(canvas, offset, cellData);
  }

  /// Paints the character in the cell represented by [cellData] to [canvas] at
  /// [offset].
  @pragma('vm:prefer-inline')
  void paintCellForeground(
    Canvas canvas,
    Offset offset,
    CellData cellData, {
    String? combiningCharacters,
    int? glyphCellSpan,
    bool blinkVisible = true,
    int? activeHyperlinkId,
    Color? foregroundOverride,
    bool ensureSelectionContrast = false,
  }) {
    final charCode = cellData.content & CellContent.codepointMask;
    if (charCode == 0) return;
    if (charCode == 0x09) return;

    final cellFlags = cellData.flags;
    if (cellFlags & CellFlags.invisible != 0) return;
    if (cellFlags & CellFlags.blink != 0 && !blinkVisible) return;

    final isActiveHyperlink =
        cellData.hyperlinkId != 0 && cellData.hyperlinkId == activeHyperlinkId;
    final isBlankBraille = charCode == 0x2800;
    if (combiningCharacters == null &&
        (charCode == 0x20 || isBlankBraille) &&
        !isActiveHyperlink &&
        !_hasVisibleSpaceDecoration(cellFlags)) {
      return;
    }
    final color = switch (ensureSelectionContrast) {
      true => resolveSelectionForegroundColor(
          cellData,
          foregroundOverride: foregroundOverride,
        ),
      false => resolveCellForegroundColor(
          cellData,
          foregroundOverride: foregroundOverride,
        ),
    };
    final charWidth = cellData.content >> CellContent.widthShift;
    final cellSpan = switch (charWidth) {
      2 => 2,
      _ => 1,
    };
    final allocatedWidth = _cellSize.width * cellSpan;
    final glyphClipWidth =
        _cellSize.width * max(cellSpan, glyphCellSpan ?? cellSpan);
    final decorationColor = switch (cellData.underlineColor) {
      0 => _underlineDecorationColor(cellFlags, color),
      _ => resolveForegroundColor(cellData.underlineColor),
    };

    if (combiningCharacters == null && (charCode == 0x20 || isBlankBraille)) {
      _paintManualDecorations(
        canvas,
        offset,
        color,
        decorationColor,
        cellFlags,
        allocatedWidth: allocatedWidth,
        isActiveHyperlink: isActiveHyperlink,
      );
      return;
    }

    _foregroundPaint.color = color;
    if (combiningCharacters == null &&
        paintProceduralGlyph(
          canvas,
          offset,
          _cellSize,
          charCode,
          _foregroundPaint,
          cache: _proceduralGlyphCache,
        )) {
      _paintManualDecorations(
        canvas,
        offset,
        color,
        decorationColor,
        cellFlags,
        allocatedWidth: allocatedWidth,
        isActiveHyperlink: isActiveHyperlink,
      );
      return;
    }

    final visualFlags = cellData.flags & CellAttr.visualMask;
    final hyperlinkFlag = switch (isActiveHyperlink) {
      true => CellAttr.hyperlinkMarker,
      false => 0,
    };
    // Colors are keyed by their packed ARGB value rather than by the [Color]
    // instance: hashing an integer is markedly cheaper than hashing the four
    // floating point components of a [Color], and this key is built once per
    // visible cell per frame. Every color reaching this point comes from the
    // sRGB palette, so the packed value identifies it uniquely.
    final cacheKey = (
      color.toARGB32(),
      decorationColor.toARGB32(),
      visualFlags | hyperlinkFlag,
      cellData.content,
      _textScaler,
      combiningCharacters,
    );
    var paragraph = _paragraphCache.getLayoutFromCache(cacheKey);

    if (paragraph == null) {
      final style = _textStyle.toTextStyle(
        color: color,
        decorationColor: decorationColor,
        bold: cellFlags & CellFlags.bold != 0,
        italic: cellFlags & CellFlags.italic != 0,
        underline: _hasUnderline(cellFlags) || isActiveHyperlink,
        doubleUnderline: _hasDoubleUnderline(cellFlags, isActiveHyperlink),
        decorationStyle: _decorationStyle(cellFlags),
        strikethrough: cellFlags & CellAttr.strikethrough != 0,
        overline: cellFlags & CellAttr.overline != 0,
      );

      // Flutter does not draw an underline below a space which is not between
      // other regular characters. As only single characters are drawn, this
      // will never produce an underline below a space in the terminal. As a
      // workaround the regular space CodePoint 0x20 is replaced with
      // the CodePoint 0xA0. This is a non breaking space and a underline can be
      // drawn below it.
      var char = String.fromCharCode(charCode);
      if ((_hasUnderline(cellFlags) || isActiveHyperlink) &&
          (charCode == 0x20 || isBlankBraille)) {
        char = String.fromCharCode(0xA0);
      }
      if (combiningCharacters != null) {
        char += combiningCharacters;
      }

      paragraph = _paragraphCache.performAndCacheLayout(
        char,
        style,
        _textScaler,
        cacheKey,
      );
    }

    if (paragraph.maxIntrinsicWidth <= glyphClipWidth &&
        paragraph.height <= _cellSize.height) {
      canvas.drawParagraph(paragraph, offset);
      _paintFrameDecoration(
        canvas,
        offset,
        color,
        cellFlags,
        allocatedWidth: allocatedWidth,
      );
      return;
    }
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        offset.dx,
        offset.dy,
        glyphClipWidth,
        _cellSize.height,
      ),
    );
    final glyphWidth = paragraph.maxIntrinsicWidth;
    if (cellSpan == 2 && glyphWidth > glyphClipWidth) {
      // A wide character is almost always an emoji, drawn from a color emoji
      // font whose advance (about 1.25em for Apple Color Emoji) exceeds two
      // cells of most monospace faces. Clipping it shaves off its right edge,
      // so shrink it to the two cells instead, keeping it vertically centred
      // on where it would have been drawn.
      final scale = glyphClipWidth / glyphWidth;
      canvas.translate(
        offset.dx,
        offset.dy + paragraph.height * (1 - scale) / 2,
      );
      canvas.scale(scale);
      canvas.drawParagraph(paragraph, Offset.zero);
    } else {
      canvas.drawParagraph(paragraph, offset);
    }
    canvas.restore();
    _paintFrameDecoration(
      canvas,
      offset,
      color,
      cellFlags,
      allocatedWidth: allocatedWidth,
    );
  }

  @pragma('vm:prefer-inline')
  bool _hasUnderline(int cellFlags) {
    return cellFlags & CellAttr.underlineMask != 0;
  }

  @pragma('vm:prefer-inline')
  bool _hasDoubleUnderline(int cellFlags, bool isActiveHyperlink) {
    if (cellFlags & CellAttr.doubleUnderline != 0) {
      return true;
    }
    return isActiveHyperlink && (cellFlags & CellFlags.underline != 0);
  }

  @pragma('vm:prefer-inline')
  bool _hasVisibleSpaceDecoration(int cellFlags) {
    return cellFlags &
            (CellAttr.underlineMask |
                CellAttr.strikethrough |
                CellAttr.overline |
                CellAttr.frameMask) !=
        0;
  }

  void _paintManualDecorations(
    Canvas canvas,
    Offset offset,
    Color color,
    Color decorationColor,
    int cellFlags, {
    required double allocatedWidth,
    required bool isActiveHyperlink,
  }) {
    if (isActiveHyperlink ||
        cellFlags &
                (CellFlags.underline |
                    CellAttr.undercurl |
                    CellAttr.dottedUnderline |
                    CellAttr.dashedUnderline) !=
            0) {
      _paintUnderlineDecoration(
        canvas,
        offset,
        decorationColor,
        cellFlags,
        allocatedWidth: allocatedWidth,
        isHyperlink: isActiveHyperlink,
      );
    }
    if (cellFlags & CellAttr.doubleUnderline != 0) {
      _paintDoubleUnderline(canvas, offset, decorationColor, allocatedWidth);
    }

    _foregroundPaint.color = decorationColor;
    if (cellFlags & CellAttr.strikethrough != 0) {
      canvas.drawLine(
        offset.translate(0, _cellSize.height / 2),
        offset.translate(allocatedWidth, _cellSize.height / 2),
        _foregroundPaint,
      );
    }
    if (cellFlags & CellAttr.overline != 0) {
      canvas.drawLine(
        offset,
        offset.translate(allocatedWidth, 0),
        _foregroundPaint,
      );
    }
    _paintFrameDecoration(
      canvas,
      offset,
      color,
      cellFlags,
      allocatedWidth: allocatedWidth,
    );
  }

  void _paintFrameDecoration(
    Canvas canvas,
    Offset offset,
    Color color,
    int cellFlags, {
    required double allocatedWidth,
  }) {
    if (cellFlags & CellAttr.frameMask == 0) return;

    final paint = _decorationPaint
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Rect.fromLTWH(
      offset.dx + 0.5,
      offset.dy + 0.5,
      allocatedWidth - 1,
      _cellSize.height - 1,
    );

    if (cellFlags & CellAttr.encircled != 0) {
      canvas.drawOval(rect, paint);
      return;
    }

    canvas.drawRect(rect, paint);
  }

  @pragma('vm:prefer-inline')
  TextDecorationStyle _decorationStyle(int cellFlags) {
    if (cellFlags & CellAttr.undercurl != 0) {
      return TextDecorationStyle.wavy;
    }
    if (cellFlags & CellAttr.dottedUnderline != 0) {
      return TextDecorationStyle.dotted;
    }
    if (cellFlags & CellAttr.dashedUnderline != 0) {
      return TextDecorationStyle.dashed;
    }
    return TextDecorationStyle.solid;
  }

  void _paintUnderlineDecoration(
    Canvas canvas,
    Offset offset,
    Color color,
    int cellFlags, {
    required double allocatedWidth,
    required bool isHyperlink,
  }) {
    if (isHyperlink && (cellFlags & CellFlags.underline != 0)) {
      _paintDoubleUnderline(canvas, offset, color, allocatedWidth);
      return;
    }
    if (cellFlags & CellAttr.undercurl != 0) {
      _paintWavyUnderline(canvas, offset, color, allocatedWidth);
      return;
    }
    if (cellFlags & CellAttr.dottedUnderline != 0) {
      _paintDottedUnderline(canvas, offset, color, allocatedWidth);
      return;
    }
    if (cellFlags & CellAttr.dashedUnderline != 0) {
      _paintDashedUnderline(canvas, offset, color, allocatedWidth);
      return;
    }
    if (cellFlags & CellFlags.underline == 0 && !isHyperlink) {
      return;
    }

    final paint = _decorationPaint
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;
    canvas.drawLine(
      offset.translate(0, _cellSize.height - 1),
      offset.translate(allocatedWidth, _cellSize.height - 1),
      paint,
    );
  }

  void _paintDoubleUnderline(
    Canvas canvas,
    Offset offset,
    Color color,
    double allocatedWidth,
  ) {
    final paint = _decorationPaint
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;
    canvas.drawLine(
      offset.translate(0, _cellSize.height - 3),
      offset.translate(allocatedWidth, _cellSize.height - 3),
      paint,
    );
    canvas.drawLine(
      offset.translate(0, _cellSize.height - 1),
      offset.translate(allocatedWidth, _cellSize.height - 1),
      paint,
    );
  }

  void _paintWavyUnderline(
    Canvas canvas,
    Offset offset,
    Color color,
    double allocatedWidth,
  ) {
    final baseline = offset.dy + _cellSize.height - 2;
    final amplitude = (_cellSize.height / 12).clamp(1.0, 2.0).toDouble();
    final segmentWidth = (_cellSize.width / 2).clamp(3.0, 6.0).toDouble();
    final path = Path()..moveTo(offset.dx, baseline);
    var x = offset.dx;
    var waveUp = true;
    while (x < offset.dx + allocatedWidth) {
      final controlY = switch (waveUp) {
        true => baseline - amplitude,
        false => baseline + amplitude,
      };
      final nextX = (x + segmentWidth)
          .clamp(offset.dx, offset.dx + allocatedWidth)
          .toDouble();
      path.quadraticBezierTo(
        x + segmentWidth / 2,
        controlY,
        nextX,
        baseline,
      );
      x = nextX;
      waveUp = !waveUp;
    }

    final paint = _decorationPaint
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, paint);
  }

  void _paintDottedUnderline(
    Canvas canvas,
    Offset offset,
    Color color,
    double allocatedWidth,
  ) {
    final y = offset.dy + _cellSize.height - 1;
    final radius = (_cellSize.height / 18).clamp(0.75, 1.25).toDouble();
    final step = (radius * 4).clamp(3.0, 5.0).toDouble();
    final paint = _decorationPaint
      ..color = color
      ..style = PaintingStyle.fill;

    var x = offset.dx + radius;
    while (x < offset.dx + allocatedWidth) {
      canvas.drawCircle(Offset(x, y), radius, paint);
      x += step;
    }
  }

  void _paintDashedUnderline(
    Canvas canvas,
    Offset offset,
    Color color,
    double allocatedWidth,
  ) {
    final y = offset.dy + _cellSize.height - 1;
    final dashWidth = (_cellSize.width / 3).clamp(3.0, 6.0).toDouble();
    final gapWidth = (dashWidth / 2).clamp(1.0, 3.0).toDouble();
    final paint = _decorationPaint
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;

    var x = offset.dx;
    while (x < offset.dx + allocatedWidth) {
      final endX = (x + dashWidth)
          .clamp(offset.dx, offset.dx + allocatedWidth)
          .toDouble();
      canvas.drawLine(Offset(x, y), Offset(endX, y), paint);
      x = endX + gapWidth;
    }
  }

  /// Paints the background of a cell represented by [cellData] to [canvas] at
  /// [offset].
  @pragma('vm:prefer-inline')
  void paintCellBackground(Canvas canvas, Offset offset, CellData cellData) {
    final color = resolveCellBackgroundColor(cellData);
    if (color == null) return;

    _backgroundPaint.color = color;
    final doubleWidth = cellData.content >> CellContent.widthShift == 2;
    final widthScale = switch (doubleWidth) {
      true => 2,
      false => 1,
    };
    final size = Size(_cellSize.width * widthScale, _cellSize.height);
    canvas.drawRect(offset & size, _backgroundPaint);
  }

  @pragma('vm:prefer-inline')
  void paintBackgroundRun(
    Canvas canvas,
    Offset offset,
    int start,
    int end,
    Color color,
  ) {
    _backgroundPaint.color = color;
    final runOffset = offset.translate(start * _cellSize.width, 0);
    final runSize = Size(
      (end - start) * _cellSize.width,
      _cellSize.height,
    );
    canvas.drawRect(runOffset & runSize, _backgroundPaint);
  }

  /// Get the effective background color for a cell, or null when the cell uses
  /// the normal transparent terminal background.
  @pragma('vm:prefer-inline')
  Color? resolveCellBackgroundColor(CellData cellData) {
    final colorType = cellData.background & CellColor.typeMask;

    final inverse =
        (cellData.flags & CellFlags.inverse != 0) != _reverseDisplay;
    if (inverse) {
      return _resolveLogicalForegroundColor(cellData);
    }

    if (colorType == CellColor.normal) return null;

    return resolveBackgroundColor(cellData.background);
  }

  Color resolveCellForegroundColor(
    CellData cellData, {
    Color? foregroundOverride,
  }) {
    final inverse =
        (cellData.flags & CellFlags.inverse != 0) != _reverseDisplay;
    final color = foregroundOverride ??
        switch (inverse) {
          false => _resolveLogicalForegroundColor(cellData),
          true => _specialColorOverrides[_specialReverseColor] ??
              resolveBackgroundColor(cellData.background),
        };
    return color;
  }

  Color resolveSelectionForegroundColor(
    CellData cellData, {
    Color? foregroundOverride,
  }) {
    final foreground = resolveCellForegroundColor(
      cellData,
      foregroundOverride: foregroundOverride,
    );
    final cellBackground =
        resolveCellBackgroundColor(cellData) ?? backgroundColor;
    final selectedBackground = Color.alphaBlend(
      selectionColor,
      cellBackground,
    );
    if (_contrastRatio(foreground, selectedBackground) >= 1.5) {
      return foreground;
    }

    final terminalBackgroundContrast =
        _contrastRatio(backgroundColor, selectedBackground);
    final terminalForegroundContrast =
        _contrastRatio(foregroundColor, selectedBackground);
    return switch (terminalBackgroundContrast >= terminalForegroundContrast) {
      true => backgroundColor,
      false => foregroundColor,
    };
  }

  Color _resolveLogicalForegroundColor(CellData cellData) {
    final specialColor = _attributeForegroundColor(cellData.flags);
    final color =
        specialColor ?? resolveForegroundColor(_boldBrightForeground(cellData));
    if (cellData.flags & CellFlags.faint == 0) return color;
    return color.withValues(
      red: color.r * _dimColorFactor,
      green: color.g * _dimColorFactor,
      blue: color.b * _dimColorFactor,
    );
  }

  Color? _attributeForegroundColor(int cellFlags) {
    if (cellFlags & CellFlags.bold != 0) {
      final color = _specialColorOverrides[_specialBoldColor];
      if (color != null) return color;
    }
    if (cellFlags & CellFlags.italic != 0) {
      final color = _specialColorOverrides[_specialItalicColor];
      if (color != null) return color;
    }
    if (cellFlags & CellFlags.blink != 0) {
      final color = _specialColorOverrides[_specialBlinkColor];
      if (color != null) return color;
    }
    return null;
  }

  int _boldBrightForeground(CellData cellData) {
    if (!_textStyle.drawBoldTextWithBrightColors) {
      return cellData.foreground;
    }
    if (cellData.flags & CellFlags.bold == 0) {
      return cellData.foreground;
    }

    final colorType = cellData.foreground & CellColor.typeMask;
    if (colorType != CellColor.named && colorType != CellColor.palette) {
      return cellData.foreground;
    }

    final colorValue = cellData.foreground & CellColor.valueMask;
    if (colorValue > 7) {
      return cellData.foreground;
    }

    return colorType | (colorValue + 8);
  }

  Color _underlineDecorationColor(int cellFlags, Color fallback) {
    if (cellFlags & CellAttr.underlineMask == 0) return fallback;
    return _specialColorOverrides[_specialUnderlineColor] ?? fallback;
  }

  ({Color background, Color foreground}) resolveCursorColors(
    CellData cellData,
  ) {
    final inverse =
        (cellData.flags & CellFlags.inverse != 0) != _reverseDisplay;
    final cellForeground = switch (inverse) {
      true => resolveBackgroundColor(cellData.background),
      false => _resolveLogicalForegroundColor(cellData),
    };
    final cellBackground = switch (inverse) {
      true => _resolveLogicalForegroundColor(cellData),
      false => resolveBackgroundColor(cellData.background),
    };

    if (_contrastRatio(cellForeground, cellBackground) < 1.5) {
      return (
        background: foregroundColor,
        foreground: backgroundColor,
      );
    }
    return (
      background: cursorColor,
      foreground: cellBackground,
    );
  }

  /// Get the effective foreground color for a cell from information encoded in
  /// [cellColor].
  @pragma('vm:prefer-inline')
  Color resolveForegroundColor(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return foregroundColor;
      case CellColor.named:
      case CellColor.palette:
        return _indexedColorOverrides[colorValue] ??
            _paletteColorOrDefault(colorValue, foregroundColor);
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }

  /// Get the effective background color for a cell from information encoded in
  /// [cellColor].
  @pragma('vm:prefer-inline')
  Color resolveBackgroundColor(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return backgroundColor;
      case CellColor.named:
      case CellColor.palette:
        return _indexedColorOverrides[colorValue] ??
            _paletteColorOrDefault(colorValue, backgroundColor);
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }

  Color _paletteColorOrDefault(int colorValue, Color defaultColor) {
    if (colorValue < 0 || colorValue >= _colorPalette.length) {
      return defaultColor;
    }
    return _colorPalette[colorValue];
  }
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = max(firstLuminance, secondLuminance);
  final darker = min(firstLuminance, secondLuminance);
  return (lighter + 0.05) / (darker + 0.05);
}
