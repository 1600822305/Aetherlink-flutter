import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_diff_view.dart';

/// Devin Changes 风格的 diff 行渲染：小号等宽字体、不换行（横向滚动）、
/// 左侧单列行号 gutter（新增绿底/删除红底/上下文灰），只有变更行有
/// 浅色整行底色，折叠的未变更区间显示「⋯」分隔条。
class DevinDiffLines extends StatelessWidget {
  const DevinDiffLines({required this.rows, super.key});

  final List<DiffLine> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final green = Colors.green.shade700;
    final red = cs.error;

    var maxNo = 1;
    for (final r in rows) {
      maxNo = math.max(maxNo, math.max(r.oldLine ?? 0, r.newLine ?? 0));
    }
    final digits = maxNo.toString().length;
    final gutterWidth = 14.0 + digits * 8.0;

    const textStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 11.5,
      height: 1.55,
    );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in rows)
                if (row.kind == DiffLineKind.skip)
                  Container(
                    color: cs.onSurface.withValues(alpha: 0.04),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '⋯',
                      style: textStyle.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.left,
                      softWrap: false,
                    ),
                  )
                else
                  _line(cs, green, red, gutterWidth, textStyle, row),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(
    ColorScheme cs,
    Color green,
    Color red,
    double gutterWidth,
    TextStyle textStyle,
    DiffLine row,
  ) {
    final (rowBg, gutterBg, numColor, lineNo) = switch (row.kind) {
      DiffLineKind.added => (
          green.withValues(alpha: 0.08),
          green.withValues(alpha: 0.16),
          green,
          row.newLine,
        ),
      DiffLineKind.removed => (
          red.withValues(alpha: 0.07),
          red.withValues(alpha: 0.14),
          red,
          row.oldLine,
        ),
      _ => (
          Colors.transparent,
          cs.onSurface.withValues(alpha: 0.04),
          cs.onSurfaceVariant,
          row.newLine,
        ),
    };
    return Container(
      color: rowBg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: gutterWidth,
            color: gutterBg,
            padding: const EdgeInsets.only(right: 6),
            alignment: Alignment.centerRight,
            child: Text(
              lineNo?.toString() ?? '',
              style: textStyle.copyWith(color: numColor, fontSize: 10.5),
              softWrap: false,
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              row.text.isEmpty ? ' ' : row.text,
              style: textStyle.copyWith(
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}
