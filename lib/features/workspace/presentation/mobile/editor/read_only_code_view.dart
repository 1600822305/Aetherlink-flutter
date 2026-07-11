// Virtualized read-only code viewer: one `Text` row per logical line inside a
// fixed-extent `ListView.builder`, so opening / scrolling a large file only
// lays out the visible lines — unlike a `TextField`, which lays out the whole
// document in a single `RenderEditable` and janks on multi-thousand-line
// files. Used whenever the editor is not in editing mode; entering 编辑 swaps
// in the real `EditorTextArea`.
//
// Keeps the editable area's look and affordances: line-number gutter (synced
// 1:1), horizontal pan sized to the longest line, pinch / pill font zoom, and
// long-press text selection (via `SelectionArea`, limited to the built rows).
// Find matches are highlighted per line and the current match is auto-scrolled
// into view.

import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_text_area.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/find_replace_engine.dart';

const double _lineHeightFactor = 1.5;
const double _topPad = 12;
const double _bottomPad = 24;
const double _textLeftPad = 12;
const double _textRightPad = 16;

class ReadOnlyCodeView extends StatefulWidget {
  const ReadOnlyCodeView({
    super.key,
    required this.controller,
    required this.fontSize,
    required this.onFontSize,
    this.findMatches = const <TextMatch>[],
    this.findIndex = -1,
    this.jumpLine,
    this.jumpToken = 0,
  });

  /// The same controller the editor owns; the viewer reads its text and
  /// listens for reloads (external re-sync, 「重新加载」) to re-split lines.
  final TextEditingController controller;
  final double fontSize;
  final ValueChanged<double> onFontSize;

  /// Current find matches (offsets into the controller's text) and the active
  /// match index, used for per-line highlighting and scroll-to-match.
  final List<TextMatch> findMatches;
  final int findIndex;

  /// 「跳到某行」 (1-based, 全局搜索结果点击)：[jumpToken] 每变一次触发一次
  /// 滚动居中，[jumpLine] 所在行会画一条高亮带。
  final int? jumpLine;
  final int jumpToken;

  @override
  State<ReadOnlyCodeView> createState() => _ReadOnlyCodeViewState();
}

class _ReadOnlyCodeViewState extends State<ReadOnlyCodeView> {
  final _vScroll = ScrollController();
  final _gutterScroll = ScrollController();
  final _hScroll = ScrollController();

  final Map<int, Offset> _pointers = {};
  double? _pinchStartGap;
  double _pinchStartFont = kEditorDefaultFontSize;

  List<String> _lines = const [''];
  // Start offset of each line in the full text (for match → line mapping).
  List<int> _lineStarts = const [0];
  int _maxLineLen = 1;
  String _lastText = '\u0000__uncomputed__';

  double? _cachedWidth;
  int _cachedWidthLen = -1;
  double _cachedWidthFont = -1;

  @override
  void initState() {
    super.initState();
    _resplit();
    widget.controller.addListener(_onControllerChanged);
    _vScroll.addListener(_syncGutter);
    if (widget.jumpLine != null) _scrollToLine(widget.jumpLine!);
  }

  @override
  void didUpdateWidget(covariant ReadOnlyCodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _lastText = '\u0000__uncomputed__';
      _resplit();
    }
    if (oldWidget.findIndex != widget.findIndex ||
        !identical(oldWidget.findMatches, widget.findMatches)) {
      _scrollToCurrentMatch();
    }
    if (oldWidget.jumpToken != widget.jumpToken && widget.jumpLine != null) {
      _scrollToLine(widget.jumpLine!);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _vScroll.removeListener(_syncGutter);
    _vScroll.dispose();
    _gutterScroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (widget.controller.text == _lastText) return;
    setState(_resplit);
  }

  void _resplit() {
    final text = widget.controller.text;
    _lastText = text;
    final lines = text.split('\n');
    final starts = List<int>.filled(lines.length, 0);
    var offset = 0;
    var maxLen = 1;
    for (var i = 0; i < lines.length; i++) {
      starts[i] = offset;
      final len = lines[i].length;
      if (len > maxLen) maxLen = len;
      offset += len + 1;
    }
    _lines = lines;
    _lineStarts = starts;
    _maxLineLen = maxLen;
  }

  void _syncGutter() {
    if (!_gutterScroll.hasClients) return;
    final target = _vScroll.offset.clamp(
      _gutterScroll.position.minScrollExtent,
      _gutterScroll.position.maxScrollExtent,
    );
    if ((_gutterScroll.offset - target).abs() > 0.01) {
      _gutterScroll.jumpTo(target);
    }
  }

  // 0-based line containing text [offset] (last line start <= offset).
  int _lineOfOffset(int offset) {
    var lo = 0;
    var hi = _lineStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_lineStarts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  void _scrollToCurrentMatch() {
    final i = widget.findIndex;
    if (i < 0 || i >= widget.findMatches.length) return;
    _scrollToLine(_lineOfOffset(widget.findMatches[i].start) + 1);
  }

  // Centers 1-based [line] in the viewport (shared by scroll-to-match and
  // 「跳到某行」).
  void _scrollToLine(int line) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_vScroll.hasClients) return;
      final lineHeight = widget.fontSize * _lineHeightFactor;
      final viewport = _vScroll.position.viewportDimension;
      final target =
          (_topPad + (line - 1) * lineHeight - (viewport - lineHeight) / 2)
              .clamp(
                _vScroll.position.minScrollExtent,
                _vScroll.position.maxScrollExtent,
              );
      _vScroll.jumpTo(target);
    });
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

  // The matches that intersect line [i], as spans relative to the line start.
  // Matches are sorted, so a binary search finds the first candidate and a
  // linear walk collects the rest — O(log m + k) per built row.
  List<_LineSpan> _spansForLine(int i) {
    final matches = widget.findMatches;
    if (matches.isEmpty) return const [];
    final lineStart = _lineStarts[i];
    final lineEnd = lineStart + _lines[i].length;
    var lo = 0;
    var hi = matches.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (matches[mid].end <= lineStart) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final out = <_LineSpan>[];
    for (var j = lo; j < matches.length; j++) {
      final m = matches[j];
      if (m.start >= lineEnd) break;
      out.add(
        _LineSpan(
          start: (m.start - lineStart).clamp(0, _lines[i].length),
          end: (m.end - lineStart).clamp(0, _lines[i].length),
          current: j == widget.findIndex,
        ),
      );
    }
    return out;
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
    final matchColor = theme.colorScheme.tertiaryContainer;
    final currentMatchColor = theme.colorScheme.primary.withValues(alpha: 0.4);

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EditorLineNumberGutter(
                controller: _gutterScroll,
                lineCount: _lines.length,
                lineHeight: lineHeight,
                style: gutterStyle,
                borderColor: theme.dividerColor,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final width = _contentWidth(textStyle, c.maxWidth);
                    return SingleChildScrollView(
                      controller: _hScroll,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: width,
                        child: SelectionArea(
                          child: ListView.builder(
                            controller: _vScroll,
                            padding: const EdgeInsets.only(
                              top: _topPad,
                              bottom: _bottomPad,
                              left: _textLeftPad,
                              right: _textRightPad,
                            ),
                            itemExtent: lineHeight,
                            itemCount: _lines.length,
                            itemBuilder: (context, i) => _lineRow(
                              i,
                              textStyle,
                              matchColor,
                              currentMatchColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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

  Widget _lineRow(
    int i,
    TextStyle style,
    Color matchColor,
    Color currentMatchColor,
  ) {
    final line = _lines[i];
    final spans = _spansForLine(i);
    final jumped = widget.jumpLine != null && i == widget.jumpLine! - 1;
    final Widget text;
    if (spans.isEmpty) {
      text = Text(line, style: style, maxLines: 1, softWrap: false);
    } else {
      final children = <InlineSpan>[];
      var pos = 0;
      for (final s in spans) {
        if (s.start > pos) {
          children.add(TextSpan(text: line.substring(pos, s.start)));
        }
        children.add(
          TextSpan(
            text: line.substring(s.start, s.end),
            style: TextStyle(
              backgroundColor: s.current ? currentMatchColor : matchColor,
            ),
          ),
        );
        pos = s.end;
      }
      if (pos < line.length) {
        children.add(TextSpan(text: line.substring(pos)));
      }
      text = Text.rich(
        TextSpan(style: style, children: children),
        maxLines: 1,
        softWrap: false,
      );
    }
    final row = Align(alignment: Alignment.centerLeft, child: text);
    if (!jumped) return row;
    return ColoredBox(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.09),
      child: row,
    );
  }
}

class _LineSpan {
  const _LineSpan({
    required this.start,
    required this.end,
    required this.current,
  });

  final int start;
  final int end;
  final bool current;
}
