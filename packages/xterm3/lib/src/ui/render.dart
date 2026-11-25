import 'dart:async';
import 'dart:developer' show Timeline;
import 'dart:math' show max, min;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm3/src/core/buffer/buffer.dart';
import 'package:xterm3/src/core/buffer/cell_offset.dart';
import 'package:xterm3/src/core/buffer/line.dart';
import 'package:xterm3/src/core/buffer/range.dart';
import 'package:xterm3/src/core/buffer/range_line.dart';
import 'package:xterm3/src/core/buffer/segment.dart';
import 'package:xterm3/src/core/cell.dart';
import 'package:xterm3/src/core/mouse/button.dart';
import 'package:xterm3/src/core/mouse/button_state.dart';
import 'package:xterm3/src/core/mouse/modifiers.dart';
import 'package:xterm3/src/terminal.dart';
import 'package:xterm3/src/ui/controller.dart';
import 'package:xterm3/src/ui/cursor_type.dart';
import 'package:xterm3/src/ui/painter.dart';
import 'package:xterm3/src/ui/render_stats.dart';
import 'package:xterm3/src/ui/selection_mode.dart';
import 'package:xterm3/src/ui/terminal_size.dart';
import 'package:xterm3/src/ui/terminal_text_style.dart';
import 'package:xterm3/src/ui/terminal_theme.dart';

typedef EditableRectCallback = void Function(Rect rect, Rect caretRect);

class RenderTerminal extends RenderBox with RelayoutWhenSystemFontsChangeMixin {
  RenderTerminal({
    required Terminal terminal,
    required TerminalController controller,
    required ViewportOffset offset,
    required EdgeInsets padding,
    required bool autoResize,
    required double backgroundOpacity,
    required TerminalStyle textStyle,
    required TextScaler textScaler,
    required double devicePixelRatio,
    required TerminalTheme theme,
    required FocusNode focusNode,
    required TerminalCursorType cursorType,
    required bool alwaysShowCursor,
    int? activeHyperlinkId,
    EditableRectCallback? onEditableRect,
    String? composingText,
    String? predictionText,
  })  : _terminal = terminal,
        _controller = controller,
        _offset = offset,
        _padding = padding,
        _autoResize = autoResize,
        _backgroundOpacity = backgroundOpacity,
        _focusNode = focusNode,
        _cursorType = cursorType,
        _alwaysShowCursor = alwaysShowCursor,
        _activeHyperlinkId = activeHyperlinkId,
        _onEditableRect = onEditableRect,
        _composingText = composingText,
        _predictionText = predictionText,
        _painter = TerminalPainter(
          theme: theme,
          textStyle: textStyle,
          textScaler: textScaler,
          devicePixelRatio: devicePixelRatio,
        );

  Terminal _terminal;
  set terminal(Terminal terminal) {
    if (_terminal == terminal) return;
    if (attached) _terminal.removeListener(_onTerminalChange);
    _terminal = terminal;
    _recordTerminalLayoutState();
    if (attached) _terminal.addListener(_onTerminalChange);
    _resizeTerminalIfNeeded();
    markNeedsLayout();
  }

  TerminalController _controller;
  set controller(TerminalController controller) {
    if (_controller == controller) return;
    if (attached) _controller.removeListener(_onControllerUpdate);
    _controller = controller;
    if (attached) _controller.addListener(_onControllerUpdate);
    markNeedsPaint();
  }

  ViewportOffset _offset;
  set offset(ViewportOffset value) {
    if (value == _offset) return;
    if (attached) _offset.removeListener(_onScroll);
    _offset = value;
    if (attached) _offset.addListener(_onScroll);
    markNeedsLayout();
  }

  EdgeInsets _padding;
  set padding(EdgeInsets value) {
    if (value == _padding) return;
    _padding = value;
    markNeedsLayout();
  }

  bool _autoResize;
  set autoResize(bool value) {
    if (value == _autoResize) return;
    _autoResize = value;
    markNeedsLayout();
  }

  double _backgroundOpacity;
  set backgroundOpacity(double value) {
    if (value == _backgroundOpacity) return;
    _backgroundOpacity = value;
    markNeedsPaint();
  }

  set textStyle(TerminalStyle value) {
    if (value == _painter.textStyle) return;
    _painter.textStyle = value;
    markNeedsLayout();
  }

  set textScaler(TextScaler value) {
    if (value == _painter.textScaler) return;
    _painter.textScaler = value;
    markNeedsLayout();
  }

  set devicePixelRatio(double value) {
    if (value == _painter.devicePixelRatio) return;
    _painter.devicePixelRatio = value;
    markNeedsLayout();
  }

  set theme(TerminalTheme value) {
    if (value == _painter.theme) return;
    _painter.theme = value;
    markNeedsPaint();
  }

  FocusNode _focusNode;
  set focusNode(FocusNode value) {
    if (value == _focusNode) return;
    if (attached) _focusNode.removeListener(_onFocusChange);
    _focusNode = value;
    if (attached) _focusNode.addListener(_onFocusChange);
    markNeedsPaint();
  }

  TerminalCursorType _cursorType;
  set cursorType(TerminalCursorType value) {
    if (value == _cursorType) return;
    _cursorType = value;
    markNeedsPaint();
  }

  bool _alwaysShowCursor;
  set alwaysShowCursor(bool value) {
    if (value == _alwaysShowCursor) return;
    _alwaysShowCursor = value;
    markNeedsPaint();
  }

  int? get activeHyperlinkId => _activeHyperlinkId;
  int? _activeHyperlinkId;
  set activeHyperlinkId(int? value) {
    if (value == _activeHyperlinkId) return;
    _activeHyperlinkId = value;
    markNeedsPaint();
  }

  EditableRectCallback? _onEditableRect;
  set onEditableRect(EditableRectCallback? value) {
    if (value == _onEditableRect) return;
    _onEditableRect = value;
    markNeedsLayout();
  }

  String? _composingText;
  set composingText(String? value) {
    if (value == _composingText) return;
    _composingText = value;
    markNeedsPaint();
  }

  String? _predictionText;
  set predictionText(String? value) {
    if (value == _predictionText) return;
    _predictionText = value;
    markNeedsPaint();
  }

  TerminalSize? _viewportSize;

  final TerminalPainter _painter;

  /// Reused by the per-frame fills and by [_paintUnderline], which runs once
  /// per visible underline segment.
  final _fillPaint = Paint();
  final _underlinePaint = Paint();

  var _stickToBottom = true;

  Timer? _cursorBlinkTimer;

  Timer? _cursorBlinkTimeout;

  Timer? _textBlinkTimer;

  bool _cursorBlinkVisible = true;

  bool _cursorBlinkWasEnabled = false;

  bool _textBlinkVisible = true;

  bool get isCursorBlinkVisible => _cursorBlinkVisible;

  Color? debugBackgroundFillColor() {
    _updatePainterColorState();
    final backgroundOverride = _painter.backgroundColorOverride;
    if (backgroundOverride == null) return null;
    return backgroundOverride.withValues(alpha: _backgroundOpacity);
  }

  var _lastTerminalLineCount = 0;

  var _lastTerminalWidth = 0;

  var _lastTerminalHeight = 0;

  var _lastForceScrollToBottomGeneration = 0;

  Buffer? _lastTerminalBuffer;

  /// The max scroll extent last applied to [_offset]. The scroll position
  /// clamps to this, not to the live [_maxScrollExtent], until the next layout.
  var _appliedMaxScrollExtent = 0.0;

  /// The line list and its trim count as of the last layout, used to keep a
  /// scrolled-up view on the same text while a full scrollback drops lines.
  Object? _layoutLines;
  var _layoutTrimmedLines = 0;

  void _onScroll() {
    _stickToBottom = _scrollOffset >= _appliedMaxScrollExtent;
    markNeedsLayout();
    _markEditableRectDirty();
  }

  void _onFocusChange() {
    _updateCursorBlinking(force: true);
    markNeedsPaint();
  }

  void _onTerminalChange() {
    _updateCursorBlinking();
    final bufferChanged = !identical(_terminal.buffer, _lastTerminalBuffer);
    if (bufferChanged && _controller.selection != null) {
      _controller.clearSelection();
    }
    final forceScrollToBottom =
        _terminal.buffer.forceScrollToBottomGeneration !=
            _lastForceScrollToBottomGeneration;
    if (forceScrollToBottom) {
      _stickToBottom = true;
    }
    final needsLayout = forceScrollToBottom ||
        _terminal.buffer.lines.length != _lastTerminalLineCount ||
        (!_stickToBottom &&
            _terminal.buffer.lines.absoluteStartIndex != _layoutTrimmedLines) ||
        _terminal.viewWidth != _lastTerminalWidth ||
        _terminal.viewHeight != _lastTerminalHeight;
    _recordTerminalLayoutState();
    if (needsLayout) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
    _markEditableRectDirty();
  }

  void _recordTerminalLayoutState() {
    _lastTerminalBuffer = _terminal.buffer;
    _lastTerminalLineCount = _terminal.buffer.lines.length;
    _lastTerminalWidth = _terminal.viewWidth;
    _lastTerminalHeight = _terminal.viewHeight;
    _lastForceScrollToBottomGeneration =
        _terminal.buffer.forceScrollToBottomGeneration;
  }

  void _onControllerUpdate() {
    markNeedsPaint();
  }

  @override
  final isRepaintBoundary = true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _recordTerminalLayoutState();
    _offset.addListener(_onScroll);
    _terminal.addListener(_onTerminalChange);
    _controller.addListener(_onControllerUpdate);
    _focusNode.addListener(_onFocusChange);
    _updateCursorBlinking(force: true);
  }

  @override
  void detach() {
    _stopCursorBlinking();
    _stopTextBlinking();
    _offset.removeListener(_onScroll);
    _terminal.removeListener(_onTerminalChange);
    _controller.removeListener(_onControllerUpdate);
    _focusNode.removeListener(_onFocusChange);
    super.detach();
  }

  @override
  void dispose() {
    _stopCursorBlinking();
    _stopTextBlinking();
    _painter.dispose();
    super.dispose();
  }

  void _updateCursorBlinking({bool force = false}) {
    final enabled = _terminal.cursorBlinkMode && _focusNode.hasFocus;
    final blinkTimerActive = _cursorBlinkTimer != null;
    if (!force &&
        enabled == _cursorBlinkWasEnabled &&
        (!enabled || blinkTimerActive)) {
      return;
    }

    _stopCursorBlinking();
    _cursorBlinkWasEnabled = enabled;
    _cursorBlinkVisible = true;
    if (!enabled || !attached) return;

    _cursorBlinkTimer = Timer.periodic(
      const Duration(milliseconds: 750),
      (_) {
        _cursorBlinkVisible = !_cursorBlinkVisible;
        if (_isCursorRowVisible) markNeedsPaint();
      },
    );
    _cursorBlinkTimeout = Timer(const Duration(seconds: 5), () {
      _cursorBlinkTimer?.cancel();
      _cursorBlinkTimer = null;
      final wasHidden = !_cursorBlinkVisible;
      _cursorBlinkVisible = true;
      if (wasHidden && _isCursorRowVisible) markNeedsPaint();
    });
  }

  /// Whether a change of [_cursorBlinkVisible] can affect what is on screen.
  ///
  /// Toggling the blink phase repaints the whole viewport, so it is only worth
  /// doing when the phase is actually observable: the cursor must be drawn at
  /// all, must not be pinned visible, and its row must be scrolled into view.
  bool get _isCursorRowVisible {
    if (!hasSize) return false;
    if (_alwaysShowCursor || _isComposingText) return false;
    if (!_terminal.cursorVisibleMode) return false;

    final cursorRow = _terminal.buffer.absoluteCursorY;
    final (firstLine, lastLine) = _visibleLineRange(
      _terminal.buffer.lines.length,
      _scrollOffset,
      _scrollOffset + _viewportHeight,
      _painter.cellSize.height,
    );
    return cursorRow >= firstLine && cursorRow <= lastLine;
  }

  void _stopCursorBlinking() {
    _cursorBlinkTimer?.cancel();
    _cursorBlinkTimeout?.cancel();
    _cursorBlinkTimer = null;
    _cursorBlinkTimeout = null;
    _cursorBlinkVisible = true;
  }

  void _updateTextBlinking(bool enabled) {
    if (!enabled) {
      _stopTextBlinking();
      return;
    }
    if (_textBlinkTimer != null || !attached) return;

    _textBlinkTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        _textBlinkVisible = !_textBlinkVisible;
        markNeedsPaint();
      },
    );
  }

  void _stopTextBlinking() {
    _textBlinkTimer?.cancel();
    _textBlinkTimer = null;
    _textBlinkVisible = true;
  }

  @override
  bool hitTestSelf(Offset position) {
    return true;
  }

  @override
  void systemFontsDidChange() {
    _painter.clearFontCache();
    super.systemFontsDidChange();
  }

  @override
  void performLayout() {
    size = constraints.biggest;

    _updateViewportSize();
    _recordTerminalLayoutState();

    _updateScrollOffset();

    final lines = _terminal.buffer.lines;
    if (_stickToBottom) {
      _offset.correctBy(_maxScrollExtent - _scrollOffset);
    } else if (identical(lines, _layoutLines)) {
      final trimmed = lines.absoluteStartIndex - _layoutTrimmedLines;
      if (trimmed > 0) {
        _offset.correctBy(-min(trimmed * lineHeight, _scrollOffset));
      }
    }
    _layoutLines = lines;
    _layoutTrimmedLines = lines.absoluteStartIndex;
  }

  /// Total height of the terminal in pixels. Includes scrollback buffer.
  double get _terminalHeight =>
      _terminal.buffer.lines.length * _painter.cellSize.height;

  /// The distance from the top of the terminal to the top of the viewport.
  // double get _scrollOffset => _offset.pixels;
  double get _scrollOffset {
    // return _offset.pixels ~/ _painter.cellSize.height * _painter.cellSize.height;
    return _offset.pixels;
  }

  /// The height of a terminal line in pixels. This includes the line spacing.
  /// Height of the entire terminal is expected to be a multiple of this value.
  double get lineHeight => _painter.cellSize.height;

  /// Get the top-left corner of the cell at [cellOffset] in pixels.
  Offset getOffset(CellOffset cellOffset) {
    final row = cellOffset.y;
    final col = cellOffset.x;
    final x = col * _painter.cellSize.width;
    final y = row * _painter.cellSize.height;
    return Offset(x + _padding.left, y + _padding.top - _scrollOffset);
  }

  /// Get the [CellOffset] of the cell that [offset] is in.
  CellOffset getCellOffset(Offset offset) {
    final x = offset.dx - _padding.left;
    final y = offset.dy - _padding.top + _scrollOffset;
    final row = y ~/ _painter.cellSize.height;
    final col = x ~/ _painter.cellSize.width;
    return CellOffset(
      col.clamp(0, _terminal.viewWidth - 1),
      row.clamp(0, _terminal.buffer.lines.length - 1),
    );
  }

  /// A [CellAnchor] on the cell that [offset] is in, in the active buffer.
  ///
  /// Unlike [offset], the anchor keeps naming that cell when the viewport
  /// scrolls or scrollback is trimmed. The caller owns it and disposes it.
  CellAnchor createAnchorAt(Offset offset) {
    return _terminal.buffer.createAnchorFromOffset(getCellOffset(offset));
  }

  /// Get the viewport-local [CellOffset] of the cell that [offset] is in.
  ///
  /// Mouse reports are screen-relative, not scrollback-buffer-relative.
  CellOffset _getViewportCellOffset(Offset offset) {
    final x = offset.dx - _padding.left;
    final y = _viewportY(offset.dy);
    final row = y ~/ _painter.cellSize.height;
    final col = x ~/ _painter.cellSize.width;
    return CellOffset(
      col.clamp(0, _terminal.viewWidth - 1),
      row.clamp(0, _terminal.viewHeight - 1),
    );
  }

  /// Distance from the top of the screen (buffer row [Buffer.scrollBack]) to
  /// [dy], using the same mapping as [getCellOffset]. Once there is
  /// scrollback the content is bottom-aligned, so the screen does not start at
  /// the top padding.
  double _viewportY(double dy) {
    return dy -
        _padding.top +
        _scrollOffset -
        _terminal.buffer.scrollBack * _painter.cellSize.height;
  }

  CellOffset _getViewportPixelOffset(Offset offset) {
    final x = (offset.dx - _padding.left).floor();
    final y = _viewportY(offset.dy).floor();
    final maxX =
        max(0, (_terminal.viewWidth * _painter.cellSize.width).floor());
    final maxY =
        max(0, (_terminal.viewHeight * _painter.cellSize.height).floor());
    return CellOffset(
      x.clamp(0, max(0, maxX - 1)),
      y.clamp(0, max(0, maxY - 1)),
    );
  }

  /// Selects entire words in the terminal that contains [from] and [to].
  ///
  /// A cell that is not part of a word — a space, a separator, or one of the
  /// empty cells that make up most of a sparse screen — selects itself rather
  /// than selecting nothing. This is the entry point for touch selection, and
  /// bailing out left a long press on blank space with no selection at all and
  /// no way to grow one: every later drag update re-reads the same blank
  /// starting cell and bails again.
  void selectWord(Offset from, [Offset? to]) {
    _selectWordCells(
        getCellOffset(from), to == null ? null : getCellOffset(to));
  }

  /// Selects entire words from the cell [from] holds to the cell under [to].
  ///
  /// The press that started the selection is held as an anchor rather than as
  /// a pixel offset: a pixel names a different line as soon as the viewport
  /// scrolls, and resolving it again on every move dragged the start of the
  /// selection along with the scroll. Does nothing when [from] no longer
  /// belongs to the active buffer.
  void selectWordFrom(CellAnchor from, Offset to) {
    if (!_terminal.buffer.ownsAnchor(from)) return;
    _selectWordCells(from.offset, getCellOffset(to));
  }

  void _selectWordCells(CellOffset from, CellOffset? to) {
    final fromBoundary = _wordOrCellBoundary(from);
    if (to == null) {
      _controller.setSelection(
        _terminal.buffer.createAnchorFromOffset(fromBoundary.begin),
        _terminal.buffer.createAnchorFromOffset(fromBoundary.end),
        mode: SelectionMode.line,
      );
    } else {
      final toBoundary = _wordOrCellBoundary(to);
      final range = fromBoundary.merge(toBoundary);
      _controller.setSelection(
        _terminal.buffer.createAnchorFromOffset(range.begin),
        _terminal.buffer.createAnchorFromOffset(range.end),
        mode: SelectionMode.line,
      );
    }
  }

  /// The word [position] is part of, or the single cell it lands on when it is
  /// part of none.
  BufferRangeLine _wordOrCellBoundary(CellOffset position) {
    final boundary = _terminal.buffer.getWordBoundary(position);
    if (boundary != null) return boundary;
    return BufferRangeLine(
      _cellSelectionStart(position),
      _cellSelectionEnd(position),
    );
  }

  /// Selects entire visual lines in the terminal that contain [from] and [to].
  ///
  /// Soft-wrapped rows are treated as one logical line, matching terminal
  /// triple-click selection behavior.
  void selectLine(Offset from, [Offset? to]) {
    final fromOffset = getCellOffset(from);
    final fromBoundary = _terminal.buffer.getLineBoundary(fromOffset);
    if (fromBoundary == null) return;
    if (to == null) {
      _controller.setSelection(
        _terminal.buffer.createAnchorFromOffset(fromBoundary.begin),
        _terminal.buffer.createAnchorFromOffset(fromBoundary.end),
        mode: SelectionMode.line,
      );
    } else {
      final toOffset = getCellOffset(to);
      final toBoundary = _terminal.buffer.getLineBoundary(toOffset);
      if (toBoundary == null) return;
      final range = fromBoundary.merge(toBoundary);
      _controller.setSelection(
        _terminal.buffer.createAnchorFromOffset(range.begin),
        _terminal.buffer.createAnchorFromOffset(range.end),
        mode: SelectionMode.line,
      );
    }
  }

  /// Selects characters in the terminal that starts from [from] to [to]. At
  /// least one cell is selected even if [from] and [to] are same.
  void selectCharacters(
    Offset from, [
    Offset? to,
    SelectionMode mode = SelectionMode.line,
  ]) {
    _selectCharacterCells(
      getCellOffset(from),
      to == null ? null : getCellOffset(to),
      mode,
    );
  }

  /// Selects characters from the cell [from] holds to the cell under [to].
  ///
  /// See [selectWordFrom] for why the start is an anchor. Does nothing when
  /// [from] no longer belongs to the active buffer.
  void selectCharactersFrom(
    CellAnchor from,
    Offset to, [
    SelectionMode mode = SelectionMode.line,
  ]) {
    if (!_terminal.buffer.ownsAnchor(from)) return;
    _selectCharacterCells(from.offset, getCellOffset(to), mode);
  }

  void _selectCharacterCells(
    CellOffset fromPosition,
    CellOffset? toPosition,
    SelectionMode mode,
  ) {
    final fromStart = _cellSelectionStart(fromPosition);
    final fromEnd = _cellSelectionEnd(fromPosition);
    if (toPosition == null) {
      _controller.setSelection(
        _terminal.buffer.createAnchorFromOffset(fromStart),
        _terminal.buffer.createAnchorFromOffset(fromEnd),
        mode: mode,
      );
    } else {
      if (toPosition.isAfterOrSame(fromPosition)) {
        _controller.setSelection(
          _terminal.buffer.createAnchorFromOffset(fromStart),
          _terminal.buffer.createAnchorFromOffset(
            _cellSelectionEnd(toPosition),
          ),
          mode: mode,
        );
        return;
      }
      _controller.setSelection(
        _terminal.buffer.createAnchorFromOffset(fromEnd),
        _terminal.buffer.createAnchorFromOffset(
          _cellSelectionStart(toPosition),
        ),
        mode: mode,
      );
    }
  }

  CellOffset _cellSelectionStart(CellOffset position) {
    final line = _terminal.buffer.lines[position.y];
    if (position.x > 0 &&
        line.getWidth(position.x) == 0 &&
        line.getWidth(position.x - 1) == 2) {
      return CellOffset(position.x - 1, position.y);
    }
    return position;
  }

  CellOffset _cellSelectionEnd(CellOffset position) {
    final start = _cellSelectionStart(position);
    final line = _terminal.buffer.lines[start.y];
    final width = switch (line.getWidth(start.x)) {
      2 => 2,
      _ => 1,
    };
    return CellOffset(
      min(start.x + width, _terminal.viewWidth),
      start.y,
    );
  }

  /// Send a mouse event at [offset] with [button] being currently in [buttonState].
  bool mouseEvent(
    TerminalMouseButton button,
    TerminalMouseButtonState buttonState,
    Offset offset, {
    bool motion = false,
    TerminalMouseModifiers modifiers = TerminalMouseModifiers.none,
  }) {
    final position = _getViewportCellOffset(offset);
    return _terminal.mouseInput(
      button,
      buttonState,
      position,
      motion: motion,
      modifiers: modifiers,
      pixelPosition: _getViewportPixelOffset(offset),
    );
  }

  /// Set when the cursor rect may have moved, cleared once it has been
  /// reported. See [_notifyEditableRect].
  var _editableRectDirty = false;

  /// Marks the editable rect as needing to be reported after the next paint.
  ///
  /// [_notifyEditableRect] walks to the root through [localToGlobal], and it
  /// used to run inline on every terminal change. A PTY hands over dozens of
  /// small chunks between frames and each one is a `Terminal.write`, so that
  /// was dozens of ancestor walks per frame to report a rect that can only be
  /// observed once, after the frame. Deferring collapses them into one.
  void _markEditableRectDirty() {
    _editableRectDirty = true;
  }

  void _notifyEditableRect() {
    _editableRectDirty = false;

    final onEditableRect = _onEditableRect;
    if (onEditableRect == null) return;

    final cursor = localToGlobal(cursorOffset);

    final rect = Rect.fromLTRB(
      cursor.dx,
      cursor.dy,
      size.width,
      cursor.dy + _painter.cellSize.height,
    );

    final caretRect = cursor & cursorSize;

    onEditableRect(rect, caretRect);
  }

  /// Update the viewport size in cells based on the current widget size in
  /// pixels.
  void _updateViewportSize() {
    final viewportWidth = size.width - _padding.horizontal;
    final viewportHeight = _viewportHeight;
    if (viewportWidth < _painter.cellSize.width ||
        viewportHeight < _painter.cellSize.height) {
      return;
    }

    final viewportSize = TerminalSize(
      viewportWidth ~/ _painter.cellSize.width,
      viewportHeight ~/ _painter.cellSize.height,
    );

    if (_viewportSize != viewportSize) {
      _viewportSize = viewportSize;
      _resizeTerminalIfNeeded();
    }
  }

  /// Notify the underlying terminal that the viewport size has changed.
  void _resizeTerminalIfNeeded() {
    if (!_autoResize) {
      return;
    }
    if (_viewportSize case final viewportSize?) {
      _terminal.resize(
        viewportSize.width,
        viewportSize.height,
        _painter.cellSize.width.round(),
        _painter.cellSize.height.round(),
      );
    }
  }

  /// Update the scroll offset based on the current terminal state. This should
  /// be called in [performLayout] after the viewport size has been updated.
  void _updateScrollOffset() {
    _offset.applyViewportDimension(_viewportHeight);
    _appliedMaxScrollExtent = _maxScrollExtent;
    _offset.applyContentDimensions(0, _appliedMaxScrollExtent);
  }

  bool get _isComposingText {
    if (_composingText case final composingText?) {
      return composingText.isNotEmpty;
    }
    return false;
  }

  /// Whether the caller-supplied [_predictionText] should be painted.
  ///
  /// IME composition always wins: a user actively composing a character must
  /// not also see a speculative prediction drawn at the same spot.
  bool get _isShowingPrediction {
    if (_isComposingText) return false;
    if (_predictionText case final predictionText?) {
      return predictionText.isNotEmpty;
    }
    return false;
  }

  bool get _shouldShowCursor {
    if (_alwaysShowCursor || _isComposingText) return true;
    if (!_terminal.cursorVisibleMode) return false;
    if (!_terminal.cursorBlinkMode || !_focusNode.hasFocus) return true;
    return _cursorBlinkVisible;
  }

  double get _viewportHeight {
    return max(size.height - _padding.vertical, 0);
  }

  double get _maxScrollExtent {
    return max(_terminalHeight - _viewportHeight, 0.0);
  }

  double get _lineOffset {
    return -_scrollOffset + _padding.top;
  }

  /// The offset of the cursor from the top left corner of this render object.
  Offset get cursorOffset {
    return _lineOrigin(
      Offset.zero,
      _terminal.buffer.absoluteCursorY,
      column: _cursorRenderColumn(),
    );
  }

  Size get cellSize {
    return _painter.cellSize;
  }

  Size get cursorSize {
    final cursorWidth = _cursorRenderWidth(_cursorRenderColumn());
    return Size(
      _painter.cellSize.width * cursorWidth,
      _painter.cellSize.height,
    );
  }

  /// Rounds a logical pixel position onto the device pixel grid. Cell metrics
  /// are already a whole number of device pixels, so snapping the origin of the
  /// grid keeps every row and column aligned with physical pixels instead of
  /// drifting through subpixel phases.
  double _snapToDevicePixels(double value) {
    final ratio = _painter.devicePixelRatio;
    if (!ratio.isFinite || ratio <= 0) return value;
    return (value * ratio).roundToDouble() / ratio;
  }

  /// Origin of [line] (optionally offset by [column] cells) in absolute paint
  /// coordinates, snapped onto the device pixel grid. Cell metrics are already
  /// a whole number of device pixels, so snapping the origin keeps every row
  /// and column aligned with physical pixels instead of drifting through
  /// subpixel phases.
  Offset _lineOrigin(Offset paintOffset, int line, {int column = 0}) {
    return Offset(
      _snapToDevicePixels(
        paintOffset.dx + _padding.left + column * _painter.cellSize.width,
      ),
      _snapToDevicePixels(
        paintOffset.dy + line * _painter.cellSize.height + _lineOffset,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.save();
    canvas.clipRect(offset & size);
    TerminalRenderStats.paints++;
    // Rows on screen, not rows in the terminal: without auto-resize the view
    // can be taller than the terminal's own grid.
    _painter.fitParagraphCacheToGrid(
      _terminal.viewWidth,
      max(
        _terminal.viewHeight,
        (size.height / _painter.cellSize.height).ceil(),
      ),
    );
    if (kReleaseMode) {
      _paint(context, offset);
    } else {
      // Named so it can be picked out of a `--trace-skia` timeline: everything
      // the terminal contributes to the UI thread's frame is inside this
      // slice. Release builds skip it - timeline slices are not free, and
      // nothing is listening there.
      Timeline.timeSync('RenderTerminal.paint', () => _paint(context, offset));
    }
    canvas.restore();
    context.setWillChangeHint();

    // Flush here rather than from every terminal change: this is the point
    // where the cursor has settled for the frame, and `localToGlobal` is one
    // walk instead of one per chunk the PTY delivered.
    if (_editableRectDirty) _notifyEditableRect();
  }

  /// Paints the terminal in four passes, in this order:
  ///
  ///  1. [_paintStaticBackgrounds] - one background run per visible line.
  ///  2. [_paintOverlayBackgrounds] - cursor line highlight, search, custom
  ///     highlights, selection, and the block cursor rectangle.
  ///  3. [_paintStaticForegrounds] - the glyphs of every visible line.
  ///  4. [_paintOverlayForegrounds] - text that overlays redraw in their own
  ///     colors, underlines, composing text, and non-block cursors.
  ///
  /// The two static passes are the ones whose output depends only on the
  /// buffer, and are what a line cache would record. They are deliberately
  /// *not* adjacent: the overlays in pass 2 have to land on top of the
  /// backgrounds and underneath the glyphs, so a cache cannot record a line's
  /// background and foreground into a single replayable unit. Anything that
  /// caches has to keep these as two separate recordings with pass 2 between
  /// them.
  void _paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    _updatePainterColorState();

    _paintSurface(canvas, offset);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(
      offset.dx + _padding.left,
      offset.dy + _padding.top,
      max(size.width - _padding.horizontal, 0),
      _viewportHeight,
    ));

    final lines = _terminal.buffer.lines;

    final (effectFirstLine, effectLastLine) = _visibleLineRange(
      lines.length,
      _scrollOffset,
      _scrollOffset + _viewportHeight,
      _painter.cellSize.height,
    );

    TerminalRenderStats.paintedLines += effectLastLine - effectFirstLine + 1;

    final cursor = _resolveCursorPaintState(effectFirstLine, effectLastLine);
    final selection = _controller.selectionFor(_terminal.buffer);

    _paintStaticBackgrounds(canvas, offset, effectFirstLine, effectLastLine);
    _paintOverlayBackgrounds(
      canvas,
      offset,
      effectFirstLine,
      effectLastLine,
      cursor,
      selection,
    );
    _paintStaticForegrounds(
      canvas,
      offset,
      effectFirstLine,
      effectLastLine,
      cursor,
    );
    _paintOverlayForegrounds(
      canvas,
      offset,
      effectFirstLine,
      effectLastLine,
      cursor,
      selection,
    );

    canvas.restore();
  }

  /// Fills the whole render box before any cell is drawn. Outside the viewport
  /// clip because the padding around the grid takes these colors too.
  void _paintSurface(Canvas canvas, Offset offset) {
    final backgroundOverride = _painter.backgroundColorOverride;
    if (backgroundOverride != null) {
      final paint = _fillPaint
        ..color = backgroundOverride.withValues(alpha: _backgroundOpacity);
      canvas.drawRect(offset & size, paint);
    }

    if (_terminal.reverseDisplayMode) {
      final paint = _fillPaint
        ..color =
            _painter.foregroundColor.withValues(alpha: _backgroundOpacity);
      canvas.drawRect(offset & size, paint);
    }
  }

  /// Everything about the cursor that the paint passes need, resolved once.
  ///
  /// Each of these reads the cursor cell out of the buffer, so resolving them
  /// per pass would repeat the same lookups three times for one frame.
  _CursorPaintState _resolveCursorPaintState(int firstLine, int lastLine) {
    final type = _terminal.applicationCursorType ?? _cursorType;
    final isRowVisible = _terminal.buffer.absoluteCursorY >= firstLine &&
        _terminal.buffer.absoluteCursorY <= lastLine;
    final shouldPaint = isRowVisible && _shouldShowCursor;
    final shouldPaintBlock = shouldPaint && type == TerminalCursorType.block;
    final column = _cursorRenderColumn();
    final colors = _cursorColors(column);
    final invertsCell = shouldPaintBlock && _focusNode.hasFocus;

    return _CursorPaintState(
      type: type,
      isRowVisible: isRowVisible,
      shouldPaint: shouldPaint,
      shouldPaintBlock: shouldPaintBlock,
      hasFocus: _focusNode.hasFocus,
      column: column,
      width: _cursorRenderWidth(column),
      background: colors.background,
      // A block cursor with focus inverts the cell under it; every other case
      // leaves the glyph alone, and this color goes unused.
      foreground: switch (invertsCell) {
        true => colors.foreground,
        false => _painter.backgroundColor,
      },
    );
  }

  /// Pass 1: the background of every visible line.
  ///
  /// Depends only on the buffer, the palette and the cell size.
  void _paintStaticBackgrounds(
    Canvas canvas,
    Offset offset,
    int firstLine,
    int lastLine,
  ) {
    final lines = _terminal.buffer.lines;
    for (var i = firstLine; i <= lastLine; i++) {
      _painter.paintLineBackgrounds(
        canvas,
        _lineOrigin(offset, i),
        lines[i],
      );
    }
  }

  /// Pass 2: fills that sit on top of the line backgrounds and underneath the
  /// glyphs. All of it can change without the buffer changing.
  void _paintOverlayBackgrounds(
    Canvas canvas,
    Offset offset,
    int firstLine,
    int lastLine,
    _CursorPaintState cursor,
    BufferRange? selection,
  ) {
    if (_terminal.cursorLineHighlightMode &&
        _terminal.buffer.absoluteCursorY >= firstLine &&
        _terminal.buffer.absoluteCursorY <= lastLine) {
      final paint = _fillPaint..color = _painter.cursorLineHighlightColor;
      canvas.drawRect(
        Rect.fromLTWH(
          _snapToDevicePixels(offset.dx + _padding.left),
          _lineOrigin(offset, _terminal.buffer.absoluteCursorY).dy,
          max(size.width - _padding.horizontal, 0),
          _painter.cellSize.height,
        ),
        paint,
      );
    }

    _paintSearchHighlightBackgrounds(canvas, offset, firstLine, lastLine);

    _paintHighlights(
      canvas,
      offset,
      _controller.highlights,
      firstLine,
      lastLine,
    );

    if (selection != null) {
      _paintSelection(canvas, offset, selection, firstLine, lastLine);
    }

    // The block cursor rectangle goes down before the glyphs so the inverted
    // character in pass 3 lands on top of it.
    if (cursor.invertsCell) {
      _painter.paintCursor(
        canvas,
        _cursorRenderOffset(offset, cursor.column),
        cursorType: cursor.type,
        cellWidth: cursor.width,
        color: cursor.background,
      );
    }
  }

  /// Pass 3: the glyphs of every visible line.
  ///
  /// Two things keep this from depending on the buffer alone, and both have to
  /// be dealt with before a line can be cached:
  ///  - the cell under a focused block cursor is drawn in inverted colors, so
  ///    the cursor's row differs from what the buffer says;
  ///  - [_textBlinkVisible] hides cells with the blink attribute for half of
  ///    the blink cycle.
  void _paintStaticForegrounds(
    Canvas canvas,
    Offset offset,
    int firstLine,
    int lastLine,
    _CursorPaintState cursor,
  ) {
    final lines = _terminal.buffer.lines;
    var hasBlinkingText = false;

    for (var i = firstLine; i <= lastLine; i++) {
      hasBlinkingText = _painter.paintLineForegrounds(
            canvas,
            _lineOrigin(offset, i),
            lines[i],
            blinkVisible: _textBlinkVisible,
            activeHyperlinkId: _activeHyperlinkId,
            cursorColumn: switch (
                cursor.invertsCell && i == _terminal.buffer.absoluteCursorY) {
              true => cursor.column,
              false => null,
            },
            cursorForeground: cursor.foreground,
          ) ||
          hasBlinkingText;
    }

    // Starts or stops the blink timer for the next frame. Has to run after the
    // whole loop: a single blinking cell anywhere keeps the timer alive.
    _updateTextBlinking(hasBlinkingText);
  }

  /// Pass 4: text redrawn in an overlay's own colors, decorations, and the
  /// cursors that go on top of the glyphs rather than underneath them.
  void _paintOverlayForegrounds(
    Canvas canvas,
    Offset offset,
    int firstLine,
    int lastLine,
    _CursorPaintState cursor,
    BufferRange? selection,
  ) {
    _paintSearchHighlightForegrounds(
      canvas,
      offset,
      firstLine,
      lastLine,
      cursorColumn: cursor.invertedColumn,
      cursorForeground: cursor.foreground,
    );

    if (selection != null) {
      _paintSelectionForegrounds(
        canvas,
        offset,
        selection,
        firstLine,
        lastLine,
        _painter.selectionForegroundColor,
        cursorColumn: cursor.invertedColumn,
        cursorForeground: cursor.foreground,
      );
    }

    _paintUnderlines(
      canvas,
      offset,
      _controller.underlines,
      firstLine,
      lastLine,
    );

    // Predicted text is anchored to the cursor but is not part of it: it has
    // to stay readable while the cursor blinks off, and while an application
    // has hidden the cursor entirely. So it is gated on the row being visible
    // rather than on the cursor being painted.
    if (_isShowingPrediction && cursor.isRowVisible) {
      _paintCursorText(canvas, offset, cursorOffset, _predictionText);
    }

    if (!cursor.shouldPaint) return;

    // Composing text keeps the cursor forced visible (see _shouldShowCursor),
    // so it can stay behind that guard.
    if (_isComposingText) {
      _paintCursorText(canvas, offset, cursorOffset, _composingText);
    }

    // The focused block cursor already went down in pass 2, underneath the
    // glyph it inverts. Every other cursor is drawn over the text.
    if (!cursor.invertsCell) {
      _painter.paintCursor(
        canvas,
        _cursorRenderOffset(offset, cursor.column),
        cursorType: cursor.type,
        hasFocus: cursor.hasFocus,
        cellWidth: cursor.width,
        color: cursor.background,
      );
    }
  }

  void _updatePainterColorState() {
    _painter.updateColorOverrides(
      _terminal,
      _terminal.colorRevision,
      _terminal.indexedColorOverrides,
      _terminal.specialColorOverrides,
      _terminal.foregroundColorOverride,
      _terminal.backgroundColorOverride,
      _terminal.cursorColorOverride,
      _terminal.selectionColorOverride,
      _terminal.selectionForegroundColorOverride,
    );
    _painter.reverseDisplay = _terminal.reverseDisplayMode;
  }

  @visibleForTesting
  bool debugCursorBlinkNeedsPaint() {
    return _isCursorRowVisible;
  }

  @visibleForTesting
  (int, int) debugVisibleLineRange() {
    return _visibleLineRange(
      _terminal.buffer.lines.length,
      _scrollOffset,
      _scrollOffset + _viewportHeight,
      _painter.cellSize.height,
    );
  }

  @visibleForTesting
  double debugComposingTextStart(double cursorX, double textWidth) {
    return _composingTextStart(cursorX, textWidth);
  }

  /// Whether [predictionText] is currently taking the paint path - i.e. it is
  /// non-empty and IME composition is not active. Painted pixels aren't
  /// practical to assert on in widget tests, so this exposes the same
  /// decision the paint method makes.
  @visibleForTesting
  bool get debugIsShowingPrediction => _isShowingPrediction;

  int _debugCursorTextPaints = 0;

  /// How many times cursor-anchored text has actually been drawn.
  ///
  /// Counted inside the paint helper itself rather than recomputed from the
  /// same conditions, so a test can pin that a prediction really is drawn on a
  /// frame where the cursor is not — checking a mirrored copy of the gate
  /// would keep passing if the gate in the paint pass changed.
  @visibleForTesting
  int get debugCursorTextPaints => _debugCursorTextPaints;

  (int, int) _visibleLineRange(
    int lineCount,
    double firstLineOffset,
    double lastLineOffset,
    double charHeight,
  ) {
    if (lineCount <= 0) return (0, -1);
    final firstLine = firstLineOffset ~/ charHeight;
    final hasVisibleHeight = lastLineOffset > firstLineOffset;
    final lastLine = switch (hasVisibleHeight) {
      true => ((lastLineOffset - 0.000001) ~/ charHeight),
      false => firstLine,
    };
    return (
      firstLine.clamp(0, lineCount - 1),
      lastLine.clamp(0, lineCount - 1),
    );
  }

  int _cursorRenderColumn() {
    final line = _terminal.buffer.lines[_terminal.buffer.absoluteCursorY];
    final cursorX = _terminal.buffer.cursorX;
    final cellData = CellData.empty();
    line.getCellData(cursorX, cellData);

    final charWidth = cellData.content >> CellContent.widthShift;
    if (charWidth != 0 || cursorX == 0) {
      return cursorX;
    }

    line.getCellData(cursorX - 1, cellData);
    final previousCharWidth = cellData.content >> CellContent.widthShift;
    if (previousCharWidth == 2) {
      return cursorX - 1;
    }

    return cursorX;
  }

  int _cursorRenderWidth(int cursorColumn) {
    final line = _terminal.buffer.lines[_terminal.buffer.absoluteCursorY];
    final cellData = CellData.empty();
    line.getCellData(cursorColumn, cellData);

    final charWidth = cellData.content >> CellContent.widthShift;
    if (charWidth == 2) {
      return 2;
    }

    return 1;
  }

  ({Color background, Color foreground}) _cursorColors(int cursorColumn) {
    final line = _terminal.buffer.lines[_terminal.buffer.absoluteCursorY];
    final cellData = CellData.empty();
    line.getCellData(cursorColumn, cellData);
    return _painter.resolveCursorColors(cellData);
  }

  Offset _cursorRenderOffset(Offset paintOffset, int cursorColumn) {
    return _lineOrigin(
      paintOffset,
      _terminal.buffer.absoluteCursorY,
      column: cursorColumn,
    );
  }

  double _composingTextStart(double cursorX, double textWidth) {
    final contentLeft = _padding.left;
    final contentRight = max(size.width - _padding.right, contentLeft);
    final latestStart = contentRight - max(textWidth, 0);
    return max(contentLeft, min(cursorX, latestStart));
  }

  /// Paints [text] at the cursor, underlined, in the same style used for both
  /// IME composing text and caller-supplied prediction text. Neither ever
  /// touches the terminal buffer - this only draws over the cursor position.
  void _paintCursorText(
    Canvas canvas,
    Offset paintOffset,
    Offset cursorOffset,
    String? text,
  ) {
    if (text == null || text.isEmpty) {
      return;
    }

    _debugCursorTextPaints++;

    final style = _painter.textStyle.toTextStyle(
      color: switch (_terminal.reverseDisplayMode) {
        true => _painter.resolveBackgroundColor(_terminal.cursor.background),
        false => _painter.resolveForegroundColor(_terminal.cursor.foreground),
      },
      backgroundColor: switch (_terminal.reverseDisplayMode) {
        true => _painter.foregroundColor,
        false => _painter.backgroundColor,
      },
      underline: true,
    );

    final builder = ParagraphBuilder(style.getParagraphStyle());
    builder.pushStyle(
      style.getTextStyle(textScaler: _painter.textScaler),
    );
    builder.addText(text);

    final paragraph = builder.build();
    paragraph.layout(const ParagraphConstraints(width: double.infinity));

    final textStart = _composingTextStart(
      cursorOffset.dx,
      paragraph.maxIntrinsicWidth,
    );
    canvas.drawParagraph(
      paragraph,
      paintOffset + Offset(textStart, cursorOffset.dy),
    );
    paragraph.dispose();
  }

  void _paintSelection(
    Canvas canvas,
    Offset offset,
    BufferRange selection,
    int firstLine,
    int lastLine,
  ) {
    for (final segment in selection.toSegments()) {
      if (segment.line >= _terminal.buffer.lines.length) {
        break;
      }

      if (segment.line < firstLine) {
        continue;
      }

      if (segment.line > lastLine) {
        break;
      }

      _paintSegment(canvas, offset, segment, _painter.selectionColor);
    }
  }

  void _paintSelectionForegrounds(
    Canvas canvas,
    Offset offset,
    BufferRange selection,
    int firstLine,
    int lastLine,
    Color? foreground, {
    int? cursorColumn,
    Color? cursorForeground,
  }) {
    for (final segment in selection.toSegments()) {
      if (segment.line >= _terminal.buffer.lines.length) {
        break;
      }

      if (segment.line < firstLine) {
        continue;
      }

      if (segment.line > lastLine) {
        break;
      }

      final start = segment.start ?? 0;
      final end = segment.end ?? _terminal.viewWidth;
      final segmentOffset = getSegmentOffset(segment, offset);
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          segmentOffset.dx,
          segmentOffset.dy,
          (end - start) * _painter.cellSize.width,
          _painter.cellSize.height,
        ),
      );
      _painter.paintLineForegrounds(
        canvas,
        _lineOrigin(offset, segment.line),
        _terminal.buffer.lines[segment.line],
        blinkVisible: _textBlinkVisible,
        activeHyperlinkId: _activeHyperlinkId,
        cursorColumn: switch (
            segment.line == _terminal.buffer.absoluteCursorY) {
          true => cursorColumn,
          false => null,
        },
        cursorForeground: cursorForeground,
        foregroundOverride: foreground,
        ensureSelectionContrast: true,
      );
      canvas.restore();
    }
  }

  void _paintHighlights(
    Canvas canvas,
    Offset offset,
    List<TerminalHighlight> highlights,
    int firstLine,
    int lastLine,
  ) {
    for (var highlight in _controller.highlights) {
      final range = highlight.rangeFor(_terminal.buffer)?.normalized;

      if (range == null ||
          range.begin.y > lastLine ||
          range.end.y < firstLine) {
        continue;
      }

      for (var segment in range.toSegments()) {
        if (segment.line < firstLine) {
          continue;
        }

        if (segment.line > lastLine) {
          break;
        }

        _paintSegment(canvas, offset, segment, highlight.color);
      }
    }
  }

  void _paintSearchHighlightBackgrounds(
    Canvas canvas,
    Offset offset,
    int firstLine,
    int lastLine,
  ) {
    final highlights = _controller.searchHighlights;
    for (var index = 0; index < highlights.length; index++) {
      final range = _visibleSearchHighlightRange(
        highlights[index],
        firstLine,
        lastLine,
      );
      if (range == null) continue;

      final color = switch (index == _controller.currentSearchHighlight) {
        true => _painter.searchHitBackgroundCurrentColor,
        false => _painter.searchHitBackgroundColor,
      };
      for (final segment in range.toSegments()) {
        if (segment.line < firstLine) continue;
        if (segment.line > lastLine) break;
        _paintSegment(canvas, offset, segment, color);
      }
    }
  }

  void _paintSearchHighlightForegrounds(
    Canvas canvas,
    Offset offset,
    int firstLine,
    int lastLine, {
    required int? cursorColumn,
    required Color cursorForeground,
  }) {
    final clipPath = Path();
    final highlightedLines = <int>{};
    for (final highlight in _controller.searchHighlights) {
      final range = _visibleSearchHighlightRange(
        highlight,
        firstLine,
        lastLine,
      );
      if (range == null) continue;

      for (final segment in range.toSegments()) {
        if (segment.line < firstLine) continue;
        if (segment.line > lastLine) break;

        final start = segment.start ?? 0;
        final end = segment.end ?? _terminal.viewWidth;
        final segmentOffset = getSegmentOffset(segment, offset);
        clipPath.addRect(
          Rect.fromLTWH(
            segmentOffset.dx,
            segmentOffset.dy,
            (end - start) * _painter.cellSize.width,
            _painter.cellSize.height,
          ),
        );
        highlightedLines.add(segment.line);
      }
    }
    if (highlightedLines.isEmpty) return;

    canvas.save();
    canvas.clipPath(clipPath);
    for (final line in highlightedLines) {
      _painter.paintLineForegrounds(
        canvas,
        _lineOrigin(offset, line),
        _terminal.buffer.lines[line],
        blinkVisible: _textBlinkVisible,
        activeHyperlinkId: _activeHyperlinkId,
        cursorColumn: switch (
            cursorColumn != null && line == _terminal.buffer.absoluteCursorY) {
          true => cursorColumn,
          false => null,
        },
        cursorForeground: cursorForeground,
        foregroundOverride: _painter.searchHitForegroundColor,
        ensureSelectionContrast: true,
      );
    }
    canvas.restore();
  }

  BufferRangeLine? _visibleSearchHighlightRange(
    TerminalSearchHighlight highlight,
    int firstLine,
    int lastLine,
  ) {
    final buffer = _terminal.buffer;
    if (!buffer.ownsAnchor(highlight.p1) || !buffer.ownsAnchor(highlight.p2)) {
      return null;
    }

    final beginY = highlight.p1.y;
    final endY = highlight.p2.y;
    if (beginY > lastLine || endY < firstLine) return null;

    return BufferRangeLine(
      CellOffset(highlight.p1.x, beginY),
      CellOffset(highlight.p2.x, endY),
    );
  }

  void _paintUnderlines(
    Canvas canvas,
    Offset offset,
    List<TerminalUnderline> underlines,
    int firstLine,
    int lastLine,
  ) {
    for (final underline in underlines) {
      final range = underline.rangeFor(_terminal.buffer)?.normalized;

      if (range == null ||
          range.begin.y > lastLine ||
          range.end.y < firstLine) {
        continue;
      }

      for (final segment in range.toSegments()) {
        if (segment.line < firstLine) {
          continue;
        }

        if (segment.line > lastLine) {
          break;
        }

        _paintUnderline(canvas, offset, segment, underline.color);
      }
    }
  }

  @pragma('vm:prefer-inline')
  void _paintUnderline(
    Canvas canvas,
    Offset offset,
    BufferSegment segment,
    Color color,
  ) {
    final start = segment.start ?? 0;
    final end = segment.end ?? _terminal.viewWidth;
    final startOffset = getSegmentOffset(segment, offset);
    final y = startOffset.dy + _painter.cellSize.height - 1;
    final paint = _underlinePaint
      ..color = color
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(startOffset.dx, y),
      Offset(startOffset.dx + (end - start) * _painter.cellSize.width, y),
      paint,
    );
  }

  @pragma('vm:prefer-inline')
  void _paintSegment(
    Canvas canvas,
    Offset offset,
    BufferSegment segment,
    Color color,
  ) {
    final start = segment.start ?? 0;
    final end = segment.end ?? _terminal.viewWidth;

    final startOffset = getSegmentOffset(segment, offset);

    _painter.paintHighlight(canvas, startOffset, end - start, color);
  }

  Offset getSegmentOffset(BufferSegment segment, Offset paintOffset) {
    final start = segment.start ?? 0;
    return _lineOrigin(paintOffset, segment.line, column: start);
  }
}

/// The cursor state the paint passes share, resolved once per frame by
/// [RenderTerminal._resolveCursorPaintState].
class _CursorPaintState {
  const _CursorPaintState({
    required this.type,
    required this.isRowVisible,
    required this.shouldPaint,
    required this.shouldPaintBlock,
    required this.hasFocus,
    required this.column,
    required this.width,
    required this.background,
    required this.foreground,
  });

  final TerminalCursorType type;

  /// Whether the cursor's row is inside the viewport, regardless of whether
  /// the cursor itself is being drawn this frame. Text anchored to the cursor
  /// that is not part of it — a prediction — is gated on this instead of on
  /// [shouldPaint], so it stays legible while the cursor blinks.
  final bool isRowVisible;

  /// Whether the cursor is on a visible row and not currently hidden.
  final bool shouldPaint;

  final bool shouldPaintBlock;

  final bool hasFocus;

  /// The column the cursor is drawn at, which is the column to the left of
  /// [Buffer.cursorX] when the cursor sits on the trailing half of a wide
  /// character.
  final int column;

  /// Cursor width in cells: 2 over a wide character, 1 otherwise.
  final int width;

  final Color background;

  /// The color the inverted glyph under a focused block cursor is drawn in.
  /// Meaningless unless [invertsCell] is true.
  final Color foreground;

  /// Whether the cursor covers a cell and inverts the glyph in it.
  ///
  /// Only a focused block cursor does this, and it is what forces the glyph
  /// pass to know about the cursor at all: the cursor rectangle is painted
  /// underneath the glyphs, and that one cell is then drawn in swapped colors
  /// on top of it.
  bool get invertsCell => shouldPaintBlock && hasFocus;

  /// [column] when a cell is being inverted, null otherwise - the shape the
  /// painter's `cursorColumn` arguments expect.
  int? get invertedColumn => invertsCell ? column : null;
}
