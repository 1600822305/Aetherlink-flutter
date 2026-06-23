import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Whether [language]/[code] should be rendered as a diff.
bool isDiffContent(String? language, String code) {
  if (language == 'diff') return true;
  final lines = code.split('\n');
  if (lines.length < 2) return false;
  final diffLines = lines.where(
    (l) => l.startsWith('+') || l.startsWith('-') || l.startsWith('@@'),
  );
  return diffLines.length > lines.length * 0.3;
}

/// Renders unified diff with per-line coloring: green for additions,
/// red for deletions, blue for hunk headers.
class DiffCodeView extends StatelessWidget {
  const DiffCodeView({
    required this.lines,
    required this.showLineNumbers,
    required this.codeStyle,
    required this.lineNumberStyle,
    required this.gutterBorderColor,
    super.key,
  });

  final List<String> lines;
  final bool showLineNumbers;
  final TextStyle codeStyle;
  final TextStyle lineNumberStyle;
  final Color gutterBorderColor;

  @override
  Widget build(BuildContext context) {
    final gutterWidth = showLineNumbers
        ? math.max(34.0, 18.0 + lines.length.toString().length * 8.0)
        : 0.0;

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(lines.length, (i) {
          final line = lines[i];
          final diffType = _diffType(line);
          final bg = _diffBg(diffType);
          final textColor = _diffTextColor(diffType);

          return Container(
            color: bg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLineNumbers) ...[
                  Container(
                    width: gutterWidth,
                    padding: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: gutterBorderColor),
                      ),
                    ),
                    child: Text(
                      '${i + 1}',
                      textAlign: TextAlign.right,
                      style: lineNumberStyle,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (diffType == _DiffType.added)
                        Text('+',
                            style: codeStyle.copyWith(
                                color: const Color(0xFF22863A),
                                fontWeight: FontWeight.w700))
                      else if (diffType == _DiffType.deleted)
                        Text('-',
                            style: codeStyle.copyWith(
                                color: const Color(0xFFCB2431),
                                fontWeight: FontWeight.w700))
                      else if (diffType == _DiffType.hunk)
                        const SizedBox.shrink()
                      else
                        Text(' ', style: codeStyle),
                      Expanded(
                        child: Text(
                          diffType == _DiffType.context
                              ? (line.length > 1 ? line.substring(1) : '')
                              : (diffType == _DiffType.hunk
                                  ? line
                                  : (line.length > 1
                                      ? line.substring(1)
                                      : '')),
                          style: codeStyle.copyWith(color: textColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

enum _DiffType { added, deleted, hunk, context }

_DiffType _diffType(String line) {
  if (line.startsWith('@@')) return _DiffType.hunk;
  if (line.startsWith('+')) return _DiffType.added;
  if (line.startsWith('-')) return _DiffType.deleted;
  return _DiffType.context;
}

Color _diffBg(_DiffType type) => switch (type) {
      _DiffType.added => const Color(0x1A22863A),
      _DiffType.deleted => const Color(0x1ACB2431),
      _DiffType.hunk => const Color(0x1A0366D6),
      _DiffType.context => Colors.transparent,
    };

Color? _diffTextColor(_DiffType type) => switch (type) {
      _DiffType.added => const Color(0xFF22863A),
      _DiffType.deleted => const Color(0xFFCB2431),
      _DiffType.hunk => const Color(0xFF0366D6),
      _DiffType.context => null,
    };
