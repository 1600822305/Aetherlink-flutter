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

/// A Markdown table styled after Kelivo (soft [ColorScheme.outlineVariant]
/// border, primary-tinted header, faint primary-tinted body, rounded/clipped
/// frame), but with the original web table's scroll behaviour: columns size to
/// their content, and when the table is wider than the bubble it scrolls
/// horizontally with a persistent scrollbar that sits in a reserved bottom
/// gutter (so it never paints over the last row). Narrow tables that fit show
/// no scrollbar and no gutter.
class MarkdownTable extends StatefulWidget {
  const MarkdownTable({required this.rows, required this.baseStyle, super.key});

  final List<CustomTableRow> rows;
  final TextStyle baseStyle;

  @override
  State<MarkdownTable> createState() => _MarkdownTableState();
}

class _MarkdownTableState extends State<MarkdownTable> {
  final ScrollController _controller = ScrollController();
  bool _scrollable = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncScrollable() {
    if (!mounted || !_controller.hasClients) return;
    final scrollable = _controller.position.maxScrollExtent > 0.5;
    if (scrollable != _scrollable) {
      setState(() => _scrollable = scrollable);
    }
  }

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

    final colCount = widget.rows.fold<int>(
      0,
      (max, row) => math.max(max, row.fields.length),
    );
    if (colCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final table = _buildTable(
          context,
          colCount: colCount,
          borderColor: borderColor,
          headerBg: headerBg,
          maxColWidth: maxWidth,
        );

        // The scrollable state is known only after layout; re-sync once the
        // frame settles so the gutter/scrollbar appears only when needed.
        WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollable());

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
          // Suppress the platform's auto overlay scrollbar (desktop/web add one
          // that paints over the last row); keep only the explicit [Scrollbar],
          // whose thumb sits in the reserved bottom gutter below the table.
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: Scrollbar(
              controller: _controller,
              thumbVisibility: _scrollable,
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.only(bottom: _scrollable ? 12 : 0),
                child: table,
              ),
            ),
          ),
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
    required double maxColWidth,
  }) {
    final columnWidth = _ContentColumnWidth(maxWidth: maxColWidth);
    return Table(
      defaultColumnWidth: columnWidth,
      columnWidths: {for (var i = 0; i < colCount; i++) i: columnWidth},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        horizontalInside: BorderSide(color: borderColor, width: 0.5),
        verticalInside: BorderSide(color: borderColor, width: 0.5),
      ),
      children: [
        for (final row in widget.rows)
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

    final cellStyle = widget.baseStyle.copyWith(
      fontWeight: isHeader ? FontWeight.w600 : widget.baseStyle.fontWeight,
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
}

/// Sizes a column to the natural (unwrapped) width of its widest cell, with a
/// lower bound of [_minWidth] and capped at [maxWidth] (the bubble width) so a
/// single long cell wraps instead of stretching the table indefinitely. Tables
/// whose columns sum wider than the viewport then overflow and scroll.
class _ContentColumnWidth extends TableColumnWidth {
  const _ContentColumnWidth({required this.maxWidth});

  static const double _minWidth = 72;

  final double maxWidth;

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    var width = _minWidth;
    for (final cell in cells) {
      cell.layout(const BoxConstraints(), parentUsesSize: true);
      width = math.max(width, cell.size.width);
    }
    return math.min(maxWidth, width);
  }

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return math.min(maxWidth, _minWidth);
  }
}
