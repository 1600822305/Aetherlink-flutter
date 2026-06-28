import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';
import 'code_block_body.dart';
import 'code_block_search.dart';
import 'code_diff_view.dart';
import 'code_highlight_utils.dart';

/// Full-screen code viewer with pinch-to-zoom, search, and copy.
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

  @override
  State<CodeBlockFullScreen> createState() => _CodeBlockFullScreenState();
}

class _CodeBlockFullScreenState extends State<CodeBlockFullScreen> {
  bool _copied = false;
  bool _showSearch = false;
  String _searchQuery = '';
  int _currentMatchIndex = 0;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA);
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final dc = displayCode(widget.code);
    final lines = dc.isEmpty ? <String>[''] : dc.split('\n');
    final useDiff = isDiffContent(widget.highlightLanguage, dc);

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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // `InteractiveViewer` owns all gestures so a two-finger
                  // pinch reliably forms (no inner scroll view to steal the
                  // first pointer): one finger pans, two fingers zoom — like
                  // an image viewer. `constrained: false` lets the content
                  // take its natural size and be freely panned/zoomed.
                  return InteractiveViewer(
                    constrained: false,
                    panEnabled: true,
                    scaleEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    // Pin the content's edges to the viewport (like MT / mobile
                    // text editors): no overscroll past the top-left origin, so
                    // empty space never appears before the code starts.
                    boundaryMargin: EdgeInsets.zero,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                        minHeight: constraints.maxHeight,
                      ),
                      child: _buildContent(
                        dc,
                        lines,
                        useDiff,
                        constraints.maxWidth,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the code content, honoring the code-block "wrap" setting (mirrors
  /// the inline [CodeBlockBody] logic). Wrap/diff modes are pinned to the
  /// viewport width so text wraps; non-wrap mode keeps its natural (possibly
  /// overflowing) width so [InteractiveViewer] can pan across long lines.
  Widget _buildContent(
    String dc,
    List<String> lines,
    bool useDiff,
    double viewportWidth,
  ) {
    if (useDiff) {
      return SizedBox(
        width: viewportWidth,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DiffCodeView(
            lines: lines,
            showLineNumbers: widget.showLineNumbers,
            codeStyle: widget.codeStyle,
            lineNumberStyle: widget.lineNumberStyle,
            gutterBorderColor: widget.gutterBorderColor,
          ),
        ),
      );
    }

    if (widget.wrappable) {
      return SizedBox(
        width: viewportWidth,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: PerLineCodeView(
            lines: lines,
            highlightLanguage: widget.highlightLanguage,
            highlightTheme: widget.highlightTheme,
            showLineNumbers: widget.showLineNumbers,
            codeStyle: widget.codeStyle,
            lineNumberStyle: widget.lineNumberStyle,
            gutterBorderColor: widget.gutterBorderColor,
            searchQuery: _searchQuery,
            currentMatchIndex: _currentMatchIndex,
          ),
        ),
      );
    }

    // Non-wrap: keep each line on a single row at its natural width; horizontal
    // panning is handled by the enclosing InteractiveViewer.
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SingleBlockCodeView(
        code: dc.isEmpty ? ' ' : dc,
        lineCount: lines.length,
        highlightLanguage: widget.highlightLanguage,
        highlightTheme: widget.highlightTheme,
        showLineNumbers: widget.showLineNumbers,
        codeStyle: widget.codeStyle,
        lineNumberStyle: widget.lineNumberStyle,
        gutterBorderColor: widget.gutterBorderColor,
      ),
    );
  }
}
