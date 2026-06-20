import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/code_block_view.dart';

/// Renders Markdown for message blocks, mirroring the original `Markdown.tsx`.
///
/// The original used `react-markdown` + remark-gfm + remark-math + KaTeX with a
/// custom `code` component ([CodeBlockView]) and external links. This wraps
/// [GptMarkdown] (GFM-style text, tables, lists, links and LaTeX via
/// flutter_math_fork) and routes:
///   * fenced code blocks → [CodeBlockView] (language header + copy);
///   * inline code → a subtle monospace chip;
///   * links → opened externally (`target="_blank"` equivalent);
///   * tables → [MarkdownTable], mirroring Kelivo's renderer (columns flex to
///     fill the width with wrapping cells, falling back to fixed-width columns
///     inside a horizontal scroll view only when there are many columns).
///
/// LaTeX uses single/double dollar delimiters (`$...$`, `$$...$$`), matching the
/// original's `mathEnableSingleDollar` default.
class AppMarkdown extends StatelessWidget {
  const AppMarkdown({required this.content, this.style, super.key});

  final String content;
  final TextStyle? style;

  static void _openLink(String url, String _) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Widget _inlineCode(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: style.copyWith(fontFamily: 'monospace')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = style ?? theme.textTheme.bodyMedium;

    final brightness = theme.brightness;
    final baseSize = baseStyle?.fontSize ?? 16;

    // Mirror the original markdown.css heading sizes (all relative to body
    // font-size via em units). Because AetherlinkApp applies a global
    // TextScaler (fontSize / 16), baseSize is already scaled — multiplying
    // by the same ratios keeps headings proportional exactly like the web
    // version:
    //   h1: 2em, h2: 1.5em, h3: 1.2em, h4: 1em, h5: 0.9em, h6: 0.8em
    return GptMarkdownTheme(
      gptThemeData: GptMarkdownThemeData(
        brightness: brightness,
        h1: baseStyle?.copyWith(
          fontSize: baseSize * 2.0,
          fontWeight: FontWeight.bold,
        ),
        h2: baseStyle?.copyWith(
          fontSize: baseSize * 1.5,
          fontWeight: FontWeight.bold,
        ),
        h3: baseStyle?.copyWith(
          fontSize: baseSize * 1.2,
          fontWeight: FontWeight.w600,
        ),
        h4: baseStyle?.copyWith(
          fontSize: baseSize * 1.0,
          fontWeight: FontWeight.w600,
        ),
        h5: baseStyle?.copyWith(
          fontSize: baseSize * 0.9,
          fontWeight: FontWeight.w600,
        ),
        h6: baseStyle?.copyWith(
          fontSize: baseSize * 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: GptMarkdown(
        content,
        style: baseStyle,
        useDollarSignsForLatex: true,
        onLinkTap: _openLink,
        codeBuilder: (context, name, code, closed) =>
            CodeBlockView(language: name, code: code),
        highlightBuilder: _inlineCode,
        tableBuilder: (context, rows, textStyle, config) =>
            MarkdownTable(rows: rows, baseStyle: textStyle),
      ),
    );
  }
}

/// A Markdown table mirroring Kelivo's renderer: columns flex to fill the
/// available width (cells wrap) so typical tables never scroll horizontally,
/// switching to fixed-width columns inside a plain horizontal scroll view only
/// when there are many columns that would otherwise be too cramped.
///
/// Colours come from the Material [ColorScheme]: a soft [ColorScheme.outlineVariant]
/// border, a primary-tinted header and a very faint primary-tinted body, all
/// inside a rounded, clipped frame. There is deliberately no overlay
/// [Scrollbar] — it would otherwise paint over the last row of short tables.
class MarkdownTable extends StatelessWidget {
  const MarkdownTable({required this.rows, required this.baseStyle, super.key});

  final List<CustomTableRow> rows;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.22 : 0.30,
    );
    final headerBg = Color.alphaBlend(
      cs.primary.withValues(alpha: isDark ? 0.15 : 0.07),
      cs.surface,
    );
    final bodyBg = Color.alphaBlend(
      cs.primary.withValues(alpha: isDark ? 0.04 : 0.015),
      cs.surface,
    );

    final colCount = rows.fold<int>(
      0,
      (max, row) => math.max(max, row.fields.length),
    );
    if (colCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final columnWidth = _columnWidth(maxWidth, colCount);
        final scrollHorizontally =
            colCount >= 4 && columnWidth * colCount > maxWidth;

        final table = _buildTable(
          context,
          colCount: colCount,
          borderColor: borderColor,
          headerBg: headerBg,
          columnWidth: columnWidth,
          fixedColumns: scrollHorizontally,
        );

        final frame = Container(
          decoration: BoxDecoration(
            color: bodyBg,
            borderRadius: BorderRadius.circular(10),
          ),
          foregroundDecoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 0.8),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: scrollHorizontally
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  clipBehavior: Clip.hardEdge,
                  child: table,
                )
              : table,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: frame,
        );
      },
    );
  }

  Widget _buildTable(
    BuildContext context, {
    required int colCount,
    required Color borderColor,
    required Color headerBg,
    required double columnWidth,
    required bool fixedColumns,
  }) {
    final columnWidth0 = fixedColumns
        ? FixedColumnWidth(columnWidth)
        : const FlexColumnWidth();
    return Table(
      defaultColumnWidth: columnWidth0,
      columnWidths: {for (var i = 0; i < colCount; i++) i: columnWidth0},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        horizontalInside: BorderSide(color: borderColor, width: 0.5),
        verticalInside: BorderSide(color: borderColor, width: 0.5),
      ),
      children: [
        for (final row in rows)
          TableRow(
            decoration: row.isHeader ? BoxDecoration(color: headerBg) : null,
            children: [
              for (var c = 0; c < colCount; c++)
                _cell(
                  context,
                  field: c < row.fields.length ? row.fields[c] : null,
                  isHeader: row.isHeader,
                ),
            ],
          ),
      ],
    );
  }

  Widget _cell(
    BuildContext context, {
    required CustomTableField? field,
    required bool isHeader,
  }) {
    final cs = Theme.of(context).colorScheme;
    final data = field?.data ?? '';
    final align = field?.alignment ?? TextAlign.left;

    final cellStyle = baseStyle.copyWith(
      fontWeight: isHeader ? FontWeight.w600 : baseStyle.fontWeight,
      color: isHeader ? cs.onSurface : cs.onSurface.withValues(alpha: 0.90),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Align(
        alignment: switch (align) {
          TextAlign.center => Alignment.center,
          TextAlign.right => Alignment.centerRight,
          _ => Alignment.centerLeft,
        },
        child: GptMarkdown(
          data,
          style: cellStyle,
          textAlign: align,
          useDollarSignsForLatex: true,
          onLinkTap: AppMarkdown._openLink,
          highlightBuilder: AppMarkdown._inlineCode,
        ),
      ),
    );
  }

  /// Per-column width for the fixed-column horizontal-scroll fallback, mirroring
  /// Kelivo's compact sizing (`(width - 16) / visibleColumns`, clamped). Only
  /// used when [colCount] >= 4 and the columns would overflow the viewport.
  double _columnWidth(double maxWidth, int colCount) {
    final safeMax = maxWidth.isFinite && maxWidth > 0 ? maxWidth : 360.0;
    if (colCount <= 1) {
      return (safeMax - 16).clamp(220.0, 360.0).toDouble();
    }
    final visibleColumns = colCount >= 4 ? 2.45 : colCount.toDouble();
    return ((safeMax - 16) / visibleColumns).clamp(112.0, 178.0).toDouble();
  }
}
