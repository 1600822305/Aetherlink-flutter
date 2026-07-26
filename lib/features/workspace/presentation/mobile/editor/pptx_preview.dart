// 编辑器内的 .pptx/.potx 只读预览：复用 aetherlink_pptx 的 readPptxBytes
// （纯 Dart OOXML 解析，在后台 isolate 里跑），按幻灯片真实宽高比与形状
// 坐标（EMU）做版面级渲染：文本 run 样式、图片字节、表格、图表（内置
// 柱/折/饼画笔）、形状填充。不是像素级还原（母版装饰、渐变、艺术字等
// 不渲染）；要原样查看可用「用其他应用打开」。

import 'dart:math' as math;

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

/// 1 pt = 12700 EMU；fontSizePx = sizePt * 12700 * (画布px / 幻灯片EMU宽)。
const double _emuPerPt = 12700;

Color? _hex(String? rrggbb, [double alpha = 1]) {
  if (rrggbb == null) return null;
  final v = int.tryParse(rrggbb, radix: 16);
  if (v == null) return null;
  return Color(0xFF000000 | v).withValues(alpha: alpha);
}

/// Reads a .pptx/.potx through [backend] and renders read-only slides at
/// their true aspect ratio with positioned shapes.
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
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: result.slides.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${result.title ?? entry.name} · 共 ${result.slides.length} 页',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '用其他应用打开',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.externalLink, size: 16),
                  onPressed: () =>
                      shareWorkspaceFile(context, ref, entry: entry),
                ),
              ],
            ),
          );
        }
        final index = i - 1;
        final slide = result.slides[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('第 ${index + 1} 页', style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              _SlideCanvas(result: result, slide: slide),
              if (slide.notes != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '备注：${slide.notes}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One slide, rendered at true aspect ratio; shapes positioned by their
/// EMU frames scaled to the canvas width.
class _SlideCanvas extends StatelessWidget {
  const _SlideCanvas({required this.result, required this.slide});

  final PptxReadResult result;
  final PptxSlideContent slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = _hex(slide.backgroundHex) ?? Colors.white;
    return AspectRatio(
      aspectRatio: result.slideWidthInches / result.slideHeightInches,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / result.slideWidthEmu;
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: theme.dividerColor, width: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (final shape in slide.shapes)
                    if (shape.rect != null && _isVisible(shape))
                      Positioned(
                        left: shape.rect!.x * scale,
                        top: shape.rect!.y * scale,
                        width: math.max(1, shape.rect!.w * scale),
                        height: math.max(1, shape.rect!.h * scale),
                        child: _rotated(
                          shape,
                          _ShapeView(shape: shape, scale: scale, slideBg: bg),
                        ),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static bool _isVisible(PptxShape s) => switch (s.kind) {
    PptxShapeKind.text ||
    PptxShapeKind.image ||
    PptxShapeKind.table ||
    PptxShapeKind.chart => true,
    PptxShapeKind.shape => s.fillHex != null || s.lineHex != null,
  };

  static Widget _rotated(PptxShape shape, Widget child) =>
      shape.rotationDeg == 0
      ? child
      : Transform.rotate(angle: shape.rotationDeg * math.pi / 180, child: child);
}

class _ShapeView extends StatelessWidget {
  const _ShapeView({
    required this.shape,
    required this.scale,
    required this.slideBg,
  });

  final PptxShape shape;
  final double scale;
  final Color slideBg;

  @override
  Widget build(BuildContext context) {
    switch (shape.kind) {
      case PptxShapeKind.image:
        return _image();
      case PptxShapeKind.table:
        return _TableView(table: shape.table!, scale: scale);
      case PptxShapeKind.chart:
        return _ChartView(chart: shape.chart!);
      case PptxShapeKind.text:
      case PptxShapeKind.shape:
        return _box(context);
    }
  }

  Widget _image() {
    final bytes = shape.imageBytes;
    if (bytes == null) {
      // wmf/emf 等 Flutter 解不了的格式：给个占位框。
      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.04),
          border: Border.all(color: Colors.black26, width: 0.5),
        ),
        child: const Center(
          child: Icon(LucideIcons.image, size: 16, color: Colors.black38),
        ),
      );
    }
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0x11000000),
        child: Center(
          child: Icon(LucideIcons.imageOff, size: 16, color: Colors.black38),
        ),
      ),
    );
  }

  Widget _box(BuildContext context) {
    final fill = _hex(shape.fillHex);
    final line = _hex(shape.lineHex);
    final isEllipse = shape.geometry == 'ellipse';
    final radius = shape.geometry == 'roundRect'
        ? BorderRadius.circular(6 * scale * _emuPerPt)
        : null;
    return Container(
      decoration: BoxDecoration(
        color: fill,
        shape: isEllipse ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isEllipse ? null : radius,
        border: line == null
            ? null
            : Border.all(color: line, width: math.max(0.5, _emuPerPt * scale)),
      ),
      alignment: Alignment.center,
      child: shape.paragraphs.isEmpty ? null : _text(),
    );
  }

  Widget _text() {
    final onDark = _luminance(shape.fillHex) < 0.4 && shape.fillHex != null;
    final fallback = onDark
        ? Colors.white
        : (_luminance(null, bg: slideBg) < 0.4 ? Colors.white : const Color(0xFF212121));
    final defaultPt = shape.isTitlePlaceholder
        ? 28.0
        : shape.placeholderType == 'subTitle'
        ? 18.0
        : 14.0;
    double px(double pt) => math.max(6, pt * _emuPerPt * scale);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 4 * _emuPerPt * scale,
        vertical: 2 * _emuPerPt * scale,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in shape.paragraphs)
            if (p.text.trim().isNotEmpty || shape.paragraphs.length > 1)
              Padding(
                padding: EdgeInsets.only(left: p.level * 12.0 * _emuPerPt * scale),
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (p.bullet)
                        TextSpan(
                          text: '•  ',
                          style: TextStyle(
                            color: fallback,
                            fontSize: px(
                              p.runs.firstOrNull?.sizePt ?? defaultPt,
                            ),
                          ),
                        ),
                      for (final r in p.runs)
                        TextSpan(
                          text: r.text,
                          style: TextStyle(
                            color: _hex(r.colorHex) ?? fallback,
                            fontSize: px(r.sizePt ?? defaultPt),
                            height: 1.25,
                            fontWeight: r.bold
                                ? FontWeight.w700
                                : shape.isTitlePlaceholder
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontStyle: r.italic
                                ? FontStyle.italic
                                : FontStyle.normal,
                            decoration: r.underline
                                ? TextDecoration.underline
                                : null,
                            fontFamily: r.fontFamily,
                          ),
                        ),
                    ],
                  ),
                  textAlign: switch (p.align) {
                    'ctr' => TextAlign.center,
                    'r' => TextAlign.right,
                    'just' => TextAlign.justify,
                    _ => TextAlign.left,
                  },
                ),
              ),
        ],
      ),
    );
  }

  static double _luminance(String? hexStr, {Color? bg}) {
    final c = _hex(hexStr) ?? bg;
    return c?.computeLuminance() ?? 1;
  }
}

/// Table stretched into its frame; content scales down to fit.
class _TableView extends StatelessWidget {
  const _TableView({required this.table, required this.scale});

  final PptxTableContent table;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (table.rows.isEmpty) return const SizedBox.shrink();
    final columns = table.rows
        .map((r) => r.length)
        .fold<int>(0, (a, b) => a > b ? a : b);
    if (columns == 0) return const SizedBox.shrink();
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topLeft,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: Colors.black26, width: 0.5),
        children: [
          for (final (r, row) in table.rows.indexed)
            TableRow(
              decoration: r == 0
                  ? const BoxDecoration(color: Color(0x14000000))
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
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF212121),
                        fontWeight: r == 0 ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Cached chart data drawn as a real mini chart (bar / line / pie /
/// doughnut / area); other kinds fall back to a data summary.
class _ChartView extends StatelessWidget {
  const _ChartView({required this.chart});

  final PptxChartContent chart;

  static const _palette = [
    Color(0xFF4472C4),
    Color(0xFFED7D31),
    Color(0xFFA5A5A5),
    Color(0xFFFFC000),
    Color(0xFF5B9BD5),
    Color(0xFF70AD47),
  ];

  @override
  Widget build(BuildContext context) {
    final drawable =
        const {'bar', 'bar3D', 'line', 'pie', 'doughnut', 'area'}
            .contains(chart.kind) &&
        chart.series.any((s) => s.values.isNotEmpty);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chart.title != null)
            Text(
              chart.title!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF212121),
              ),
            ),
          Expanded(
            child: drawable
                ? CustomPaint(
                    painter: _MiniChartPainter(chart: chart, palette: _palette),
                  )
                : _summary(),
          ),
          if (chart.series.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  for (final (i, s) in chart.series.indexed)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          color: _palette[i % _palette.length],
                        ),
                        const SizedBox(width: 3),
                        Text(
                          s.name,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _summary() {
    String fmt(double v) =>
        v == v.roundToDouble() ? v.round().toString() : v.toString();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '图表（${chart.kind}）',
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          for (final s in chart.series)
            Text(
              '${s.name}: ${s.values.map(fmt).join(', ')}',
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
        ],
      ),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  _MiniChartPainter({required this.chart, required this.palette});

  final PptxChartContent chart;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (chart.kind == 'pie' || chart.kind == 'doughnut') {
      _paintPie(canvas, size);
      return;
    }
    _paintCartesian(canvas, size);
  }

  void _paintPie(Canvas canvas, Size size) {
    final values = chart.series.first.values.where((v) => v > 0).toList();
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 2;
    var start = -math.pi / 2;
    for (final (i, v) in values.indexed) {
      final sweep = v / total * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        Paint()..color = palette[i % palette.length],
      );
      start += sweep;
    }
    if (chart.kind == 'doughnut') {
      canvas.drawCircle(center, radius * 0.55, Paint()..color = Colors.white);
    }
  }

  void _paintCartesian(Canvas canvas, Size size) {
    final n = chart.series
        .map((s) => s.values.length)
        .fold<int>(0, (a, b) => a > b ? a : b);
    if (n == 0) return;
    var maxV = 0.0, minV = 0.0;
    for (final s in chart.series) {
      for (final v in s.values) {
        maxV = math.max(maxV, v);
        minV = math.min(minV, v);
      }
    }
    if (maxV == minV) maxV = minV + 1;
    final plot = Rect.fromLTWH(0, 2, size.width, size.height - 4);
    double yOf(double v) =>
        plot.bottom - (v - minV) / (maxV - minV) * plot.height;

    // 零轴/底轴。
    canvas.drawLine(
      Offset(plot.left, yOf(math.max(0, minV))),
      Offset(plot.right, yOf(math.max(0, minV))),
      Paint()
        ..color = Colors.black26
        ..strokeWidth = 0.7,
    );

    final isBar = chart.kind.startsWith('bar');
    if (isBar) {
      final groupW = plot.width / n;
      final barW = groupW * 0.7 / chart.series.length;
      for (final (si, s) in chart.series.indexed) {
        final paint = Paint()..color = palette[si % palette.length];
        for (var i = 0; i < s.values.length; i++) {
          final x = plot.left + i * groupW + groupW * 0.15 + si * barW;
          final y0 = yOf(0);
          final y1 = yOf(s.values[i]);
          canvas.drawRect(
            Rect.fromLTRB(x, math.min(y0, y1), x + barW * 0.9, math.max(y0, y1)),
            paint,
          );
        }
      }
      return;
    }

    // line / area / scatter 等：按点连线。
    for (final (si, s) in chart.series.indexed) {
      if (s.values.isEmpty) continue;
      final color = palette[si % palette.length];
      final path = Path();
      for (var i = 0; i < s.values.length; i++) {
        final x = n == 1
            ? plot.center.dx
            : plot.left + i / (n - 1) * plot.width;
        final y = yOf(s.values[i]);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      if (chart.kind == 'area') {
        final fill = Path.from(path)
          ..lineTo(plot.right, yOf(math.max(0, minV)))
          ..lineTo(plot.left, yOf(math.max(0, minV)))
          ..close();
        canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.25));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_MiniChartPainter old) =>
      old.chart != chart || old.palette != palette;
}
