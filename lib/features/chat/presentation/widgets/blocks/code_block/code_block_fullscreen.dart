import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';
import 'package:aetherlink_flutter/shared/widgets/editor_zoom_pill.dart';
import 'code_block_body.dart';
import 'code_block_search.dart';
import 'code_diff_view.dart';
import 'code_highlight_utils.dart';

/// Full-screen code viewer with font-size zoom (pinch / pill), search and copy.
///
/// Zoom re-lays out the text at a larger font size — like the workspace editor —
/// instead of an [InteractiveViewer] transform that just scales pixels, so
/// enlarged code stays crisp and wraps/pans naturally. Non-diff content is
/// rendered through a virtualized [ListView] (one highlighted row per line), so
/// opening / scrolling a large code block only lays out the visible lines.
class CodeBlockFullScreen extends StatefulWidget {
  const CodeBlockFullScreen({
    required this.code,
    required this.language,
    required this.highlightLanguage,
    required this.highlightTheme,
    required this.codeStyle,
    required this.lineNumberStyle,
    required this.gutterBorderColor,
    required this.showLineNumbers,
    required this.wrappable,
    this.gutterStartLine = 1,
    super.key,
  });

  final String code;
  final String language;
  final String? highlightLanguage;
  final Map<String, TextStyle> highlightTheme;
  final TextStyle codeStyle;
  final TextStyle lineNumberStyle;
  final Color gutterBorderColor;
  final bool showLineNumbers;
  final bool wrappable;
  final int gutterStartLine;

  @override
  State<CodeBlockFullScreen> createState() => _CodeBlockFullScreenState();
}

class _CodeBlockFullScreenState extends State<CodeBlockFullScreen> {
  bool _copied = false;
  bool _showSearch = false;
  String _searchQuery = '';
  int _currentMatchIndex = 0;
  late double _fontSize =
      (widget.codeStyle.fontSize ?? kEditorDefaultFontSize)
          .clamp(kEditorMinFontSize, kEditorMaxFontSize)
          .toDouble();

  Future<void> _copy() async {
    await AppToast.copy(context, widget.code);
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _onSearchChanged(String query, int matchCount, int currentIndex) {
    setState(() {
      _searchQuery = query;
      _currentMatchIndex = currentIndex;
    });
  }

  void _setFontSize(double v) {
    final next = v.clamp(kEditorMinFontSize, kEditorMaxFontSize).toDouble();
    if (next != _fontSize) setState(() => _fontSize = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA);
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final dc = displayCode(widget.code);
    final lines = dc.isEmpty ? <String>[''] : dc.split('\n');
    final useDiff = isDiffContent(widget.highlightLanguage, dc);

    final codeStyle = widget.codeStyle.copyWith(fontSize: _fontSize);
    final lineNumberStyle = widget.lineNumberStyle.copyWith(fontSize: _fontSize);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF282828) : const Color(0xFFF0F0F0),
        foregroundColor: labelColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: labelColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '<${displayLanguage(widget.language).toUpperCase()}>',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: labelColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              LucideIcons.search,
              size: 18,
              color: _showSearch ? theme.colorScheme.primary : labelColor,
            ),
            tooltip: '搜索',
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) _searchQuery = '';
            }),
          ),
          IconButton(
            icon: Icon(
              _copied ? LucideIcons.check : LucideIcons.copy,
              size: 18,
              color: _copied ? Colors.green : labelColor,
            ),
            tooltip: _copied ? '已复制' : '复制代码',
            onPressed: _copy,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_showSearch)
              CodeBlockSearchBar(
                code: dc,
                onChanged: _onSearchChanged,
                onClose: () => setState(() {
                  _showSearch = false;
                  _searchQuery = '';
                }),
                labelColor: labelColor,
              ),
            Expanded(
              child: useDiff
                  ? _DiffBody(
                      lines: lines,
                      showLineNumbers: widget.showLineNumbers,
                      codeStyle: codeStyle,
                      lineNumberStyle: lineNumberStyle,
                      gutterBorderColor: widget.gutterBorderColor,
                      fontSize: _fontSize,
                      onFontSize: _setFontSize,
                    )
                  : _VirtualizedCodeBody(
                      lines: lines,
                      highlightLanguage: widget.highlightLanguage,
                      highlightTheme: widget.highlightTheme,
                      showLineNumbers: widget.showLineNumbers,
                      wrappable: widget.wrappable,
                      codeStyle: codeStyle,
                      lineNumberStyle: lineNumberStyle,
                      gutterBorderColor: widget.gutterBorderColor,
                      gutterStartLine: widget.gutterStartLine,
                      searchQuery: _showSearch ? _searchQuery : '',
                      currentMatchIndex: _currentMatchIndex,
                      fontSize: _fontSize,
                      onFontSize: _setFontSize,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diff content is usually small, so it keeps the simple non-virtualized
/// [DiffCodeView] inside a scroll view; pinch still drives font zoom.
class _DiffBody extends StatelessWidget {
  const _DiffBody({
    required this.lines,
    required this.showLineNumbers,
    required this.codeStyle,
    required this.lineNumberStyle,
    required this.gutterBorderColor,
    required this.fontSize,
    required this.onFontSize,
  });

  final List<String> lines;
  final bool showLineNumbers;
  final TextStyle codeStyle;
  final TextStyle lineNumberStyle;
  final Color gutterBorderColor;
  final double fontSize;
  final ValueChanged<double> onFontSize;

  @override
  Widget build(BuildContext context) {
    return _PinchZoom(
      fontSize: fontSize,
      onFontSize: onFontSize,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DiffCodeView(
            lines: lines,
            showLineNumbers: showLineNumbers,
            codeStyle: codeStyle,
            lineNumberStyle: lineNumberStyle,
            gutterBorderColor: gutterBorderColor,
          ),
        ),
      ),
    );
  }
}

/// Virtualized, syntax-highlighted code viewer: one highlighted `Text.rich`
/// row per line inside a fixed-extent `ListView.builder`, so only the visible
/// lines are laid out. A pinned line-number gutter is synced vertically; the
/// code pans horizontally to the longest line's width. Font zoom re-lays out
/// the rows (no pixel-scaling transform).
class _VirtualizedCodeBody extends StatefulWidget {
  const _VirtualizedCodeBody({
    required this.lines,
    required this.highlightLanguage,
    required this.highlightTheme,
    required this.showLineNumbers,
    required this.wrappable,
    required this.codeStyle,
    required this.lineNumberStyle,
    required this.gutterBorderColor,
    required this.gutterStartLine,
    required this.searchQuery,
    required this.currentMatchIndex,
    required this.fontSize,
    required this.onFontSize,
  });

  final List<String> lines;
  final String? highlightLanguage;
  final Map<String, TextStyle> highlightTheme;
  final bool showLineNumbers;
  final bool wrappable;
  final TextStyle codeStyle;
  final TextStyle lineNumberStyle;
  final Color gutterBorderColor;
  final int gutterStartLine;
  final String searchQuery;
  final int currentMatchIndex;
  final double fontSize;
  final ValueChanged<double> onFontSize;

  @override
  State<_VirtualizedCodeBody> createState() => _VirtualizedCodeBodyState();
}

class _VirtualizedCodeBodyState extends State<_VirtualizedCodeBody> {
  static const double _lineHeightFactor = 1.5;
  static const double _pad = 12;

  final _vScroll = ScrollController();
  final _gutterScroll = ScrollController();
  final _hScroll = ScrollController();

  late LineHighlighter _highlighter;
  int _maxLineLen = 1;

  // Per-search-query cumulative match offsets so each line knows its global
  // match index in O(N) total (mirrors PerLineCodeView).
  List<int> _matchOffsets = const [];
  String _lastQuery = '';

  // Content-width cache (depends on longest line + font size).
  double? _cachedWidth;
  double _cachedWidthFont = -1;

  @override
  void initState() {
    super.initState();
    _highlighter = _makeHighlighter();
    _computeMaxLen();
    _recomputeMatches();
    _vScroll.addListener(_syncGutter);
  }

  @override
  void didUpdateWidget(covariant _VirtualizedCodeBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lines, widget.lines) ||
        oldWidget.highlightLanguage != widget.highlightLanguage ||
        !identical(oldWidget.highlightTheme, widget.highlightTheme)) {
      _highlighter = _makeHighlighter();
      _computeMaxLen();
      _lastQuery = '\u0000';
    }
    if (widget.searchQuery != _lastQuery) _recomputeMatches();
  }

  @override
  void dispose() {
    _vScroll.removeListener(_syncGutter);
    _vScroll.dispose();
    _gutterScroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  LineHighlighter _makeHighlighter() => LineHighlighter(
        lines: widget.lines,
        language: widget.highlightLanguage,
        theme: widget.highlightTheme,
      );

  void _computeMaxLen() {
    var maxLen = 1;
    for (final l in widget.lines) {
      if (l.length > maxLen) maxLen = l.length;
    }
    _maxLineLen = maxLen;
    _cachedWidth = null;
  }

  void _recomputeMatches() {
    _lastQuery = widget.searchQuery;
    if (widget.searchQuery.isEmpty) {
      _matchOffsets = const [];
      return;
    }
    final lowerQuery = widget.searchQuery.toLowerCase();
    final offsets = List<int>.filled(widget.lines.length, 0);
    var cumulative = 0;
    for (var i = 0; i < widget.lines.length; i++) {
      offsets[i] = cumulative;
      final line = widget.lines[i].toLowerCase();
      var start = 0;
      while (true) {
        final idx = line.indexOf(lowerQuery, start);
        if (idx == -1) break;
        cumulative++;
        start = idx + 1;
      }
    }
    _matchOffsets = offsets;
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

  double _contentWidth(TextStyle style, double viewport) {
    if (_cachedWidth == null || _cachedWidthFont != widget.fontSize) {
      final tp = TextPainter(
        text: TextSpan(text: 'M' * _maxLineLen, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      _cachedWidth = tp.width + _pad * 2;
      _cachedWidthFont = widget.fontSize;
    }
    final width = _cachedWidth!;
    return width < viewport ? viewport : width;
  }

  @override
  Widget build(BuildContext context) {
    final lineHeight = widget.fontSize * _lineHeightFactor;
    final hasSearch = widget.searchQuery.isNotEmpty;

    final body = Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showLineNumbers)
              _Gutter(
                controller: _gutterScroll,
                lineCount: widget.lines.length,
                startAt: widget.gutterStartLine,
                lineHeight: lineHeight,
                style: widget.lineNumberStyle,
                borderColor: widget.gutterBorderColor,
                topPad: _pad,
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final width = widget.wrappable
                      ? c.maxWidth
                      : _contentWidth(widget.codeStyle, c.maxWidth);
                  final list = SelectionArea(
                    child: ListView.builder(
                      controller: _vScroll,
                      padding: const EdgeInsets.symmetric(
                        horizontal: _pad,
                        vertical: _pad,
                      ),
                      itemExtent: widget.wrappable ? null : lineHeight,
                      itemCount: widget.lines.length,
                      itemBuilder: (context, i) =>
                          _row(i, lineHeight, hasSearch),
                    ),
                  );
                  if (widget.wrappable) return list;
                  return SingleChildScrollView(
                    controller: _hScroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: width, child: list),
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
    );

    return _PinchZoom(
      fontSize: widget.fontSize,
      onFontSize: widget.onFontSize,
      child: body,
    );
  }

  Widget _row(int i, double lineHeight, bool hasSearch) {
    final base = _highlighter.spansFor(i);
    final decorated = hasSearch
        ? applySearchHighlight(
            base,
            widget.searchQuery,
            widget.codeStyle,
            widget.currentMatchIndex,
            _matchOffsets.length > i ? _matchOffsets[i] : 0,
          )
        : base;
    final text = Text.rich(
      TextSpan(style: widget.codeStyle, children: decorated),
      softWrap: widget.wrappable,
      maxLines: widget.wrappable ? null : 1,
      strutStyle: StrutStyle.fromTextStyle(
        widget.codeStyle,
        forceStrutHeight: true,
      ),
    );
    if (widget.wrappable) return text;
    return Align(alignment: Alignment.centerLeft, child: text);
  }
}

/// Fixed line-number gutter, vertically synced to the code list.
class _Gutter extends StatelessWidget {
  const _Gutter({
    required this.controller,
    required this.lineCount,
    required this.startAt,
    required this.lineHeight,
    required this.style,
    required this.borderColor,
    required this.topPad,
  });

  final ScrollController controller;
  final int lineCount;
  final int startAt;
  final double lineHeight;
  final TextStyle style;
  final Color borderColor;
  final double topPad;

  @override
  Widget build(BuildContext context) {
    final lastLine = startAt + lineCount - 1;
    final width = gutterWidthFor(lastLine, style);
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: ListView.builder(
        controller: controller,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: topPad, bottom: topPad, right: 8),
        itemExtent: lineHeight,
        itemCount: lineCount,
        itemBuilder: (context, i) => Align(
          alignment: Alignment.centerRight,
          child: Text('${startAt + i}', style: style, maxLines: 1),
        ),
      ),
    );
  }
}

/// Two-finger pinch → font-size zoom, via a raw [Listener] so it never joins
/// the gesture arena (single-finger scroll / select keep working).
class _PinchZoom extends StatefulWidget {
  const _PinchZoom({
    required this.fontSize,
    required this.onFontSize,
    required this.child,
  });

  final double fontSize;
  final ValueChanged<double> onFontSize;
  final Widget child;

  @override
  State<_PinchZoom> createState() => _PinchZoomState();
}

class _PinchZoomState extends State<_PinchZoom> {
  final Map<int, Offset> _pointers = {};
  double? _startGap;
  double _startFont = kEditorDefaultFontSize;

  void _onDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      final pts = _pointers.values.toList();
      _startGap = (pts[0] - pts[1]).distance;
      _startFont = widget.fontSize;
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    final gap0 = _startGap;
    if (_pointers.length >= 2 && gap0 != null && gap0 > 0) {
      final pts = _pointers.values.toList();
      final gap = (pts[0] - pts[1]).distance;
      widget.onFontSize(_startFont * gap / gap0);
    }
  }

  void _onUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _startGap = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onUp,
      child: widget.child,
    );
  }
}
