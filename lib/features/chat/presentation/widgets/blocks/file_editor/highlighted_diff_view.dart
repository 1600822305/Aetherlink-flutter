import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/settings/application/font_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/code_block/code_highlight_utils.dart';
import 'package:aetherlink_flutter/shared/utils/line_diff.dart';

/// Renders a line-level [LineDiff] as a Cursor/Windsurf-style unified diff:
/// red removed rows, green added rows, plain context, with syntax highlighting
/// layered on top of the diff backgrounds.
///
/// Highlighting uses full-file context: the "new" side (context + added) and
/// the "old" side (context + removed) are each highlighted as a whole and then
/// split per line, so multi-line constructs (block comments, strings) colour
/// correctly instead of being lexed line-by-line.
class HighlightedDiffView extends ConsumerStatefulWidget {
  const HighlightedDiffView({
    required this.diff,
    this.language,
    this.collapsedMaxLines = 18,
    super.key,
  });

  final LineDiff diff;
  final String? language;

  /// When the diff has more lines than this, it renders collapsed with a
  /// "展开全部" toggle. Set to a large number to disable.
  final int collapsedMaxLines;

  @override
  ConsumerState<HighlightedDiffView> createState() =>
      _HighlightedDiffViewState();
}

class _HighlightedDiffViewState extends ConsumerState<HighlightedDiffView> {
  bool _expanded = false;

  // Cached per-line spans, keyed by the inputs that affect them.
  List<List<TextSpan>>? _cachedSpans;
  Object? _spanKey;

  static const _addedBg = Color(0x1A22863A);
  static const _removedBg = Color(0x1ACB2431);
  static const _addedSign = Color(0xFF22863A);
  static const _removedSign = Color(0xFFCB2431);

  List<List<TextSpan>> _computeSpans(Map<String, TextStyle> theme) {
    final lang = normalizeHighlightLanguage(widget.language ?? '');
    final lines = widget.diff.lines;

    // Reconstruct old/new sides to preserve cross-line highlight context.
    final newLines = <String>[];
    final oldLines = <String>[];
    final newIndex = <int>[]; // diff-line index -> index in newLines
    final oldIndex = <int>[];
    for (final line in lines) {
      switch (line.type) {
        case DiffLineType.added:
          newIndex.add(newLines.length);
          oldIndex.add(-1);
          newLines.add(line.text);
        case DiffLineType.removed:
          oldIndex.add(oldLines.length);
          newIndex.add(-1);
          oldLines.add(line.text);
        case DiffLineType.context:
          newIndex.add(newLines.length);
          oldIndex.add(oldLines.length);
          newLines.add(line.text);
          oldLines.add(line.text);
      }
    }

    final newSpans = _highlightLines(newLines, lang, theme);
    final oldSpans = _highlightLines(oldLines, lang, theme);

    return List.generate(lines.length, (i) {
      final ni = newIndex[i];
      if (ni >= 0 && ni < newSpans.length) return newSpans[ni];
      final oi = oldIndex[i];
      if (oi >= 0 && oi < oldSpans.length) return oldSpans[oi];
      return [TextSpan(text: lines[i].text)];
    });
  }

  static List<List<TextSpan>> _highlightLines(
    List<String> lines,
    String? lang,
    Map<String, TextStyle> theme,
  ) {
    if (lines.isEmpty) return const [];
    final spans = parseToSpans(lines.join('\n'), lang, theme);
    return splitSpansByLine(spans, lines.length);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeName = ref.watch(
      sidebarSettingsControllerProvider.select((s) => s.codeHighlightTheme),
    );
    final codeFont = ref.watch(codeFontFamilyProvider);
    final highlightTheme = resolveTheme(themeName, isDark);

    final key = (themeName, isDark, widget.language, widget.diff.lines.length);
    if (_cachedSpans == null || key != _spanKey) {
      _spanKey = key;
      _cachedSpans = _computeSpans(highlightTheme);
    }
    final spans = _cachedSpans!;

    final codeStyle = TextStyle(
      fontFamily: codeFont ?? 'monospace',
      fontFamilyFallback: const ['monospace'],
      fontSize: 12.5,
      height: 1.45,
      color: theme.colorScheme.onSurface,
    );

    final lines = widget.diff.lines;
    final overflow = lines.length - widget.collapsedMaxLines;
    final showToggle = overflow > 0;
    final visibleCount =
        (_expanded || !showToggle) ? lines.length : widget.collapsedMaxLines;

    // Two-column line-number gutter (old | new), shown only when at least one
    // line carries a known position.
    var maxNum = 0;
    for (final l in lines) {
      if ((l.oldLine ?? 0) > maxNum) maxNum = l.oldLine!;
      if ((l.newLine ?? 0) > maxNum) maxNum = l.newLine!;
    }
    final showGutter = maxNum > 0;
    final numWidth = maxNum.toString().length * 7.5 + 4;
    final lineNumberStyle = codeStyle.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
      fontWeight: FontWeight.w400,
    );
    final gutterBorder = theme.dividerColor.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < visibleCount; i++)
                _row(
                  lines[i],
                  spans[i],
                  codeStyle,
                  showGutter: showGutter,
                  numWidth: numWidth,
                  numberStyle: lineNumberStyle,
                  gutterBorder: gutterBorder,
                ),
            ],
          ),
        ),
        if (showToggle)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              child: Text(
                _expanded ? '收起' : '展开全部 ${lines.length} 行',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _row(
    DiffLine line,
    List<TextSpan> spans,
    TextStyle codeStyle, {
    required bool showGutter,
    required double numWidth,
    required TextStyle numberStyle,
    required Color gutterBorder,
  }) {
    final (bg, sign, signColor) = switch (line.type) {
      DiffLineType.added => (_addedBg, '+', _addedSign),
      DiffLineType.removed => (_removedBg, '-', _removedSign),
      DiffLineType.context => (Colors.transparent, ' ', null),
    };

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showGutter)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: gutterBorder)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _numCell(line.oldLine, numWidth, numberStyle),
                  const SizedBox(width: 2),
                  _numCell(line.newLine, numWidth, numberStyle),
                ],
              ),
            ),
          SizedBox(
            width: 14,
            child: Text(
              sign,
              style: codeStyle.copyWith(
                color: signColor ?? codeStyle.color?.withValues(alpha: 0.3),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: codeStyle,
                children: spans.isEmpty ? [const TextSpan(text: ' ')] : spans,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numCell(int? n, double width, TextStyle style) => SizedBox(
        width: width,
        child: Text(
          n?.toString() ?? '',
          textAlign: TextAlign.right,
          style: style,
        ),
      );
}
