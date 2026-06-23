import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'code_diff_view.dart';
import 'code_highlight_utils.dart';

/// The body of a code block: either wrapping (per-line) or horizontal scroll.
class CodeBlockBody extends StatelessWidget {
  const CodeBlockBody({
    required this.code,
    required this.highlightLanguage,
    required this.highlightTheme,
    required this.showLineNumbers,
    required this.wrappable,
    required this.codeStyle,
    required this.lineNumberStyle,
    required this.gutterBorderColor,
    required this.isStreaming,
    this.searchQuery,
    this.currentMatchIndex,
    super.key,
  });

  final String code;
  final String? highlightLanguage;
  final Map<String, TextStyle> highlightTheme;
  final bool showLineNumbers;
  final bool wrappable;
  final TextStyle codeStyle;
  final TextStyle lineNumberStyle;
  final Color gutterBorderColor;
  final bool isStreaming;
  final String? searchQuery;
  final int? currentMatchIndex;

  @override
  Widget build(BuildContext context) {
    final dc = displayCode(code);
    final lines = dc.isEmpty ? <String>[''] : dc.split('\n');

    if (isDiffContent(highlightLanguage, dc)) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: DiffCodeView(
          lines: lines,
          showLineNumbers: showLineNumbers,
          codeStyle: codeStyle,
          lineNumberStyle: lineNumberStyle,
          gutterBorderColor: gutterBorderColor,
        ),
      );
    }

    if (wrappable) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: PerLineCodeView(
          lines: lines,
          highlightLanguage: highlightLanguage,
          highlightTheme: highlightTheme,
          showLineNumbers: showLineNumbers,
          codeStyle: codeStyle,
          lineNumberStyle: lineNumberStyle,
          gutterBorderColor: gutterBorderColor,
          isStreaming: isStreaming,
          searchQuery: searchQuery,
          currentMatchIndex: currentMatchIndex,
        ),
      );
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: SingleBlockCodeView(
          code: dc.isEmpty ? ' ' : dc,
          lineCount: lines.length,
          highlightLanguage: highlightLanguage,
          highlightTheme: highlightTheme,
          showLineNumbers: showLineNumbers,
          codeStyle: codeStyle,
          lineNumberStyle: lineNumberStyle,
          gutterBorderColor: gutterBorderColor,
          isStreaming: isStreaming,
        ),
      ),
    );
  }
}

/// Renders code as a single selectable block (horizontal scroll mode).
class SingleBlockCodeView extends StatelessWidget {
  const SingleBlockCodeView({
    required this.code,
    required this.lineCount,
    required this.highlightLanguage,
    required this.highlightTheme,
    required this.showLineNumbers,
    required this.codeStyle,
    required this.lineNumberStyle,
    required this.gutterBorderColor,
    this.isStreaming = false,
    super.key,
  });

  final String code;
  final int lineCount;
  final String? highlightLanguage;
  final Map<String, TextStyle> highlightTheme;
  final bool showLineNumbers;
  final TextStyle codeStyle;
  final TextStyle lineNumberStyle;
  final Color gutterBorderColor;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLineNumbers) ...[
          LineNumberGutter(
            lineCount: lineCount,
            style: lineNumberStyle,
            borderColor: gutterBorderColor,
          ),
          const SizedBox(width: 12),
        ],
        SelectableHighlightView(
          code,
          language: highlightLanguage,
          theme: highlightTheme,
          style: codeStyle,
          maxLines: lineCount,
          isStreaming: isStreaming,
        ),
      ],
    );
  }
}

/// Renders code line-by-line so line numbers stay aligned even when lines wrap.
class PerLineCodeView extends StatefulWidget {
  const PerLineCodeView({
    required this.lines,
    required this.highlightLanguage,
    required this.highlightTheme,
    required this.showLineNumbers,
    required this.codeStyle,
    required this.lineNumberStyle,
    required this.gutterBorderColor,
    this.isStreaming = false,
    this.searchQuery,
    this.currentMatchIndex,
    super.key,
  });

  final List<String> lines;
  final String? highlightLanguage;
  final Map<String, TextStyle> highlightTheme;
  final bool showLineNumbers;
  final TextStyle codeStyle;
  final TextStyle lineNumberStyle;
  final Color gutterBorderColor;
  final bool isStreaming;
  final String? searchQuery;
  final int? currentMatchIndex;

  @override
  State<PerLineCodeView> createState() => _PerLineCodeViewState();
}

class _PerLineCodeViewState extends State<PerLineCodeView> {
  late List<List<TextSpan>> _lineSpans;
  Timer? _debounce;
  bool _pendingHighlight = false;

  @override
  void initState() {
    super.initState();
    _lineSpans = _highlightAllLines();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PerLineCodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final themeChanged =
        !identical(oldWidget.highlightTheme, widget.highlightTheme);
    final langChanged = oldWidget.highlightLanguage != widget.highlightLanguage;
    final codeChanged = oldWidget.lines != widget.lines;

    if (themeChanged || langChanged) {
      _debounce?.cancel();
      _lineSpans = _highlightAllLines();
      _pendingHighlight = false;
    } else if (codeChanged) {
      if (widget.isStreaming) {
        _pendingHighlight = true;
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 50), () {
          if (!mounted) return;
          setState(() {
            _lineSpans = _highlightAllLines();
            _pendingHighlight = false;
          });
        });
      } else {
        _debounce?.cancel();
        _lineSpans = _highlightAllLines();
        _pendingHighlight = false;
      }
    }
  }

  List<List<TextSpan>> _highlightAllLines() {
    final fullCode = widget.lines.join('\n');
    final spans = parseToSpans(
      fullCode,
      widget.highlightLanguage,
      widget.highlightTheme,
    );
    return splitSpansByLine(spans, widget.lines.length);
  }

  @override
  Widget build(BuildContext context) {
    final gutterWidth = widget.showLineNumbers
        ? math.max(34.0, 18.0 + widget.lines.length.toString().length * 8.0)
        : 0.0;

    final effectiveSpans =
        _pendingHighlight ? _lineSpans : _lineSpans;

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(widget.lines.length, (i) {
          final lineSpans =
              effectiveSpans.length > i ? effectiveSpans[i] : <TextSpan>[];
          final decorated = widget.searchQuery != null &&
                  widget.searchQuery!.isNotEmpty
              ? applySearchHighlight(
                  lineSpans,
                  widget.searchQuery!,
                  widget.codeStyle,
                  widget.currentMatchIndex,
                  _globalMatchOffset(i),
                )
              : lineSpans;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showLineNumbers) ...[
                Container(
                  width: gutterWidth,
                  padding: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: widget.gutterBorderColor),
                    ),
                  ),
                  child: Text(
                    '${i + 1}',
                    textAlign: TextAlign.right,
                    style: widget.lineNumberStyle,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: widget.codeStyle,
                    children: decorated,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  int _globalMatchOffset(int lineIndex) {
    if (widget.searchQuery == null || widget.searchQuery!.isEmpty) return 0;
    var offset = 0;
    final query = widget.searchQuery!.toLowerCase();
    for (var i = 0; i < lineIndex && i < widget.lines.length; i++) {
      final line = widget.lines[i].toLowerCase();
      var start = 0;
      while (true) {
        final idx = line.indexOf(query, start);
        if (idx == -1) break;
        offset++;
        start = idx + 1;
      }
    }
    return offset;
  }
}

/// Highlight view with streaming debounce support.
class SelectableHighlightView extends StatefulWidget {
  const SelectableHighlightView(
    this.source, {
    required this.language,
    required this.theme,
    required this.style,
    this.maxLines,
    this.isStreaming = false,
    super.key,
  });

  final String source;
  final String? language;
  final Map<String, TextStyle> theme;
  final TextStyle style;
  final int? maxLines;
  final bool isStreaming;

  @override
  State<SelectableHighlightView> createState() =>
      _SelectableHighlightViewState();
}

class _SelectableHighlightViewState extends State<SelectableHighlightView> {
  late List<TextSpan> _spans;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _spans = parseToSpans(widget.source, widget.language, widget.theme);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SelectableHighlightView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final themeChanged = !identical(oldWidget.theme, widget.theme);
    final langChanged = oldWidget.language != widget.language;
    final codeChanged = oldWidget.source != widget.source;

    if (themeChanged || langChanged) {
      _debounce?.cancel();
      _spans = parseToSpans(widget.source, widget.language, widget.theme);
    } else if (codeChanged) {
      if (widget.isStreaming) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 50), () {
          if (!mounted) return;
          setState(() {
            _spans =
                parseToSpans(widget.source, widget.language, widget.theme);
          });
        });
      } else {
        _debounce?.cancel();
        _spans = parseToSpans(widget.source, widget.language, widget.theme);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(
        style: widget.style,
        children:
            _spans.isEmpty ? <TextSpan>[TextSpan(text: widget.source)] : _spans,
      ),
      maxLines: widget.maxLines,
    );
  }
}

class LineNumberGutter extends StatelessWidget {
  const LineNumberGutter({
    required this.lineCount,
    required this.style,
    required this.borderColor,
    super.key,
  });

  final int lineCount;
  final TextStyle style;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final width = math.max(34.0, 18.0 + lineCount.toString().length * 8.0);
    return Container(
      width: width,
      padding: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Text(
        List.generate(lineCount, (i) => '${i + 1}').join('\n'),
        textAlign: TextAlign.right,
        style: style,
      ),
    );
  }
}

/// Apply search highlight to spans, coloring matches yellow / current orange.
List<TextSpan> applySearchHighlight(
  List<TextSpan> spans,
  String query,
  TextStyle baseStyle,
  int? currentMatchIndex,
  int globalOffset,
) {
  if (query.isEmpty) return spans;

  final plainText = spans.map((s) => s.text ?? '').join();
  final lowerText = plainText.toLowerCase();
  final lowerQuery = query.toLowerCase();

  final matches = <int>[];
  var searchStart = 0;
  while (true) {
    final idx = lowerText.indexOf(lowerQuery, searchStart);
    if (idx == -1) break;
    matches.add(idx);
    searchStart = idx + 1;
  }
  if (matches.isEmpty) return spans;

  final result = <TextSpan>[];
  var charOffset = 0;
  var matchListIdx = 0;

  for (final span in spans) {
    final text = span.text ?? '';
    if (text.isEmpty) {
      result.add(span);
      continue;
    }

    var pos = 0;
    while (pos < text.length) {
      if (matchListIdx < matches.length) {
        final matchStart = matches[matchListIdx];
        final matchEnd = matchStart + query.length;
        final spanStart = charOffset + pos;
        final spanEnd = charOffset + text.length;

        if (matchStart >= spanEnd) {
          result.add(TextSpan(text: text.substring(pos), style: span.style));
          pos = text.length;
        } else if (matchEnd <= spanStart) {
          matchListIdx++;
        } else {
          if (matchStart > spanStart) {
            result.add(TextSpan(
              text: text.substring(pos, matchStart - charOffset),
              style: span.style,
            ));
            pos = matchStart - charOffset;
          }
          final hlStart = pos;
          final hlEnd = math.min(text.length, matchEnd - charOffset);
          final isCurrentMatch =
              currentMatchIndex == (globalOffset + matchListIdx);
          result.add(TextSpan(
            text: text.substring(hlStart, hlEnd),
            style: (span.style ?? baseStyle).copyWith(
              backgroundColor:
                  isCurrentMatch ? const Color(0xFFFF9800) : const Color(0xFFFFEB3B),
              color: Colors.black,
            ),
          ));
          pos = hlEnd;
          if (charOffset + pos >= matchEnd) {
            matchListIdx++;
          }
        }
      } else {
        result.add(TextSpan(text: text.substring(pos), style: span.style));
        pos = text.length;
      }
    }
    charOffset += text.length;
  }
  return result;
}
