import 'dart:collection';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:xterm3/src/core/buffer/cell_offset.dart';
import 'package:xterm3/src/core/cell.dart';
import 'package:xterm3/src/core/cursor.dart';
import 'package:xterm3/src/utils/circular_buffer.dart';
import 'package:xterm3/src/utils/single_cell_text.dart';
import 'package:xterm3/src/utils/unicode_v11.dart';

const _cellSize = 4;

/// Storage for a line nothing has written to yet. Shared, so creating a line
/// - which scrolling does once per line of output - allocates nothing at all.
final _noCells = Uint32List(0);

const _cellForeground = 0;

const _cellBackground = 1;

const _cellAttributes = 2;

const _cellContent = 3;

const _maxCombiningCharactersPerCell = 16;

class BufferLine with IndexedItem {
  BufferLine(
    this._length, {
    this.isWrapped = false,
  }) : _data = _noCells;

  int _length;

  Uint32List _data;

  /// Cells at or past this index hold nothing: all zero, whether because
  /// they were never written or because an erase to the default background
  /// took them back. Every store goes through [_ensureCapacity], which is what
  /// raises it; [eraseRange] is what lowers it.
  int _used = 0;

  /// Grows storage so cell [index] is addressable. The common call finds the
  /// room already there and costs one comparison.
  ///
  /// The first write allocates for what it is about to write, so a line that
  /// is filled in one run - which is what scrolling output looks like - gets
  /// exactly one store, sized to the text rather than to the viewport. A line
  /// that later outgrows that store jumps straight to its full [length]
  /// instead of climbing in 32-cell steps.
  void _ensureCapacity(int index) {
    if (index >= _used) _used = index + 1;
    final required = (index + 1) * _cellSize;
    if (required <= _data.length) return;

    if (_data.isEmpty) {
      _data = Uint32List(_calcCapacity(index + 1) * _cellSize);
      return;
    }

    final cells = index + 1 > _length ? index + 1 : _length;
    final grown = Uint32List(_calcCapacity(cells) * _cellSize);
    grown.setRange(0, _data.length, _data);
    _data = grown;
  }

  /// A cell field, or 0 for a cell this line has never had storage for.
  int _field(int index, int field) {
    final offset = index * _cellSize + field;
    if (offset >= _data.length) return 0;
    return _data[offset];
  }

  @Deprecated('Exposes raw cell storage; will be removed in the next major.')
  @visibleForTesting
  Uint32List get data => _data;

  var isWrapped = false;

  int get length => _length;

  /// Cells from here to [length] hold nothing: no content, no colour, no
  /// attributes. A scan that is looking for any of those can stop here
  /// instead of walking the blank tail of a short line.
  int get writtenLength => _used < _length ? _used : _length;

  final _anchors = <CellAnchor>[];

  Map<int, String>? _combiningCharacters;

  Map<int, int>? _underlineColors;

  List<CellAnchor> get anchors => UnmodifiableListView(_anchors);

  /// Whether this line carries any anchors, without building the view
  /// [anchors] returns. Reflow asks this per line and, for a line that has
  /// none, that view was the only thing allocated.
  bool get hasAnchors => _anchors.isNotEmpty;

  bool get hasCombiningCharacters => _combiningCharacters?.isNotEmpty ?? false;

  Map<int, String> get _mutableCombiningCharacters {
    return _combiningCharacters ??= <int, String>{};
  }

  Map<int, int> get _mutableUnderlineColors {
    return _underlineColors ??= <int, int>{};
  }

  int getForeground(int index) {
    return _field(index, _cellForeground);
  }

  int getBackground(int index) {
    return _field(index, _cellBackground);
  }

  int getAttributes(int index) {
    return _field(index, _cellAttributes);
  }

  int getHyperlinkId(int index) {
    return (getAttributes(index) & CellAttr.hyperlinkMask) >>
        CellAttr.hyperlinkShift;
  }

  int getSemanticContent(int index) {
    return getAttributes(index) & CellAttr.semanticMask;
  }

  void setSemanticContent(int index, int value) {
    final attributes = getAttributes(index);
    setAttributes(
      index,
      (attributes & ~CellAttr.semanticMask) | (value & CellAttr.semanticMask),
    );
  }

  bool isProtected(int index) {
    return getAttributes(index) & CellAttr.protected != 0;
  }

  int getContent(int index) {
    return _field(index, _cellContent);
  }

  int getCodePoint(int index) {
    return _field(index, _cellContent) & CellContent.codepointMask;
  }

  int getWidth(int index) {
    return _field(index, _cellContent) >> CellContent.widthShift;
  }

  String? getCombiningCharacters(int index) {
    return _combiningCharacters?[index];
  }

  int getUnderlineColor(int index) {
    return _underlineColors?[index] ?? 0;
  }

  void addCombiningCharacter(int index, int codePoint) {
    if (index < 0 ||
        index >= _length ||
        getCodePoint(index) == 0 ||
        codePoint < 0 ||
        codePoint > 0x10FFFF) {
      return;
    }

    final existing = _combiningCharacters?[index];
    if (existing == null) {
      _mutableCombiningCharacters[index] = String.fromCharCode(codePoint);
      return;
    }

    if (existing.runes.length >= _maxCombiningCharactersPerCell) return;
    _mutableCombiningCharacters[index] =
        existing + String.fromCharCode(codePoint);
  }

  void getCellData(
    int index,
    CellData cellData, {
    bool includeUnderlineColor = true,
  }) {
    cellData.foreground = _field(index, _cellForeground);
    cellData.background = _field(index, _cellBackground);
    cellData.underlineColor = switch (includeUnderlineColor) {
      true => _underlineColors?[index] ?? 0,
      false => 0,
    };
    cellData.flags = _field(index, _cellAttributes);
    cellData.content = _field(index, _cellContent);
  }

  CellData createCellData(int index) {
    final cellData = CellData.empty();
    getCellData(index, cellData);
    return cellData;
  }

  void setForeground(int index, int value) {
    _ensureCapacity(index);
    _data[index * _cellSize + _cellForeground] = value;
  }

  void setBackground(int index, int value) {
    _ensureCapacity(index);
    _data[index * _cellSize + _cellBackground] = value;
  }

  void setAttributes(int index, int value) {
    _ensureCapacity(index);
    _data[index * _cellSize + _cellAttributes] = value;
  }

  void setContent(int index, int value) {
    _ensureCapacity(index);
    _data[index * _cellSize + _cellContent] = value;
    _combiningCharacters?.remove(index);
  }

  void setWidth(int index, int width) {
    _ensureCapacity(index);
    final offset = index * _cellSize + _cellContent;
    _data[offset] = (_data[offset] & CellContent.codepointMask) |
        (width << CellContent.widthShift);
  }

  void setCodePoint(int index, int char) {
    final width = unicodeV11.wcwidth(char);
    setContent(index, char | (width << CellContent.widthShift));
  }

  void setCell(int index, int char, int width, CursorStyle style) {
    _repairWideCellPairing(index, width, style);

    _ensureCapacity(index);
    final offset = index * _cellSize;
    _data[offset + _cellForeground] = style.foreground;
    _data[offset + _cellBackground] = style.background;
    _data[offset + _cellAttributes] = style.attrs |
        (style.hyperlinkId << CellAttr.hyperlinkShift) |
        style.semanticAttrs;
    _data[offset + _cellContent] = char | (width << CellContent.widthShift);
    _setUnderlineColor(index, style.underlineColor);
    _combiningCharacters?.remove(index);
  }

  /// Keeps the width-2 lead / width-0 placeholder pairing invariant intact
  /// across a raw [setCell] write, regardless of what the caller remembers
  /// (or forgets) to clean up beforehand.
  ///
  /// This primitive used to know nothing about the pairing convention, which
  /// meant every call site had to repeat the same "clear the neighbouring
  /// half first" dance - and the fuzzer kept finding call sites that forgot
  /// it (see the regression tests in parser_fuzz_test.dart). Two cases can
  /// break the pairing:
  ///  - [index] is currently the width-0 placeholder half of a pair, and this
  ///    write gives it a non-zero width - its former lead at `index - 1` is
  ///    left dangling with no placeholder, so erase that lead too.
  ///  - This write is itself a new width-2 lead, and `index + 1` currently
  ///    holds an unrelated stale wide lead - it would become an invalid
  ///    "placeholder" for the new pair, so erase it (and its own
  ///    placeholder) first.
  void _repairWideCellPairing(int index, int width, CursorStyle style) {
    if (width != 0 &&
        index > 0 &&
        getWidth(index) == 0 &&
        getWidth(index - 1) == 2) {
      eraseCell(index - 1, style);
    }
    if (width == 2 && index + 1 < _length && getWidth(index + 1) == 2) {
      eraseCell(index + 1, style);
      if (index + 2 < _length) {
        eraseCell(index + 2, style);
      }
    }
  }

  void setAsciiCells(
    int start,
    String text,
    int textStart,
    int count,
    CursorStyle style,
  ) {
    assert(start >= 0 && start + count <= _length);
    assert(textStart >= 0 && textStart + count <= text.length);
    if (count <= 0) return;

    _ensureCapacity(start + count - 1);
    clearWideCellAt(start, style);
    clearWideCellAt(start + count - 1, style);

    final foreground = style.foreground;
    final background = style.background;
    final attributes = style.attrs |
        (style.hyperlinkId << CellAttr.hyperlinkShift) |
        style.semanticAttrs;
    for (var offset = 0; offset < count; offset++) {
      final cellOffset = (start + offset) * _cellSize;
      final codeUnit = text.codeUnitAt(textStart + offset);
      // Callers must have established that every unit occupies exactly one
      // cell - see `ByteConsumer.printableTextRunLength`, which is where the
      // run this writes comes from.
      assert(isSingleCellPrintable(codeUnit));
      _data[cellOffset + _cellForeground] = foreground;
      _data[cellOffset + _cellBackground] = background;
      _data[cellOffset + _cellAttributes] = attributes;
      _data[cellOffset + _cellContent] =
          codeUnit | (1 << CellContent.widthShift);
    }

    final end = start + count;
    if (_combiningCharacters case final combiningCharacters?
        when combiningCharacters.isNotEmpty) {
      combiningCharacters.removeWhere(
        (index, _) => index >= start && index < end,
      );
    }
    if (style.underlineColor == 0) {
      if (_underlineColors case final underlineColors?
          when underlineColors.isNotEmpty) {
        underlineColors.removeWhere(
          (index, _) => index >= start && index < end,
        );
      }
      return;
    }
    for (var index = start; index < end; index++) {
      _mutableUnderlineColors[index] = style.underlineColor;
    }
  }

  void clearWideCellAt(int index, CursorStyle style) {
    if (index < 0 || index >= _length) return;

    if (getWidth(index) == 2) {
      eraseCell(index, style);
      if (index + 1 < _length) {
        eraseCell(index + 1, style);
      }
      return;
    }

    if (index > 0 && getWidth(index - 1) == 2) {
      eraseCell(index - 1, style);
      eraseCell(index, style);
    }
  }

  void setCellData(int index, CellData cellData) {
    _ensureCapacity(index);
    final offset = index * _cellSize;
    _data[offset + _cellForeground] = cellData.foreground;
    _data[offset + _cellBackground] = cellData.background;
    _data[offset + _cellAttributes] = cellData.flags;
    _data[offset + _cellContent] = cellData.content;
    _setUnderlineColor(index, cellData.underlineColor);
    _combiningCharacters?.remove(index);
  }

  void eraseCell(int index, CursorStyle style) {
    _ensureCapacity(index);
    final offset = index * _cellSize;
    _data[offset + _cellForeground] = CellColor.normal;
    _data[offset + _cellBackground] = style.background;
    _data[offset + _cellAttributes] = 0;
    _data[offset + _cellContent] = 0;
    _underlineColors?.remove(index);
    _combiningCharacters?.remove(index);
  }

  void resetCell(int index) {
    _ensureCapacity(index);
    final offset = index * _cellSize;
    _data[offset + _cellForeground] = 0;
    _data[offset + _cellBackground] = 0;
    _data[offset + _cellAttributes] = 0;
    _data[offset + _cellContent] = 0;
    _underlineColors?.remove(index);
    _combiningCharacters?.remove(index);
  }

  void _setUnderlineColor(int index, int value) {
    if (value == 0) {
      _underlineColors?.remove(index);
      return;
    }
    _mutableUnderlineColors[index] = value;
  }

  /// Erase cells whose index satisfies [start] <= index < [end]. Erased cells
  /// are filled with [style].
  void eraseRange(
    int start,
    int end,
    CursorStyle style, {
    bool respectProtected = false,
  }) {
    // reset cell one to the left if start is second cell of a wide char.
    // Guarded by start < end (a non-empty range): if nothing is erased at
    // start, its lead must be left alone too, or an intact wide pair gets
    // torn apart by an empty-range call.
    if (start > 0 &&
        start < end &&
        getWidth(start - 1) == 2 &&
        _canErase(start - 1, respectProtected)) {
      eraseCell(start - 1, style);
    }

    // If end lands on the placeholder half of a wide char whose lead (at
    // end - 1) is inside the erased range, erase the placeholder too -
    // otherwise the lead below gets cleared and this placeholder is left
    // behind as an orphaned width-0 cell with no lead. end - 1 >= start
    // guards an empty range (start == end): the lead isn't erased below in
    // that case, so the placeholder must be left alone too.
    if (end > 0 &&
        end < _length &&
        end - 1 >= start &&
        getWidth(end - 1) == 2 &&
        _canErase(end, respectProtected)) {
      eraseCell(end, style);
    }

    if (end >= _length) _clearHiddenCells();

    end = min(end, _length);
    // Cells past [_used] already read as erased to the default background, so
    // they need no writing - and no storage allocated to write them into.
    final used = _used;
    if (style.background == 0 && end > used) end = used;
    for (var i = start; i < end; i++) {
      if (!_canErase(i, respectProtected)) continue;
      eraseCell(i, style);
    }
    // Everything from [start] on is zero again, so the next erase stops here.
    if (style.background == 0 &&
        !respectProtected &&
        end >= used &&
        start < used) {
      _used = start;
    }
  }

  /// Clears the cells a shrinking [resize] keeps past [length]. Anything that
  /// blanks the line up to its end calls this, so erased text cannot come back
  /// when the line grows again.
  void _clearHiddenCells() {
    final start = _length * _cellSize;
    if (start < _data.length) _data.fillRange(start, _data.length, 0);
    _combiningCharacters?.removeWhere((index, _) => index >= _length);
    _underlineColors?.removeWhere((index, _) => index >= _length);
  }

  bool _canErase(int index, bool respectProtected) {
    if (!respectProtected) return true;
    return !isProtected(index);
  }

  /// Remove [count] cells starting at [start]. Cells that are empty after the
  /// removal are filled with [style].
  void removeCells(int start, int count, [CursorStyle? style, int? end]) {
    end ??= _length;
    assert(start >= 0 && start < _length);
    assert(end >= start && end <= _length);
    assert(count >= 0 && start + count <= end);

    if (count == 0) return;
    if (end == _length) _clearHiddenCells();

    style ??= CursorStyle.empty;
    final combiningCharacters = switch (_combiningCharacters) {
      final values? when values.isNotEmpty => Map<int, String>.of(values),
      _ => const <int, String>{},
    };
    final underlineColors = switch (_underlineColors) {
      final values? when values.isNotEmpty => Map<int, int>.of(values),
      _ => const <int, int>{},
    };
    final rightBoundarySplitsWideCell =
        end < _length && end > 0 && getWidth(end - 1) == 2;

    if (start + count < end) {
      _ensureCapacity(end - 1);
      final moveStart = start * _cellSize;
      final moveEnd = (end - count) * _cellSize;
      final moveOffset = count * _cellSize;
      _data.setRange(moveStart, moveEnd, _data, moveStart + moveOffset);
    }

    for (var i = end - count; i < end; i++) {
      eraseCell(i, style);
    }

    if (start > 0 && getWidth(start - 1) == 2) {
      eraseCell(start - 1, style);
    }
    if (rightBoundarySplitsWideCell) {
      final shiftedHead = end - count - 1;
      if (shiftedHead >= start && shiftedHead < _length) {
        eraseCell(shiftedHead, style);
      }
      eraseCell(end, style);
    }

    _combiningCharacters = null;
    _underlineColors = null;
    for (final entry in combiningCharacters.entries) {
      if (entry.key < start) {
        if (getCodePoint(entry.key) != 0) {
          _mutableCombiningCharacters[entry.key] = entry.value;
        }
        continue;
      }

      if (entry.key < start + count) continue;
      final newIndex = entry.key - count;
      if (entry.key < end &&
          newIndex < _length &&
          getCodePoint(newIndex) != 0) {
        _mutableCombiningCharacters[newIndex] = entry.value;
        continue;
      }

      if (entry.key >= end && getCodePoint(entry.key) != 0) {
        _mutableCombiningCharacters[entry.key] = entry.value;
      }
    }
    for (final entry in underlineColors.entries) {
      if (entry.key < start) {
        if (getCodePoint(entry.key) != 0) {
          _mutableUnderlineColors[entry.key] = entry.value;
        }
        continue;
      }

      if (entry.key < start + count) continue;
      final newIndex = entry.key - count;
      if (entry.key < end &&
          newIndex < _length &&
          getCodePoint(newIndex) != 0) {
        _mutableUnderlineColors[newIndex] = entry.value;
        continue;
      }

      if (entry.key >= end && getCodePoint(entry.key) != 0) {
        _mutableUnderlineColors[entry.key] = entry.value;
      }
    }

    // Update anchors, remove anchors that are inside the removed range.
    if (_anchors.isNotEmpty) {
      for (final anchor in _anchors.toList()) {
        if (anchor.x >= start) {
          if (anchor.x < start + count) {
            anchor.dispose();
          } else if (anchor.x < end) {
            anchor.reposition(anchor.x - count);
          }
        }
      }
    }
  }

  /// Inserts [count] cells at [start]. New cells are initialized with [style].
  void insertCells(int start, int count, [CursorStyle? style, int? end]) {
    end ??= _length;
    assert(start >= 0 && start < _length);
    assert(end >= start && end <= _length);
    assert(count >= 0 && start + count <= end);

    if (count == 0) return;
    if (end == _length) _clearHiddenCells();

    style ??= CursorStyle.empty;
    final combiningCharacters = switch (_combiningCharacters) {
      final values? when values.isNotEmpty => Map<int, String>.of(values),
      _ => const <int, String>{},
    };
    final underlineColors = switch (_underlineColors) {
      final values? when values.isNotEmpty => Map<int, int>.of(values),
      _ => const <int, int>{},
    };
    final rightBoundarySplitsWideCell =
        end < _length && end > 0 && getWidth(end - 1) == 2;

    if (start > 0 && getWidth(start - 1) == 2) {
      eraseCell(start - 1, style);
    }

    if (start + count < end) {
      _ensureCapacity(end - 1);
      final moveStart = start * _cellSize;
      final moveEnd = (end - count) * _cellSize;
      final moveOffset = count * _cellSize;
      _data.setRange(
        moveStart + moveOffset,
        moveEnd + moveOffset,
        _data,
        moveStart,
      );
    }

    final eraseEnd = min(start + count, end);
    for (var i = start; i < eraseEnd; i++) {
      eraseCell(i, style);
    }

    if (end > 0 && getWidth(end - 1) == 2) {
      eraseCell(end - 1, style);
    }
    if (rightBoundarySplitsWideCell) {
      eraseCell(end, style);
    }

    _combiningCharacters = null;
    _underlineColors = null;
    for (final entry in combiningCharacters.entries) {
      if (entry.key < start) {
        if (getCodePoint(entry.key) != 0) {
          _mutableCombiningCharacters[entry.key] = entry.value;
        }
        continue;
      }

      final newIndex = entry.key + count;
      if (entry.key < end && newIndex < end && getCodePoint(newIndex) != 0) {
        _mutableCombiningCharacters[newIndex] = entry.value;
        continue;
      }

      if (entry.key >= end && getCodePoint(entry.key) != 0) {
        _mutableCombiningCharacters[entry.key] = entry.value;
      }
    }
    for (final entry in underlineColors.entries) {
      if (entry.key < start) {
        if (getCodePoint(entry.key) != 0) {
          _mutableUnderlineColors[entry.key] = entry.value;
        }
        continue;
      }

      final newIndex = entry.key + count;
      if (entry.key < end && newIndex < end && getCodePoint(newIndex) != 0) {
        _mutableUnderlineColors[newIndex] = entry.value;
        continue;
      }

      if (entry.key >= end && getCodePoint(entry.key) != 0) {
        _mutableUnderlineColors[entry.key] = entry.value;
      }
    }

    // Update anchors, move anchors that are after the inserted range.
    if (_anchors.isNotEmpty) {
      for (final anchor in _anchors.toList()) {
        if (anchor.x >= end - count && anchor.x < end) {
          anchor.dispose();
          continue;
        }

        if (anchor.x >= start && anchor.x < end - count) {
          anchor.reposition(anchor.x + count);
        }
      }
    }
  }

  void resize(int length) {
    assert(length >= 0);

    if (length == _length) {
      return;
    }

    final oldLength = _length;

    _length = length;

    if (length > oldLength) {
      // Growing intentionally preserves cell data past the old length (so
      // it can reappear if the line was previously shrunk and is now being
      // grown back - see the tests for this behaviour). But the raw bytes
      // newly exposed by this grow may hold a wide-char lead/placeholder
      // pair that was frozen mid-pair by some earlier resize whose own
      // boundary happened to land between the two halves (e.g. a shrink to
      // a width that kept the lead but cut off its placeholder, or a
      // subsequent write at a since-shrunk width that landed on the
      // placeholder half without the lead in scope to clear alongside it).
      // Scan the whole newly exposed range - not just its last column - for
      // a dangling lead and clear it so the width-2/placeholder invariant
      // holds for every cell we just made visible again.
      for (var i = oldLength; i < length; i++) {
        if (getWidth(i) == 2 && (i + 1 >= length || getWidth(i + 1) != 0)) {
          resetCell(i);
        }
      }
    }

    for (var i = 0; i < _anchors.length; i++) {
      final anchor = _anchors[i];
      if (anchor.x > _length) {
        anchor.reposition(_length);
      }
    }
  }

  /// Returns the offset of the last cell that has content from the start of
  /// the line.
  int getTrimmedLength([int? cols]) {
    // Clamp to _length, not capacity: resize() shrinking a line keeps the
    // cell data beyond _length around, so scanning past it would count
    // stale content that's no longer part of the line.
    final maxCols = _length;

    if (cols == null || cols > maxCols) {
      cols = maxCols;
    }

    if (cols <= 0) {
      return 0;
    }

    for (var i = cols - 1; i >= 0; i--) {
      var codePoint = getCodePoint(i);

      if (codePoint != 0) {
        // we are at the last cell in this line that has content.
        // the length of this line is the index of this cell + 1
        // the only exception is that if that last cell is wider
        // than 1 then we have to add the diff
        final lastCellWidth = getWidth(i);
        return i + lastCellWidth;
      }
    }
    return 0;
  }

  /// Copies [len] cells from [src] starting at [srcCol] to [dstCol] at this
  /// line.
  void copyFrom(BufferLine src, int srcCol, int dstCol, int len) {
    final requiredLength = dstCol + len;
    if (requiredLength > _length) {
      resize(requiredLength);
    }
    final dstEnd = dstCol + len;
    final srcEnd = srcCol + len;
    final leftBoundarySplitsWideCell = dstCol > 0 && srcCol > 0;
    final rightBoundarySplitsWideCell = dstEnd < _length && srcEnd > 0;
    Map<int, String>? copiedCombiningCharacters;
    Map<int, int>? copiedUnderlineColors;
    if (src._combiningCharacters case final combiningCharacters?) {
      for (final entry in combiningCharacters.entries) {
        if (entry.key < srcCol || entry.key >= srcCol + len) continue;
        final destination = dstCol + entry.key - srcCol;
        (copiedCombiningCharacters ??= <int, String>{})[destination] =
            entry.value;
      }
    }
    if (src._underlineColors case final underlineColors?) {
      for (final entry in underlineColors.entries) {
        if (entry.key < srcCol || entry.key >= srcCol + len) continue;
        final destination = dstCol + entry.key - srcCol;
        (copiedUnderlineColors ??= <int, int>{})[destination] = entry.value;
      }
    }

    // data.setRange(
    //   dstCol * _cellSize,
    //   (dstCol + len) * _cellSize,
    //   Uint32List.sublistView(src.data, srcCol * _cellSize, len * _cellSize),
    // );

    _ensureCapacity(dstCol + len - 1);
    src._ensureCapacity(srcCol + len - 1);
    final srcOffset = srcCol * _cellSize;
    final dstOffset = dstCol * _cellSize;
    _data.setRange(
      dstOffset,
      dstOffset + len * _cellSize,
      src._data,
      srcOffset,
    );

    if (_combiningCharacters case final combiningCharacters?) {
      combiningCharacters.removeWhere(
        (index, _) => index >= dstCol && index < dstCol + len,
      );
      if (combiningCharacters.isEmpty) _combiningCharacters = null;
    }
    if (copiedCombiningCharacters case final copied?) {
      _mutableCombiningCharacters.addAll(copied);
    }
    if (_underlineColors case final underlineColors?) {
      underlineColors.removeWhere(
        (index, _) => index >= dstCol && index < dstCol + len,
      );
      if (underlineColors.isEmpty) _underlineColors = null;
    }
    if (copiedUnderlineColors case final copied?) {
      _mutableUnderlineColors.addAll(copied);
    }

    if (leftBoundarySplitsWideCell && getWidth(dstCol) == 0) {
      resetCell(dstCol);
    }
    if (rightBoundarySplitsWideCell && getWidth(dstEnd - 1) == 2) {
      resetCell(dstEnd - 1);
    }
  }

  /// Cells to allocate storage for, for a line of [length] cells.
  ///
  /// The slack exists so that a terminal resize can usually widen a line
  /// without reallocating. It is charged on every line ever created, though,
  /// and scrolling creates one per line of output - so the cheapest thing this
  /// function can do for throughput is not round up very far. Doubling from 64
  /// used to take a 170-column line to 256 cells, half of it never addressed;
  /// rounding to 32 takes it to 192, and measured 12% more `ascii` throughput
  /// and 16% more on long lines in `bin/parse_bench.dart`.
  static int _calcCapacity(int length) {
    assert(length >= 0);

    if (length <= 64) return 64;
    return (length + 31) & ~31;
  }

  String getText([int? from, int? to]) {
    if (from == null || from < 0) {
      from = 0;
    }

    if (to == null || to > _length) {
      to = _length;
    }

    if (from > 0 &&
        from < _length &&
        getWidth(from) == 0 &&
        getWidth(from - 1) == 2) {
      from--;
    }
    if (to > 0 && to < _length && getWidth(to) == 0 && getWidth(to - 1) == 2) {
      to++;
    }

    final trimmedLength = getTrimmedLength();
    final builder = StringBuffer();
    var afterTab = false;
    for (var i = from; i < to; i++) {
      final codePoint = getCodePoint(i);
      final width = getWidth(i);
      if (codePoint == 0) {
        // A blank cell inside the content is a space, unless it is the
        // placeholder half of a wide character or the gap a tab skipped.
        if (i < trimmedLength &&
            !afterTab &&
            (i == 0 || getWidth(i - 1) != 2)) {
          builder.write(' ');
        }
        continue;
      }
      afterTab = codePoint == 0x09;
      if (i + width <= to) {
        builder.writeCharCode(codePoint);
        final combining = _combiningCharacters?[i];
        if (combining != null) {
          builder.write(combining);
        }
      }
    }

    return builder.toString();
  }

  CellAnchor createAnchor(int offset) {
    final anchor = CellAnchor(offset, owner: this);
    _anchors.add(anchor);
    return anchor;
  }

  void dispose() {
    for (final anchor in _anchors.toList()) {
      anchor.dispose();
    }
  }

  @override
  String toString() {
    return getText();
  }
}

/// A handle to a cell in a [BufferLine] that can be used to track the location
/// of the cell. Anchors are guaranteed to be stable, retaining their relative
/// position to each other after mutations to the buffer.
class CellAnchor {
  CellAnchor(int offset, {BufferLine? owner})
      : _offset = offset,
        _owner = owner;

  int _offset;

  int get x {
    return _offset;
  }

  int get y {
    assert(attached);
    return _owner!.index;
  }

  CellOffset get offset {
    assert(attached);
    return CellOffset(_offset, _owner!.index);
  }

  BufferLine? _owner;

  BufferLine? get line => _owner;

  bool get attached => _owner?.attached ?? false;

  void reparent(BufferLine owner, int offset) {
    _owner?._anchors.remove(this);
    _owner = owner;
    _owner?._anchors.add(this);
    _offset = offset;
  }

  void reposition(int offset) {
    _offset = offset;
  }

  void dispose() {
    _owner?._anchors.remove(this);
    _owner = null;
  }

  @override
  String toString() {
    if (attached) {
      return 'CellAnchor($x, $y)';
    } else {
      return 'CellAnchor($x, detached)';
    }
  }
}
