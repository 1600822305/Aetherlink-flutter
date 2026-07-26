// chart 元素：原生 OOXML 图表（<p:graphicFrame> 引用 c:chartSpace 部件）。
part of 'deck_document.dart';

/// Chart kinds the writer maps to native OOXML chart parts（9 种原生，
/// PowerPoint 可改数据重算）.
enum DeckChartKind {
  bar,
  line,
  pie,
  doughnut,
  area,
  scatter,
  stackedBar,
  horizontalBar,
  radar;

  static DeckChartKind parse(String? raw, String where) => switch (raw) {
    'bar' => DeckChartKind.bar,
    'line' => DeckChartKind.line,
    'pie' => DeckChartKind.pie,
    'doughnut' => DeckChartKind.doughnut,
    'area' => DeckChartKind.area,
    'scatter' => DeckChartKind.scatter,
    'stackedBar' => DeckChartKind.stackedBar,
    'horizontalBar' => DeckChartKind.horizontalBar,
    'radar' => DeckChartKind.radar,
    _ => throw DeckParseException(
      '$where 的 chart 必须是 bar/line/pie/doughnut/area/scatter/'
      'stackedBar/horizontalBar/radar：收到 "$raw"',
    ),
  };
}

/// One data series of a chart: a name plus one value per category.
class DeckChartSeries {
  const DeckChartSeries({required this.name, required this.values, this.color});

  final String name;
  final List<double> values;

  /// Series color; null = writer's default palette.
  final DeckColor? color;
}

/// A native chart (`<p:graphicFrame>` referencing a `c:chartSpace` part) —
/// editable data/series in PowerPoint, never a rendered image.
class DeckChartElement extends DeckElement {
  const DeckChartElement({
    required super.frame,
    required this.kind,
    required this.categories,
    required this.series,
    this.title,
    this.palette,
    this.textColor,
  });

  factory DeckChartElement.fromJson(
    Map<String, Object?> json,
    String where, {
    DeckStyle? style,
  }) {
    // 别名容错：chartType 等价于 chart。
    final kind = DeckChartKind.parse(
      (json['chart'] ?? json['chartType']) as String?,
      where,
    );
    final rawCats = json['categories'];
    if (rawCats is! List ||
        rawCats.isEmpty ||
        rawCats.any((c) => c is! String)) {
      throw DeckParseException('$where 缺少非空字符串数组 "categories"');
    }
    final categories = rawCats.cast<String>();
    final rawSeries = json['series'];
    if (rawSeries is! List || rawSeries.isEmpty) {
      throw DeckParseException('$where 缺少非空数组 "series"');
    }
    if ((kind == DeckChartKind.pie || kind == DeckChartKind.doughnut) &&
        rawSeries.length > 1) {
      throw DeckParseException('$where 饼图/环形图只支持 1 个 series');
    }
    if (kind == DeckChartKind.radar && categories.length < 3) {
      throw DeckParseException('$where 雷达图至少需要 3 个 categories（维度）');
    }
    final series = <DeckChartSeries>[];
    for (final (i, rawSer) in rawSeries.indexed) {
      final serWhere = '$where.series[$i]';
      final map = _asMap(rawSer, serWhere);
      final name = map['name'];
      if (name is! String || name.isEmpty) {
        throw DeckParseException('$serWhere 缺少非空字符串 "name"');
      }
      final rawValues = map['values'];
      if (rawValues is! List || rawValues.any((v) => v is! num)) {
        throw DeckParseException('$serWhere 缺少数值数组 "values"');
      }
      if (rawValues.length != categories.length) {
        throw DeckParseException(
          '$serWhere 的 values 长度（${rawValues.length}）必须等于 '
          'categories 长度（${categories.length}）',
        );
      }
      series.add(
        DeckChartSeries(
          name: name,
          values: [for (final v in rawValues) (v as num).toDouble()],
          color: map['color'] == null
              ? null
              : DeckColor(map['color'] as String),
        ),
      );
    }
    return DeckChartElement(
      frame: DeckFrame.fromJson(json, where),
      kind: kind,
      categories: categories,
      series: series,
      title: json['title'] as String?,
      palette: style?.accents,
      textColor: style?.textPrimary,
    );
  }

  final DeckChartKind kind;
  final List<String> categories;
  final List<DeckChartSeries> series;

  /// Optional chart title shown above the plot area.
  final String? title;

  /// Style-derived default series palette; null = writer default.
  final List<DeckColor>? palette;

  /// Style-derived axis/legend/title text color; null = Office default.
  final DeckColor? textColor;
}
