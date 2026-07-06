import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/chart_type.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';

/// Renders a `CHART` block — the port of `ChartBlock.tsx`, which feeds
/// `block.data` / `block.options` straight into Chart.js. The block carries the
/// same Chart.js payload (`{labels, datasets:[{label, data, backgroundColor,
/// borderColor}]}`), parsed here into fl_chart's bar / line / pie / scatter
/// widgets. Bad or missing data renders the web's error text instead of a
/// broken chart.
class ChartBlockView extends StatelessWidget {
  const ChartBlockView({required this.block, super.key});

  final ChartBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _ChartData.parse(block.data);
    if (data == null || data.datasets.isEmpty) {
      return _errorCard(theme, '图表数据无效');
    }

    final title = _chartTitle(block.options);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            // The web card is a fixed 300px tall Paper.
            height: 260,
            child: switch (block.chartType) {
              ChartType.bar => _BarChart(data: data),
              ChartType.line => _LineChart(data: data),
              ChartType.pie => _PieChart(data: data),
              ChartType.scatter => _ScatterChart(data: data),
            },
          ),
          const SizedBox(height: 8),
          _Legend(data: data, chartType: block.chartType),
        ],
      ),
    );
  }

  Widget _errorCard(ThemeData theme, String message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.chartColumn,
            size: 16,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 6),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// `options.plugins.title.text` — the only Chart.js option the original
/// surfaces prominently on mobile.
String? _chartTitle(Map<String, dynamic>? options) {
  final plugins = options?['plugins'];
  if (plugins is! Map) return null;
  final title = plugins['title'];
  if (title is! Map) return null;
  final text = title['text'];
  return text is String && text.isNotEmpty ? text : null;
}

// ── Chart.js payload parsing ─────────────────────────────────────────────────

/// One Chart.js dataset: a label, numeric points (index-based or `{x, y}`) and
/// optional CSS colors.
class _Dataset {
  const _Dataset({
    required this.label,
    required this.points,
    this.color,
    this.sliceColors,
  });

  final String label;

  /// Points as (x, y). For plain numeric arrays x is the element index.
  final List<(double, double)> points;

  /// A single dataset color (border/background), when provided.
  final Color? color;

  /// Per-point colors (pie slices / per-bar backgroundColor arrays).
  final List<Color?>? sliceColors;
}

class _ChartData {
  const _ChartData({required this.labels, required this.datasets});

  final List<String> labels;
  final List<_Dataset> datasets;

  static _ChartData? parse(Object? raw) {
    if (raw is! Map) return null;
    final labels = <String>[
      if (raw['labels'] is List)
        for (final l in raw['labels'] as List) '$l',
    ];
    final rawSets = raw['datasets'];
    if (rawSets is! List) return null;
    final datasets = <_Dataset>[];
    for (var i = 0; i < rawSets.length; i++) {
      final set = rawSets[i];
      if (set is! Map) continue;
      final points = _parsePoints(set['data']);
      if (points == null) continue;
      datasets.add(
        _Dataset(
          label: set['label'] is String ? set['label'] as String : '数据 ${i + 1}',
          points: points,
          color:
              _parseCssColor(set['borderColor']) ??
              _parseCssColor(set['backgroundColor']),
          sliceColors: _parseColorList(set['backgroundColor']),
        ),
      );
    }
    return _ChartData(labels: labels, datasets: datasets);
  }

  static List<(double, double)>? _parsePoints(Object? data) {
    if (data is! List) return null;
    final points = <(double, double)>[];
    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      if (item is num) {
        points.add((i.toDouble(), item.toDouble()));
      } else if (item is Map && item['x'] is num && item['y'] is num) {
        points.add(((item['x'] as num).toDouble(), (item['y'] as num).toDouble()));
      } else if (item == null) {
        // Chart.js allows null gaps; skip them.
      } else {
        return null;
      }
    }
    return points;
  }

  static List<Color?>? _parseColorList(Object? value) {
    if (value is! List) return null;
    return [for (final v in value) _parseCssColor(v)];
  }
}

/// Parses the CSS color strings Chart.js payloads carry: `#RGB[A]`,
/// `#RRGGBB[AA]`, `rgb()/rgba()` and a few common names. Returns null for
/// anything else so callers fall back to the palette.
Color? _parseCssColor(Object? value) {
  if (value is! String) return null;
  final s = value.trim().toLowerCase();
  if (s.startsWith('#')) {
    var hex = s.substring(1);
    if (hex.length == 3 || hex.length == 4) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    if (hex.length == 6) hex = 'ff$hex';
    if (hex.length == 8) {
      // CSS is RRGGBBAA; Color wants AARRGGBB.
      hex = hex.substring(6) + hex.substring(0, 6);
      final v = int.tryParse(hex, radix: 16);
      if (v != null) return Color(v);
    }
    return null;
  }
  final rgb = RegExp(
    r'^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)$',
  ).firstMatch(s);
  if (rgb != null) {
    final a = rgb.group(4) == null ? 1.0 : double.tryParse(rgb.group(4)!) ?? 1.0;
    return Color.fromRGBO(
      int.parse(rgb.group(1)!).clamp(0, 255),
      int.parse(rgb.group(2)!).clamp(0, 255),
      int.parse(rgb.group(3)!).clamp(0, 255),
      a.clamp(0.0, 1.0),
    );
  }
  return const {
    'red': Color(0xFFF44336),
    'green': Color(0xFF4CAF50),
    'blue': Color(0xFF2196F3),
    'orange': Color(0xFFFF9800),
    'purple': Color(0xFF9C27B0),
    'yellow': Color(0xFFFFEB3B),
    'teal': Color(0xFF009688),
    'pink': Color(0xFFE91E63),
    'gray': Color(0xFF9E9E9E),
    'grey': Color(0xFF9E9E9E),
    'black': Color(0xFF000000),
    'white': Color(0xFFFFFFFF),
  }[s];
}

/// Chart.js's default palette, used when a dataset carries no usable color.
const List<Color> _palette = [
  Color(0xFF36A2EB),
  Color(0xFFFF6384),
  Color(0xFF4BC0C0),
  Color(0xFFFF9F40),
  Color(0xFF9966FF),
  Color(0xFFFFCD56),
  Color(0xFFC9CBCF),
];

Color _datasetColor(_Dataset set, int index) =>
    set.color ?? _palette[index % _palette.length];

Color _pointColor(_Dataset set, int datasetIndex, int pointIndex) =>
    set.sliceColors?.elementAtOrNull(pointIndex) ??
    set.color ??
    _palette[pointIndex % _palette.length];

String _axisLabel(List<String> labels, double value) {
  final i = value.round();
  if ((value - i).abs() > 0.01) return '';
  if (i >= 0 && i < labels.length) return labels[i];
  return '';
}

double _maxY(_ChartData data) {
  var maxY = 0.0;
  for (final set in data.datasets) {
    for (final (_, y) in set.points) {
      if (y > maxY) maxY = y;
    }
  }
  return maxY <= 0 ? 1 : maxY;
}

Widget _bottomTitle(
  BuildContext context,
  List<String> labels,
  double value,
) {
  final text = _axisLabel(labels, value);
  if (text.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      overflow: TextOverflow.ellipsis,
    ),
  );
}

FlGridData _grid(ThemeData theme) => FlGridData(
  drawVerticalLine: false,
  getDrawingHorizontalLine: (_) =>
      FlLine(color: theme.dividerColor.withValues(alpha: 0.5), strokeWidth: 1),
);

FlTitlesData _titles(
  BuildContext context,
  List<String> labels, {
  bool numericX = false,
}) {
  final theme = Theme.of(context);
  final labelStyle = theme.textTheme.labelSmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  );
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 36,
        getTitlesWidget: (value, meta) =>
            Text(meta.formattedValue, style: labelStyle),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 24,
        getTitlesWidget: (value, meta) => numericX
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(meta.formattedValue, style: labelStyle),
              )
            : _bottomTitle(context, labels, value),
      ),
    ),
  );
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.data});

  final _ChartData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupCount = data.datasets
        .map((s) => s.points.length)
        .fold(0, (a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        maxY: _maxY(data) * 1.1,
        gridData: _grid(theme),
        borderData: FlBorderData(show: false),
        titlesData: _titles(context, data.labels),
        barGroups: [
          for (var g = 0; g < groupCount; g++)
            BarChartGroupData(
              x: g,
              barRods: [
                for (var d = 0; d < data.datasets.length; d++)
                  if (g < data.datasets[d].points.length)
                    BarChartRodData(
                      toY: data.datasets[d].points[g].$2,
                      color: data.datasets[d].sliceColors != null
                          ? _pointColor(data.datasets[d], d, g)
                          : _datasetColor(data.datasets[d], d),
                      width: (18 / data.datasets.length).clamp(4, 18),
                      borderRadius: BorderRadius.circular(2),
                    ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.data});

  final _ChartData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LineChart(
      LineChartData(
        gridData: _grid(theme),
        borderData: FlBorderData(show: false),
        titlesData: _titles(context, data.labels),
        lineBarsData: [
          for (var d = 0; d < data.datasets.length; d++)
            LineChartBarData(
              spots: [
                for (final (x, y) in data.datasets[d].points) FlSpot(x, y),
              ],
              color: _datasetColor(data.datasets[d], d),
              barWidth: 2,
              isCurved: false,
              dotData: FlDotData(show: data.datasets[d].points.length <= 20),
            ),
        ],
      ),
    );
  }
}

class _PieChart extends StatelessWidget {
  const _PieChart({required this.data});

  final _ChartData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Chart.js pie: slices come from the first dataset; per-slice colors from
    // its backgroundColor array.
    final set = data.datasets.first;
    final total = set.points.fold(0.0, (sum, p) => sum + p.$2);
    if (total <= 0) return const SizedBox.shrink();
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 0,
        sections: [
          for (var i = 0; i < set.points.length; i++)
            PieChartSectionData(
              value: set.points[i].$2,
              color: _pointColor(set, 0, i),
              radius: 100,
              title:
                  '${(set.points[i].$2 / total * 100).toStringAsFixed(0)}%',
              titleStyle: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _ScatterChart extends StatelessWidget {
  const _ScatterChart({required this.data});

  final _ChartData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ScatterChart(
      ScatterChartData(
        gridData: _grid(theme),
        borderData: FlBorderData(show: false),
        titlesData: _titles(context, data.labels, numericX: true),
        scatterSpots: [
          for (var d = 0; d < data.datasets.length; d++)
            for (final (x, y) in data.datasets[d].points)
              ScatterSpot(
                x,
                y,
                dotPainter: FlDotCirclePainter(
                  radius: 4,
                  color: _datasetColor(data.datasets[d], d),
                ),
              ),
        ],
      ),
    );
  }
}

/// The dataset legend Chart.js shows by default: colored dot + label per
/// dataset (per slice label for pie).
class _Legend extends StatelessWidget {
  const _Legend({required this.data, required this.chartType});

  final _ChartData data;
  final ChartType chartType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = <(Color, String)>[];
    if (chartType == ChartType.pie) {
      final set = data.datasets.first;
      for (var i = 0; i < set.points.length; i++) {
        entries.add((
          _pointColor(set, 0, i),
          i < data.labels.length ? data.labels[i] : '${set.points[i].$2}',
        ));
      }
    } else {
      for (var d = 0; d < data.datasets.length; d++) {
        entries.add((_datasetColor(data.datasets[d], d), data.datasets[d].label));
      }
    }
    if (entries.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final (color, label) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
