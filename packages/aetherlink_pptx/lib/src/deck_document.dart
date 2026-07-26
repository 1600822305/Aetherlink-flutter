import 'dart:convert';
import 'dart:typed_data';

import 'deck_layout_engine.dart';
import 'deck_style.dart';

/// Thrown when a deck.json source is structurally invalid. [message] is a
/// model-facing, actionable description (which field, what was expected).
/// 解析器按元素/幻灯片批量收集错误（像编译器），[messages] 是全部错误；
/// [message] 把它们拼成一段，方便单条展示。
class DeckParseException implements Exception {
  DeckParseException(String message) : messages = [message];

  DeckParseException.all(this.messages)
    : assert(messages.isNotEmpty, 'messages 不能为空');

  final List<String> messages;

  String get message => messages.length == 1
      ? messages.first
      : '发现 ${messages.length} 处问题：\n${[for (final m in messages) '- $m'].join('\n')}';

  @override
  String toString() => 'DeckParseException: $message';
}

/// Slide canvas presets. Sizes in inches; EMU = inches × 914400.
enum DeckLayout {
  layout16x9(12192000, 6858000),
  layout4x3(9144000, 6858000);

  const DeckLayout(this.widthEmu, this.heightEmu);

  final int widthEmu;
  final int heightEmu;

  double get widthInches => widthEmu / 914400;
  double get heightInches => heightEmu / 914400;

  static DeckLayout parse(String? raw) => switch (raw) {
    null || '16x9' || '16:9' => DeckLayout.layout16x9,
    '4x3' || '4:3' => DeckLayout.layout4x3,
    _ => throw DeckParseException('未知 layout: "$raw"（支持 16x9 / 4x3）'),
  };
}

/// A validated 6-hex RGB color (`RRGGBB`, no `#`, no alpha). Transparency is
/// a separate field on the owning element — never encoded in the hex.
extension type const DeckColor._(String hex) {
  factory DeckColor(String raw) {
    final v = raw.startsWith('#') ? raw.substring(1) : raw;
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(v)) {
      throw DeckParseException(
        '颜色必须是 6 位 hex（如 "1A73E8"，不带 # 不带 alpha）：收到 "$raw"',
      );
    }
    return DeckColor._(v.toUpperCase());
  }

  /// Trusted compile-time constructor for built-in style palettes; the hex
  /// must already be 6-digit uppercase.
  const DeckColor.raw(String hex) : this._(hex);

  String get value => hex;
}

/// Common geometry: position/size in inches from the slide's top-left.
class DeckFrame {
  const DeckFrame({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  factory DeckFrame.fromJson(Map<String, Object?> json, String where) {
    double req(String key) {
      final v = json[key];
      if (v is num) return v.toDouble();
      throw DeckParseException('$where 缺少数值字段 "$key"（单位英寸）');
    }

    final frame = DeckFrame(x: req('x'), y: req('y'), w: req('w'), h: req('h'));
    if (frame.w < 0 || frame.h < 0) {
      throw DeckParseException('$where 的 w/h 不能为负数');
    }
    return frame;
  }

  final double x;
  final double y;
  final double w;
  final double h;
}

/// A styled text run.
class DeckTextRun {
  const DeckTextRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.size,
    this.color,
    this.font,
  });

  factory DeckTextRun.fromJson(
    Map<String, Object?> json,
    String where, {
    DeckStyle? style,
  }) {
    final text = json['text'];
    if (text is! String) {
      throw DeckParseException('$where 的 run 缺少字符串字段 "text"');
    }
    // 别名容错：fontSize 是 LLM 最自然的写法，等价于 size。
    final size = json['size'] ?? json['fontSize'];
    if (size != null && (size is! num || size <= 0)) {
      throw DeckParseException('$where 的 run.size 必须是正数（单位 pt）');
    }
    return DeckTextRun(
      text: text,
      bold: json['bold'] == true,
      italic: json['italic'] == true,
      size: (size as num?)?.toDouble(),
      // 风格推导：省略颜色/字体时用风格的正文色与字体栈。
      color: json['color'] == null
          ? style?.textPrimary
          : DeckColor(json['color'] as String),
      font: (json['font'] as String?) ?? style?.bodyFont,
    );
  }

  final String text;
  final bool bold;
  final bool italic;

  /// Font size in points.
  final double? size;
  final DeckColor? color;
  final String? font;
}

/// A paragraph: runs plus paragraph-level bullet/align/indent.
class DeckParagraph {
  const DeckParagraph({
    required this.runs,
    this.bullet = false,
    this.indentLevel = 0,
    this.align,
  });

  factory DeckParagraph.fromJson(
    Map<String, Object?> json,
    String where, {
    DeckStyle? style,
  }) {
    final rawRuns = json['runs'];
    if (rawRuns is! List || rawRuns.isEmpty) {
      throw DeckParseException('$where 的段落缺少非空数组 "runs"');
    }
    final align = json['align'] as String?;
    if (align != null && !const {'left', 'center', 'right'}.contains(align)) {
      throw DeckParseException('$where 的段落 align 只支持 left/center/right');
    }
    final indent = (json['indentLevel'] as num?)?.toInt() ?? 0;
    if (indent < 0 || indent > 8) {
      throw DeckParseException('$where 的段落 indentLevel 必须在 0-8 之间');
    }
    return DeckParagraph(
      runs: [
        for (final (i, r) in rawRuns.indexed)
          DeckTextRun.fromJson(
            _asMap(r, '$where.runs[$i]'),
            '$where.runs[$i]',
            style: style,
          ),
      ],
      bullet: json['bullet'] == true,
      indentLevel: indent,
      align: align,
    );
  }

  final List<DeckTextRun> runs;
  final bool bullet;
  final int indentLevel;

  /// left / center / right; null = left.
  final String? align;

  String get plainText => runs.map((r) => r.text).join();
}

/// Element variants a slide can carry.
sealed class DeckElement {
  const DeckElement({required this.frame});

  final DeckFrame frame;

  static DeckElement fromJson(
    Map<String, Object?> json,
    String where, {
    DeckStyle? style,
  }) {
    final type = json['type'];
    return switch (type) {
      'text' => DeckTextElement.fromJson(json, where, style: style),
      'shape' => DeckShapeElement.fromJson(json, where),
      'image' => DeckImageElement.fromJson(json, where),
      'table' => DeckTableElement.fromJson(json, where, style: style),
      'chart' => DeckChartElement.fromJson(json, where, style: style),
      _ => throw DeckParseException(
        '$where 的 type 必须是 text/shape/image/table/chart/infographic：收到 "$type"',
      ),
    };
  }
}

/// A native text box (`<p:sp>` with a `<p:txBody>`).
class DeckTextElement extends DeckElement {
  const DeckTextElement({
    required super.frame,
    required this.paragraphs,
    this.valign,
    this.fill,
    this.lineSpacing,
  });

  factory DeckTextElement.fromJson(
    Map<String, Object?> json,
    String where, {
    DeckStyle? style,
  }) {
    var rawParas = json['paragraphs'];
    // 简写容错：顶层 "text" 字符串（可配 size/fontSize/bold/color/font/align）
    // 自动展开成 paragraphs/runs —— 这是 LLM 最自然的写法。
    if (rawParas == null && json['text'] is String) {
      final runProps = <String, Object?>{
        'size': ?(json['size'] ?? json['fontSize']),
        if (json['bold'] == true) 'bold': true,
        if (json['color'] is String) 'color': json['color'],
        if (json['font'] is String) 'font': json['font'],
      };
      final align = json['align'] is String ? json['align'] : null;
      rawParas = [
        for (final line in (json['text'] as String).split('\n'))
          {
            'align': ?align,
            'runs': [
              {'text': line, ...runProps},
            ],
          },
      ];
    }
    if (rawParas is! List || rawParas.isEmpty) {
      throw DeckParseException(
        '$where 缺少非空数组 "paragraphs"（或简写字符串 "text"）',
      );
    }
    final valign = json['valign'] as String?;
    if (valign != null && !const {'top', 'middle', 'bottom'}.contains(valign)) {
      throw DeckParseException('$where 的 valign 只支持 top/middle/bottom');
    }
    final spacing = json['lineSpacing'];
    if (spacing != null && (spacing is! num || spacing <= 0)) {
      throw DeckParseException('$where 的 lineSpacing 必须是正数（倍数，如 1.2）');
    }
    return DeckTextElement(
      frame: DeckFrame.fromJson(json, where),
      paragraphs: [
        for (final (i, p) in rawParas.indexed)
          DeckParagraph.fromJson(
            _asMap(p, '$where.paragraphs[$i]'),
            '$where.paragraphs[$i]',
            style: style,
          ),
      ],
      valign: valign,
      fill: json['fill'] == null ? null : DeckColor(json['fill'] as String),
      lineSpacing: (spacing as num?)?.toDouble(),
    );
  }

  final List<DeckParagraph> paragraphs;

  /// top / middle / bottom; null = top.
  final String? valign;

  /// Optional box background fill.
  final DeckColor? fill;

  /// Line spacing multiple (e.g. 1.2); null = single.
  final double? lineSpacing;
}

/// Preset shape kinds the writer maps to OOXML preset geometries.
enum DeckShapeKind {
  rect('rect'),
  roundRect('roundRect'),
  ellipse('ellipse'),
  line('line'),
  pie('pie');

  const DeckShapeKind(this.preset);

  /// The `<a:prstGeom prst="...">` value.
  final String preset;

  static DeckShapeKind parse(String? raw, String where) => switch (raw) {
    'rect' => DeckShapeKind.rect,
    'roundRect' => DeckShapeKind.roundRect,
    'ellipse' => DeckShapeKind.ellipse,
    'line' => DeckShapeKind.line,
    'pie' => DeckShapeKind.pie,
    _ => throw DeckParseException(
      '$where 的 shape 必须是 rect/roundRect/ellipse/line/pie：收到 "$raw"',
    ),
  };
}

/// A native shape (`<p:sp>` with a preset geometry).
class DeckShapeElement extends DeckElement {
  const DeckShapeElement({
    required super.frame,
    required this.kind,
    this.fill,
    this.fillTransparency = 0,
    this.lineColor,
    this.lineWidth,
    this.radius,
    this.angleStart,
    this.angleEnd,
  });

  factory DeckShapeElement.fromJson(Map<String, Object?> json, String where) {
    final transparency = (json['fillTransparency'] as num?)?.toInt() ?? 0;
    if (transparency < 0 || transparency > 100) {
      throw DeckParseException('$where 的 fillTransparency 必须在 0-100 之间');
    }
    final lineWidth = json['lineWidth'];
    if (lineWidth != null && (lineWidth is! num || lineWidth <= 0)) {
      throw DeckParseException('$where 的 lineWidth 必须是正数（单位 pt）');
    }
    final radius = json['radius'];
    if (radius != null && (radius is! num || radius < 0 || radius > 0.5)) {
      throw DeckParseException('$where 的 radius 必须在 0-0.5 之间（相对短边比例）');
    }
    final kind = DeckShapeKind.parse(json['shape'] as String?, where);
    final angleStart = json['angleStart'];
    final angleEnd = json['angleEnd'];
    if (kind == DeckShapeKind.pie && (angleStart is! num || angleEnd is! num)) {
      throw DeckParseException(
        '$where 的 pie 形状需要数值 "angleStart"/"angleEnd"（角度，0=3 点钟方向顺时针）',
      );
    }
    return DeckShapeElement(
      frame: DeckFrame.fromJson(json, where),
      kind: kind,
      angleStart: (angleStart as num?)?.toDouble(),
      angleEnd: (angleEnd as num?)?.toDouble(),
      fill: json['fill'] == null ? null : DeckColor(json['fill'] as String),
      fillTransparency: transparency,
      lineColor: json['lineColor'] == null
          ? null
          : DeckColor(json['lineColor'] as String),
      lineWidth: (lineWidth as num?)?.toDouble(),
      radius: (radius as num?)?.toDouble(),
    );
  }

  final DeckShapeKind kind;
  final DeckColor? fill;

  /// 0-100; applied as `<a:alpha>` on the fill, never baked into the hex.
  final int fillTransparency;
  final DeckColor? lineColor;

  /// Outline width in points.
  final double? lineWidth;

  /// Corner radius for [DeckShapeKind.roundRect], as a 0-0.5 fraction of the
  /// shorter side.
  final double? radius;

  /// Wedge angles (degrees, 0 = 3 o'clock, clockwise) for [DeckShapeKind.pie].
  final double? angleStart;
  final double? angleEnd;
}

/// An embedded picture (`<p:pic>`), sourced from base64 PNG/JPEG data or a
/// not-yet-resolved `src` reference (URL / workspace path) — 工具层在导出前
/// 把 src 展开为 data；预览对未展开的 src 显示占位。
class DeckImageElement extends DeckElement {
  const DeckImageElement({required super.frame, required this.bytes, this.src});

  factory DeckImageElement.fromJson(Map<String, Object?> json, String where) {
    final data = json['data'];
    final src = json['src'];
    if (data is! String || data.isEmpty) {
      if (src is String && src.trim().isNotEmpty) {
        return DeckImageElement(
          frame: DeckFrame.fromJson(json, where),
          bytes: Uint8List(0),
          src: src.trim(),
        );
      }
      throw DeckParseException(
        '$where 缺少 "data"（base64 编码的 PNG/JPEG）或 "src"（图片 URL / 工作区路径）',
      );
    }
    final Uint8List bytes;
    try {
      bytes = base64Decode(data.replaceAll(RegExp(r'\s'), ''));
    } on FormatException {
      throw DeckParseException('$where 的 data 不是合法 base64');
    }
    if (detectImageFormat(bytes) == null) {
      throw DeckParseException('$where 的图片数据不是 PNG 或 JPEG');
    }
    return DeckImageElement(
      frame: DeckFrame.fromJson(json, where),
      bytes: bytes,
    );
  }

  final Uint8List bytes;

  /// Unresolved image reference (URL or workspace path); null once embedded.
  final String? src;

  bool get isResolved => bytes.isNotEmpty;
}

/// A single table cell.
class DeckTableCell {
  const DeckTableCell({required this.runs, this.fill, this.align});

  final List<DeckTextRun> runs;
  final DeckColor? fill;
  final String? align;

  String get plainText => runs.map((r) => r.text).join();
}

/// A native table (`<a:graphicFrame>` wrapping `<a:tbl>`).
class DeckTableElement extends DeckElement {
  const DeckTableElement({
    required super.frame,
    required this.rows,
    this.colWidths,
    this.headerFill,
    this.headerColor,
    this.borderColor,
  });

  factory DeckTableElement.fromJson(
    Map<String, Object?> json,
    String where, {
    DeckStyle? style,
  }) {
    final rawRows = json['rows'];
    if (rawRows is! List || rawRows.isEmpty) {
      throw DeckParseException('$where 缺少非空数组 "rows"');
    }
    final rows = <List<DeckTableCell>>[];
    int? columnCount;
    for (final (r, rawRow) in rawRows.indexed) {
      if (rawRow is! List || rawRow.isEmpty) {
        throw DeckParseException('$where.rows[$r] 必须是非空数组');
      }
      columnCount ??= rawRow.length;
      if (rawRow.length != columnCount) {
        throw DeckParseException('$where 每行的列数必须一致');
      }
      final cells = <DeckTableCell>[];
      for (final (c, rawCell) in rawRow.indexed) {
        final cellWhere = '$where.rows[$r][$c]';
        // 风格推导：省略颜色/字体的单元格文字用风格正文色与字体栈，
        // 与 DeckTextElement 一致（否则深色风格下表格文字落回默认黑色）。
        if (rawCell is String) {
          cells.add(
            DeckTableCell(
              runs: [
                DeckTextRun(
                  text: rawCell,
                  color: style?.textPrimary,
                  font: style?.bodyFont,
                ),
              ],
            ),
          );
          continue;
        }
        final map = _asMap(rawCell, cellWhere);
        final align = map['align'] as String?;
        if (align != null &&
            !const {'left', 'center', 'right'}.contains(align)) {
          throw DeckParseException('$cellWhere 的 align 只支持 left/center/right');
        }
        final rawRuns = map['runs'];
        cells.add(
          DeckTableCell(
            runs: rawRuns is List
                ? [
                    for (final (i, run) in rawRuns.indexed)
                      DeckTextRun.fromJson(
                        _asMap(run, '$cellWhere.runs[$i]'),
                        '$cellWhere.runs[$i]',
                        style: style,
                      ),
                  ]
                : [
                    DeckTextRun(
                      text: (map['text'] ?? '').toString(),
                      color: style?.textPrimary,
                      font: style?.bodyFont,
                    ),
                  ],
            fill: map['fill'] == null ? null : DeckColor(map['fill'] as String),
            align: align,
          ),
        );
      }
      rows.add(cells);
    }
    final rawColW = json['colWidths'];
    List<double>? colWidths;
    if (rawColW != null) {
      if (rawColW is! List ||
          rawColW.length != columnCount ||
          rawColW.any((w) => w is! num || w <= 0)) {
        throw DeckParseException('$where 的 colWidths 必须是与列数等长的正数数组（单位英寸）');
      }
      colWidths = [for (final w in rawColW) (w as num).toDouble()];
    }
    return DeckTableElement(
      frame: DeckFrame.fromJson(json, where),
      rows: rows,
      colWidths: colWidths,
      headerFill: json['headerFill'] == null
          ? null
          : DeckColor(json['headerFill'] as String),
      headerColor: json['headerColor'] == null
          ? null
          : DeckColor(json['headerColor'] as String),
      borderColor: json['borderColor'] == null
          ? null
          : DeckColor(json['borderColor'] as String),
    );
  }

  final List<List<DeckTableCell>> rows;

  /// Column widths in inches; null = equal split of the frame width.
  final List<double>? colWidths;
  final DeckColor? headerFill;
  final DeckColor? headerColor;
  final DeckColor? borderColor;

  int get columnCount => rows.first.length;
}

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

/// One slide: background + z-ordered elements + optional speaker notes.
class DeckSlide {
  const DeckSlide({
    required this.elements,
    this.background,
    this.notes,
    this.layoutType,
    this.layoutCardCount,
    this.layoutCardTypeCount,
  });

  factory DeckSlide.fromJson(
    Map<String, Object?> json,
    String where, {
    DeckLayout canvas = DeckLayout.layout16x9,
    DeckStyle? style,
  }) {
    final rawElements = json['elements'];
    final rawLayout = json['layout'];
    if (rawElements is! List && rawLayout == null) {
      throw DeckParseException('$where 缺少数组 "elements"（或布局声明 "layout"）');
    }
    final rawNotes = json['notes'];
    if (rawNotes != null && rawNotes is! String) {
      throw DeckParseException('$where 的 "notes" 必须是字符串（演讲者备注）');
    }
    final notes = (rawNotes as String?)?.trim();
    final elements = <DeckElement>[];
    String? layoutType;
    int? layoutCardCount;
    int? layoutCardTypeCount;
    // 布局引擎：页级 layout 声明编译成绝对定位元素；仍可与 elements 混用
    // （layout 元素在前，elements 叠加在后）。
    // 批量收集：一个元素解析失败不中断整页，攒齐所有错误一次性抛出，
    // 让 agent 一轮就能修完（编译器风格）。
    final errors = <String>[];
    if (rawLayout != null) {
      try {
        final layoutMap = _asMap(rawLayout, '$where.layout');
        elements.addAll(buildLayoutElements(layoutMap, canvas, style, where));
        // 保留布局元信息供 QA 的失败模式规则（节奏克隆/支撑坍缩）使用。
        layoutType = layoutMap['type'] as String?;
        final cards = layoutMap['cards'];
        if (cards is List) {
          layoutCardCount = cards.length;
          layoutCardTypeCount = {
            for (final c in cards)
              if (c is Map) (c['type'] as String?) ?? 'text',
          }.length;
        }
      } on DeckParseException catch (e) {
        errors.addAll(e.messages);
      }
    }
    if (rawElements is List) {
      for (final (i, e) in rawElements.indexed) {
        try {
          final map = _asMap(e, '$where.elements[$i]');
          if (map['type'] == 'infographic') {
            elements.addAll(
              buildInfographicElements(map, style, '$where.elements[$i]'),
            );
          } else {
            elements.add(
              DeckElement.fromJson(map, '$where.elements[$i]', style: style),
            );
          }
        } on DeckParseException catch (ex) {
          errors.addAll(ex.messages);
        }
      }
    }
    if (errors.isNotEmpty) throw DeckParseException.all(errors);
    return DeckSlide(
      background: json['background'] == null
          ? style?.background
          : DeckColor(json['background'] as String),
      notes: notes == null || notes.isEmpty ? null : notes,
      elements: elements,
      layoutType: layoutType,
      layoutCardCount: layoutCardCount,
      layoutCardTypeCount: layoutCardTypeCount,
    );
  }

  final DeckColor? background;
  final List<DeckElement> elements;

  /// Speaker notes, written into the slide's `notesSlide` part on export.
  final String? notes;

  /// Layout metadata (when the slide used a page-level layout declaration),
  /// consumed by the failure-mode QA rules; null for absolute-positioned pages.
  final String? layoutType;
  final int? layoutCardCount;
  final int? layoutCardTypeCount;
}

/// The whole deck source — the structured JSON the agent produces and both
/// the PPTX writer and the HTML preview renderer consume.
class DeckDocument {
  const DeckDocument({
    required this.layout,
    required this.slides,
    this.title,
    this.style,
  });

  /// Parses and validates a deck.json object (or JSON string via
  /// [DeckDocument.parse]). Throws [DeckParseException] with an actionable
  /// message on any structural problem.
  factory DeckDocument.fromJson(Map<String, Object?> json) {
    final rawSlides = json['slides'];
    if (rawSlides is! List || rawSlides.isEmpty) {
      throw DeckParseException('deck 缺少非空数组 "slides"');
    }
    final layout = DeckLayout.parse(json['layout'] as String?);
    final style = DeckStyle.resolve(json['style'], 'deck.style');
    // 批量收集：坏页不中断整个 deck 的解析，所有页的错误一次性返回。
    final slides = <DeckSlide>[];
    final errors = <String>[];
    for (final (i, s) in rawSlides.indexed) {
      try {
        slides.add(
          DeckSlide.fromJson(
            _asMap(s, 'slides[$i]'),
            'slides[$i]',
            canvas: layout,
            style: style,
          ),
        );
      } on DeckParseException catch (e) {
        errors.addAll(e.messages);
      }
    }
    if (errors.isNotEmpty) throw DeckParseException.all(errors);
    return DeckDocument(
      layout: layout,
      style: style,
      title: json['title'] as String?,
      slides: slides,
    );
  }

  /// Parses a raw JSON string.
  factory DeckDocument.parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw DeckParseException('deck JSON 解析失败: ${e.message}');
    }
    return DeckDocument.fromJson(_asMap(decoded, 'deck'));
  }

  final DeckLayout layout;
  final String? title;
  final List<DeckSlide> slides;

  /// Deck-wide visual style（内置 id 或内联对象）; null = 无风格推导.
  final DeckStyle? style;
}

Map<String, Object?> _asMap(Object? value, String where) {
  if (value is Map) return value.cast<String, Object?>();
  throw DeckParseException('$where 必须是 JSON 对象');
}

/// Sniffs [bytes] for a PNG/JPEG header. Returns `'png'`, `'jpeg'`, or null.
String? detectImageFormat(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'jpeg';
  }
  return null;
}
