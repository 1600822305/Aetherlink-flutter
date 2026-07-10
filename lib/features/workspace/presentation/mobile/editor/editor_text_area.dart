// The monospace text area with a left line-number gutter and font-size zoom.
//
// Layout: a fixed gutter (line numbers, vertically synced to the field) + a
// horizontally scrollable, non-wrapping TextField, so each logical line maps to
// exactly one gutter row. Zoom changes the font size (8–32, default 13) rather
// than transforming the canvas — an InteractiveViewer would fight the field's
// caret/selection. Pinch is handled by a raw Listener (never joins the gesture
// arena, so single-finger scroll / select / tap on the field keep working).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_limits.dart';
import 'package:aetherlink_flutter/shared/widgets/editor_zoom_pill.dart';

export 'package:aetherlink_flutter/shared/widgets/editor_zoom_pill.dart';

/// Spaces inserted for a Tab key press and continued on auto-indent.
const String _indentUnit = '  ';

const double _lineHeightFactor = 1.5;
const double _topPad = 12;
const double _bottomPad = 24;
const double _textLeftPad = 12;
const double _textRightPad = 16;

class EditorTextArea extends StatefulWidget {
  const EditorTextArea({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.editing,
    required this.fontSize,
    required this.onFontSize,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool editing;
  final double fontSize;
  final ValueChanged<double> onFontSize;

  @override
  State<EditorTextArea> createState() => _EditorTextAreaState();
}

class _EditorTextAreaState extends State<EditorTextArea> {
  final _textScroll = ScrollController();
  final _gutterScroll = ScrollController();
  final _hScroll = ScrollController();

  final Map<int, Offset> _pointers = {};
  double? _pinchStartGap;
  double _pinchStartFont = kEditorDefaultFontSize;

  // Text-derived metrics, cached so they are recomputed only when the text
  // actually changes (a controller notification also fires on caret moves /
  // selection changes, which must NOT trigger an O(text) rescan or a rebuild
  // of the whole area). A sentinel forces the first compute.
  String _lastText = '\u0000__uncomputed__';
  int _lineCount = 1;
  int _maxLineLen = 1;
  bool _softWrap = false;
  // Start offset of every line, so caret → line lookups (current-line
  // highlight) are a binary search instead of an O(offset) rescan per caret
  // move / scroll frame.
  List<int> _lineStarts = const [0];

  // Memoized non-wrapping content width (the longest line laid out). Depends
  // only on [_maxLineLen] + the font size, so it survives caret moves and is
  // recomputed only when one of those changes.
  double? _cachedWidth;
  int _cachedWidthLen = -1;
  double _cachedWidthFont = -1;

  @override
  void initState() {
    super.initState();
    _recomputeMetrics();
    widget.controller.addListener(_onControllerChanged);
    _textScroll.addListener(_syncGutter);
    widget.focusNode.onKeyEvent = _onKeyEvent;
  }

  @override
  void didUpdateWidget(covariant EditorTextArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _lastText = '\u0000__uncomputed__';
      _recomputeMetrics();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode.onKeyEvent == _onKeyEvent) {
        oldWidget.focusNode.onKeyEvent = null;
      }
      widget.focusNode.onKeyEvent = _onKeyEvent;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _textScroll.removeListener(_syncGutter);
    if (widget.focusNode.onKeyEvent == _onKeyEvent) {
      widget.focusNode.onKeyEvent = null;
    }
    _textScroll.dispose();
    _gutterScroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  // Rebuilds the area only when the text changed (line count / longest line /
  // long-line guard may differ). Caret-only notifications are ignored here —
  // the caret highlight and status bar listen to the controller themselves.
  void _onControllerChanged() {
    if (widget.controller.text == _lastText) return;
    setState(_recomputeMetrics);
  }

  // Single pass over the text computing line count, the longest line length
  // (for the non-wrapping width) and the long-line guard at once.
  void _recomputeMetrics() {
    final text = widget.controller.text;
    _lastText = text;
    var maxLen = 1;
    var col = 0;
    var longLine = false;
    final starts = <int>[0];
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0x0A) {
        starts.add(i + 1);
        if (col > maxLen) maxLen = col;
        col = 0;
      } else {
        col++;
        if (col > kMaxLineLength) longLine = true;
      }
    }
    if (col > maxLen) maxLen = col;
    _lineCount = starts.length;
    _maxLineLen = maxLen;
    _softWrap = longLine;
    _lineStarts = starts;
  }

  // Tab inserts spaces (instead of moving focus) while editing; auto-indent on
  // newline is handled by [_AutoIndentFormatter]. Other keys fall through.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.editing) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      _insertIndent();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _insertIndent() {
    final value = widget.controller.value;
    final sel = value.selection;
    final start = sel.isValid ? sel.start : value.text.length;
    final end = sel.isValid ? sel.end : value.text.length;
    widget.controller.value = TextEditingValue(
      text: value.text.replaceRange(start, end, _indentUnit),
      selection: TextSelection.collapsed(offset: start + _indentUnit.length),
    );
  }

  void _syncGutter() {
    if (!_gutterScroll.hasClients) return;
    final target = _textScroll.offset.clamp(
      _gutterScroll.position.minScrollExtent,
      _gutterScroll.position.maxScrollExtent,
    );
    if ((_gutterScroll.offset - target).abs() > 0.01) {
      _gutterScroll.jumpTo(target);
    }
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      final pts = _pointers.values.toList();
      _pinchStartGap = (pts[0] - pts[1]).distance;
      _pinchStartFont = widget.fontSize;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    final gap0 = _pinchStartGap;
    if (_pointers.length >= 2 && gap0 != null && gap0 > 0) {
      final pts = _pointers.values.toList();
      final gap = (pts[0] - pts[1]).distance;
      final next = (_pinchStartFont * gap / gap0)
          .clamp(kEditorMinFontSize, kEditorMaxFontSize)
          .toDouble();
      if (next != widget.fontSize) widget.onFontSize(next);
    }
  }

  void _onPointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _pinchStartGap = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineHeight = widget.fontSize * _lineHeightFactor;

    final textStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: widget.fontSize,
      height: _lineHeightFactor,
      color: theme.colorScheme.onSurface,
    );
    final gutterStyle = textStyle.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: Stack(
        children: [
          // Long-line guard: a single multi-megabyte line would make the
          // non-wrapping layout below measure an enormous canvas and freeze the
          // UI. Fall back to a soft-wrapping, gutterless view in that case.
          if (_softWrap)
            _wrapLayout(textStyle, theme)
          else
            _columnLayout(
              lineCount: _lineCount,
              lineHeight: lineHeight,
              textStyle: textStyle,
              gutterStyle: gutterStyle,
              theme: theme,
            ),
          Positioned(
            right: 12,
            bottom: 12,
            child: EditorZoomPill(
              fontSize: widget.fontSize,
              onChange: widget.onFontSize,
            ),
          ),
        ],
      ),
    );
  }

  // The standard view: a line-number gutter + a horizontally pannable,
  // non-wrapping field, with each logical line mapped 1:1 to a gutter row.
  Widget _columnLayout({
    required int lineCount,
    required double lineHeight,
    required TextStyle textStyle,
    required TextStyle gutterStyle,
    required ThemeData theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorLineNumberGutter(
          controller: _gutterScroll,
          lineCount: lineCount,
          lineHeight: lineHeight,
          style: gutterStyle,
          borderColor: theme.dividerColor,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final width = _contentWidth(textStyle, c.maxWidth);
              return Stack(
                children: [
                  if (widget.editing)
                    _CurrentLineHighlight(
                      scroll: _textScroll,
                      controller: widget.controller,
                      lineStarts: _lineStarts,
                      lineHeight: lineHeight,
                      color: theme.colorScheme.primary.withValues(alpha: 0.07),
                    ),
                  SingleChildScrollView(
                    controller: _hScroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      child: _field(textStyle, theme),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // Degraded fallback for pathologically long lines: full-width, soft-wrapping,
  // no gutter (1 logical line no longer maps to 1 row) and no horizontal pan.
  Widget _wrapLayout(TextStyle textStyle, ThemeData theme) {
    return SizedBox.expand(child: _field(textStyle, theme));
  }

  // The shared editing field. In [_columnLayout] it sits in a fixed-width box
  // (so it never wraps); in [_wrapLayout] it fills the viewport (so it does).
  Widget _field(TextStyle textStyle, ThemeData theme) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      scrollController: _textScroll,
      readOnly: !widget.editing,
      expands: true,
      maxLines: null,
      minLines: null,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
      inputFormatters: const [_AutoIndentFormatter()],
      style: textStyle,
      cursorColor: theme.colorScheme.primary,
      decoration: const InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.fromLTRB(
          _textLeftPad,
          _topPad,
          _textRightPad,
          _bottomPad,
        ),
      ),
    );
  }

  // Width of the longest line so the field never wraps and can pan horizontally.
  // The intrinsic measurement is memoized against [_maxLineLen] + font size, so
  // it is recomputed only when the longest line or the zoom changes — not on
  // every keystroke or caret move.
  double _contentWidth(TextStyle style, double viewport) {
    if (_cachedWidth == null ||
        _cachedWidthLen != _maxLineLen ||
        _cachedWidthFont != widget.fontSize) {
      final tp = TextPainter(
        text: TextSpan(text: 'M' * _maxLineLen, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      _cachedWidth = tp.width + _textLeftPad + _textRightPad;
      _cachedWidthLen = _maxLineLen;
      _cachedWidthFont = widget.fontSize;
    }
    final width = _cachedWidth!;
    return width < viewport ? viewport : width;
  }
}

/// A full-width band behind the caret's line. Tracks the field's vertical
/// scroll so it stays glued to the current line; spans the viewport width
/// (fixed horizontally) so the highlight is visible regardless of pan.
class _CurrentLineHighlight extends StatelessWidget {
  const _CurrentLineHighlight({
    required this.scroll,
    required this.controller,
    required this.lineStarts,
    required this.lineHeight,
    required this.color,
  });

  final ScrollController scroll;
  final TextEditingController controller;

  /// Precomputed line start offsets (from the text area's metrics pass), so
  /// the caret line is a binary search rather than a scan of the text.
  final List<int> lineStarts;
  final double lineHeight;
  final Color color;

  // 0-based line index of the caret, or -1 when there is no valid caret.
  int _caretLine() {
    final sel = controller.selection;
    if (!sel.isValid) return -1;
    final offset = sel.extentOffset.clamp(0, controller.text.length);
    var lo = 0;
    var hi = lineStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (lineStarts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds itself on caret/selection moves (controller) and vertical scroll
    // — isolated from the editor body so typing doesn't repaint the field.
    return AnimatedBuilder(
      animation: Listenable.merge([scroll, controller]),
      builder: (context, _) {
        final caretLine = _caretLine();
        if (caretLine < 0) return const SizedBox.shrink();
        final offset = scroll.hasClients ? scroll.offset : 0.0;
        final top = _topPad + caretLine * lineHeight - offset;
        return Positioned(
          left: 0,
          right: 0,
          top: top,
          height: lineHeight,
          child: IgnorePointer(child: ColoredBox(color: color)),
        );
      },
    );
  }
}

/// Continues the previous line's leading whitespace after a newline is typed,
/// so pressing Enter keeps the current indent. Works for both soft and
/// hardware keyboards (it reacts to the inserted text, not a key event).
class _AutoIndentFormatter extends TextInputFormatter {
  const _AutoIndentFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only react to a single-char insertion that is a newline at the caret.
    if (newValue.text.length != oldValue.text.length + 1) return newValue;
    final caret = newValue.selection.baseOffset;
    if (caret <= 0 || caret > newValue.text.length) return newValue;
    if (newValue.text[caret - 1] != '\n') return newValue;

    final before = newValue.text.substring(0, caret - 1);
    final lineStart = before.lastIndexOf('\n') + 1;
    final indent = _leadingWhitespace(before.substring(lineStart));
    if (indent.isEmpty) return newValue;

    final text =
        newValue.text.substring(0, caret) +
        indent +
        newValue.text.substring(caret);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret + indent.length),
    );
  }

  static String _leadingWhitespace(String line) {
    var i = 0;
    while (i < line.length && (line[i] == ' ' || line[i] == '\t')) {
      i++;
    }
    return line.substring(0, i);
  }
}

/// The fixed line-number gutter, virtualized and vertically synced to the
/// text's scroll position. Shared by the editable area and the read-only
/// viewer.
class EditorLineNumberGutter extends StatelessWidget {
  const EditorLineNumberGutter({
    super.key,
    required this.controller,
    required this.lineCount,
    required this.lineHeight,
    required this.style,
    required this.borderColor,
  });

  final ScrollController controller;
  final int lineCount;
  final double lineHeight;
  final TextStyle style;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final digits = lineCount.toString().length;
    final tp = TextPainter(
      text: TextSpan(text: '0' * digits, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = tp.width + 18;

    // Virtualized: only the visible line numbers are built (a file can have
    // tens of thousands of lines). Synced to the field's vertical scroll via
    // [controller]; matching [itemExtent]/top padding keeps each number aligned
    // 1:1 with its text line.
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: ListView.builder(
        controller: controller,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          top: _topPad,
          bottom: _bottomPad,
          right: 8,
        ),
        itemExtent: lineHeight,
        itemCount: lineCount,
        itemBuilder: (context, i) => Align(
          alignment: Alignment.centerRight,
          child: Text('${i + 1}', style: style, maxLines: 1),
        ),
      ),
    );
  }
}
