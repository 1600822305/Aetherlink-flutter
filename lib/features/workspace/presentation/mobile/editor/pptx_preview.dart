// 编辑器内的 .pptx/.potx 只读预览：复用 aetherlink_pptx 的 readPptxBytes
// （纯 Dart OOXML 解析，在后台 isolate 里跑），逐页展示文本、表格、图表
// 数据与演讲者备注。不做像素级还原（母版/主题渲染成本过高），定位是
// 「在工作区里快速查看内容」；要原样查看可用「用其他应用打开」。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_pptx/aetherlink_pptx.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_placeholders.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/workspace_file_share.dart';

/// Whether [name] is a PowerPoint package the editor can preview.
bool isPptxFileName(String name) {
  final n = name.trim().toLowerCase();
  return n.endsWith('.pptx') || n.endsWith('.potx');
}

/// Reads a .pptx/.potx through [backend] and renders a read-only, per-slide
/// content preview (text / tables / chart data / speaker notes).
class PptxPreview extends ConsumerStatefulWidget {
  const PptxPreview({super.key, required this.entry, required this.backend});

  final WorkspaceEntry entry;
  final WorkspaceBackend backend;

  @override
  ConsumerState<PptxPreview> createState() => _PptxPreviewState();
}

class _PptxPreviewState extends ConsumerState<PptxPreview> {
  late Future<PptxReadResult> _load;

  @override
  void initState() {
    super.initState();
    _load = _read();
  }

  Future<PptxReadResult> _read() async {
    final bytes = Uint8List.fromList(
      await widget.backend.readFileBytes(widget.entry.path),
    );
    // 解压 + XML 解析是同步 CPU 工作，放到后台 isolate，避免大文件卡 UI。
    return compute(readPptxBytes, bytes);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PptxReadResult>(
      future: _load,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final result = snap.data;
        if (snap.hasError || result == null) {
          final err = snap.error;
          return UnsupportedFilePlaceholder(
            entry: widget.entry,
            icon: LucideIcons.fileX,
            title: '无法解析该演示文稿',
            message: err is PptxReadException ? err.message : '${err ?? '读取失败'}',
            onOpenExternally: () =>
                shareWorkspaceFile(context, ref, entry: widget.entry),
          );
        }
        return _PptxContent(entry: widget.entry, result: result);
      },
    );
  }
}

class _PptxContent extends ConsumerWidget {
  const _PptxContent({required this.entry, required this.result});

  final WorkspaceEntry entry;
  final PptxReadResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${result.title ?? entry.name} · 共 ${result.slides.length} 页 · '
                '${result.slideWidthInches.toStringAsFixed(1)}×'
                '${result.slideHeightInches.toStringAsFixed(1)} 英寸',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              tooltip: '用其他应用打开',
              visualDensity: VisualDensity.compact,
              icon: const Icon(LucideIcons.externalLink, size: 16),
              onPressed: () => shareWorkspaceFile(context, ref, entry: entry),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final (index, slide) in result.slides.indexed)
          _SlideCard(index: index, slide: slide),
      ],
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.index, required this.slide});

  final int index;
  final PptxSlideContent slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('第 ${index + 1} 页', style: theme.textTheme.labelSmall),
          const SizedBox(height: 6),
          if (slide.texts.isEmpty &&
              slide.tables.isEmpty &&
              slide.charts.isEmpty &&
              slide.imageCount == 0)
            Text('（本页无可提取内容）', style: muted),
          // 首个文本 shape 通常是标题，用 titleSmall 突出。
          for (final (i, text) in slide.texts.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                text,
                style: i == 0
                    ? theme.textTheme.titleSmall
                    : theme.textTheme.bodyMedium,
              ),
            ),
          for (final table in slide.tables)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _SlideTable(table: table),
            ),
          for (final chart in slide.charts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ChartSummary(chart: chart),
            ),
          if (slide.imageCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.image,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text('含 ${slide.imageCount} 张图片', style: muted),
                ],
              ),
            ),
          if (slide.notes != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('备注：${slide.notes}', style: muted),
            ),
        ],
      ),
    );
  }
}

class _SlideTable extends StatelessWidget {
  const _SlideTable({required this.table});

  final PptxTableContent table;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (table.rows.isEmpty) return const SizedBox.shrink();
    final columns = table.rows
        .map((r) => r.length)
        .fold<int>(0, (a, b) => a > b ? a : b);
    if (columns == 0) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: theme.dividerColor, width: 0.5),
        children: [
          for (final (r, row) in table.rows.indexed)
            TableRow(
              decoration: r == 0
                  ? BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                    )
                  : null,
              children: [
                for (var c = 0; c < columns; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      c < row.length ? row[c] : '',
                      style: r == 0
                          ? theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            )
                          : theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChartSummary extends StatelessWidget {
  const _ChartSummary({required this.chart});

  final PptxChartContent chart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    String fmt(double v) =>
        v == v.roundToDouble() ? v.round().toString() : v.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.chartColumn,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              '图表（${chart.kind}${chart.title == null ? '' : '：${chart.title}'}）',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        for (final series in chart.series)
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 2),
            child: Text(
              '${series.name}: ${[
                for (var c = 0; c < series.values.length; c++)
                  '${c < chart.categories.length ? chart.categories[c] : '#${c + 1}'}'
                      '=${fmt(series.values[c])}',
              ].join(', ')}',
              style: muted,
            ),
          ),
      ],
    );
  }
}
