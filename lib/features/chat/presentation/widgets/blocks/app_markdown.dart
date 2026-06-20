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
///   * tables → [MarkdownTable], mirroring the original `markdown.css` table
///     styling (soft borders, rounded container, header tint, zebra rows,
///     horizontal scroll).
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

/// A Markdown table mirroring the original web `markdown.css` styling:
/// rounded scroll container with a subtle shadow, soft 1px cell borders, a
/// tinted bold header row, zebra-striped body rows, per-cell minimum width and
/// horizontal scrolling when the content overflows.
class MarkdownTable extends StatelessWidget {
  const MarkdownTable({required this.rows, required this.baseStyle, super.key});

  final List<CustomTableRow> rows;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor = isDark
        ? const Color(0xFF404040)
        : const Color(0xFFE0E0E0);
    final headerBg = isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA);
    final zebraBg = isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA);
    final containerBg = isDark
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFFFFFFF);
    final cellColor = isDark
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF333333);
    final headerColor = isDark
        ? const Color(0xFFF7FAFC)
        : const Color(0xFF2C3E50);

    final colCount = rows.fold<int>(
      0,
      (max, row) => math.max(max, row.fields.length),
    );
    if (colCount == 0) return const SizedBox.shrink();

    final bodyRows = rows.where((r) => !r.isHeader).toList();

    final tableRows = <TableRow>[
      for (final row in rows.where((r) => r.isHeader))
        _buildRow(
          context,
          row,
          decoration: BoxDecoration(color: headerBg),
          textColor: headerColor,
          isHeader: true,
          colCount: colCount,
        ),
      // The original applies zebra striping to `tbody tr:nth-child(even)`,
      // i.e. the 2nd, 4th, ... body rows (0-based odd indices).
      for (var i = 0; i < bodyRows.length; i++)
        _buildRow(
          context,
          bodyRows[i],
          decoration: i.isOdd ? BoxDecoration(color: zebraBg) : null,
          textColor: cellColor,
          isHeader: false,
          colCount: colCount,
        ),
    ];

    final controller = ScrollController();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        controller: controller,
        child: SingleChildScrollView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const _MinWidthColumnWidth(),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder(
              horizontalInside: BorderSide(color: borderColor),
              verticalInside: BorderSide(color: borderColor),
            ),
            children: tableRows,
          ),
        ),
      ),
    );
  }

  TableRow _buildRow(
    BuildContext context,
    CustomTableRow row, {
    required BoxDecoration? decoration,
    required Color textColor,
    required bool isHeader,
    required int colCount,
  }) {
    return TableRow(
      decoration: decoration,
      children: List.generate(colCount, (i) {
        final field = i < row.fields.length ? row.fields[i] : null;
        final data = field?.data ?? '';
        final align = field?.alignment ?? TextAlign.left;

        final cellStyle = baseStyle.copyWith(
          color: textColor,
          fontWeight: isHeader ? FontWeight.bold : baseStyle.fontWeight,
        );

        return Container(
          constraints: const BoxConstraints(minWidth: 80),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        );
      }),
    );
  }
}

/// A table column that sizes to the natural (unwrapped) width of its widest
/// cell, capped at the available width — mirroring the original's
/// `white-space: nowrap` plus horizontal scrolling behaviour.
class _MinWidthColumnWidth extends TableColumnWidth {
  const _MinWidthColumnWidth();

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    var width = 0.0;
    for (final cell in cells) {
      cell.layout(const BoxConstraints(), parentUsesSize: true);
      width = math.max(width, cell.size.width);
    }
    return math.min(containerWidth, width);
  }

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return 0;
  }
}
