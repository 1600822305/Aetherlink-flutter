import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
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
/// LaTeX dollar-delimiter support (`$...$`, `$$...$$`) is controlled by the
/// sidebar's `mathEnableSingleDollar` setting, read live via Riverpod.
class AppMarkdown extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final dollarLatex = ref.watch(
      sidebarSettingsControllerProvider.select((s) => s.mathEnableSingleDollar),
    );
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
        useDollarSignsForLatex: dollarLatex,
        onLinkTap: _openLink,
        codeBuilder: (context, name, code, closed) =>
            CodeBlockView(language: name, code: code),
        highlightBuilder: _inlineCode,
        tableBuilder: (context, rows, textStyle, config) => MarkdownTable(
          rows: rows,
          baseStyle: textStyle,
          useDollarSignsForLatex: dollarLatex,
        ),
      ),
    );
  }
}

/// A Markdown table matching rikkahub's style: a card with a toolbar header
/// ("表格" label + copy button), neutral surfaceContainerHighest header row,
/// surfaceContainer body, outlineVariant cell borders, columns sized between
/// 80–200px, and stretch-to-fill when narrow. Horizontal scroll with a bottom
/// indicator when the table overflows.
class MarkdownTable extends StatefulWidget {
  const MarkdownTable({
    required this.rows,
    required this.baseStyle,
    this.useDollarSignsForLatex = true,
    super.key,
  });

  final List<CustomTableRow> rows;
  final TextStyle baseStyle;
  final bool useDollarSignsForLatex;

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

  String _buildMarkdownSource() {
    final buf = StringBuffer();
    for (final row in widget.rows) {
      final cells = row.fields.map((f) => f.data).toList();
      buf.writeln('| ${cells.join(' | ')} |');
      if (row.isHeader) {
        buf.writeln('| ${cells.map((_) => '---').join(' | ')} |');
      }
    }
    return buf.toString().trimRight();
  }

  String _buildCsv() {
    final buf = StringBuffer();
    for (final row in widget.rows) {
      final cells = row.fields.map((f) {
        final v = f.data;
        if (v.contains(',') || v.contains('"') || v.contains('\n')) {
          return '"${v.replaceAll('"', '""')}"';
        }
        return v;
      }).toList();
      buf.writeln(cells.join(','));
    }
    return buf.toString().trimRight();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final borderColor = cs.outlineVariant;
    final toolbarBg = cs.surfaceContainerHighest;
    final tableHeaderBg = cs.surfaceContainerHigh;
    final bodyBg = cs.surfaceContainer;
    final trackColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.20 : 0.28,
    );
    final thumbColor = cs.onSurface.withValues(alpha: isDark ? 0.42 : 0.38);

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
          headerBg: tableHeaderBg,
          maxColWidth: maxWidth,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollable());

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: bodyBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Toolbar
                Container(
                  color: toolbarBg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '表格',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ToolbarIconButton(
                            icon: LucideIcons.copy,
                            tooltip: '复制表格',
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: _buildMarkdownSource()),
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          _ToolbarIconButton(
                            icon: LucideIcons.download,
                            tooltip: '下载 CSV',
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: _buildCsv()),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Table content with horizontal scroll
                ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: table,
                  ),
                ),
                if (_scrollable)
                  _BottomScrollIndicator(
                    controller: _controller,
                    trackColor: trackColor,
                    thumbColor: thumbColor,
                  ),
              ],
            ),
          ),
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
    final columnWidth = _ContentColumnWidth(
      minWidth: 80,
      maxWidth: math.min(200, maxColWidth),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          useDollarSignsForLatex: widget.useDollarSignsForLatex,
          onLinkTap: AppMarkdown._openLink,
          highlightBuilder: AppMarkdown._inlineCode,
        ),
      ),
    );
  }
}

/// Small icon button used in the table toolbar.
class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 16,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

/// A slim horizontal scroll bar laid out *below* the table (a sibling in the
/// Column, never an overlay), so it can never paint over a row.
class _BottomScrollIndicator extends StatelessWidget {
  const _BottomScrollIndicator({
    required this.controller,
    required this.trackColor,
    required this.thumbColor,
  });

  final ScrollController controller;
  final Color trackColor;
  final Color thumbColor;

  static const double _height = 5;

  Widget _bar(double width, Color color) => Container(
    width: width,
    height: _height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(_height),
    ),
  );

  ({double width, double left, double max, double free}) _geometry(
    double track,
  ) {
    if (!controller.hasClients || !controller.position.hasContentDimensions) {
      return (width: track, left: 0, max: 0, free: 0);
    }
    final pos = controller.position;
    final max = pos.maxScrollExtent;
    final width =
        (track * pos.viewportDimension / (pos.viewportDimension + max)).clamp(
          28.0,
          track,
        );
    final free = track - width;
    final left = max > 0 ? free * (pos.pixels.clamp(0.0, max) / max) : 0.0;
    return (width: width, left: left, max: max, free: free);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final track = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) {
              final g = _geometry(track);
              if (g.free <= 0 || g.max <= 0) return;
              controller.jumpTo(
                (controller.position.pixels + d.delta.dx * g.max / g.free)
                    .clamp(0.0, g.max),
              );
            },
            child: SizedBox(
              height: _height,
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final g = _geometry(track);
                  return Stack(
                    children: [
                      _bar(track, trackColor),
                      Positioned(
                        left: g.left,
                        child: _bar(g.width, thumbColor),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Sizes a column between [minWidth] and [maxWidth]. Columns stretch to fill
/// the viewport when the table is narrower than available width.
class _ContentColumnWidth extends TableColumnWidth {
  const _ContentColumnWidth({required this.minWidth, required this.maxWidth});

  final double minWidth;
  final double maxWidth;

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    var width = minWidth;
    for (final cell in cells) {
      cell.layout(const BoxConstraints(), parentUsesSize: true);
      width = math.max(width, cell.size.width);
    }
    return width.clamp(minWidth, maxWidth);
  }

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) {
    return minWidth;
  }

  @override
  double? flex(Iterable<RenderBox> cells) => 1.0;
}
