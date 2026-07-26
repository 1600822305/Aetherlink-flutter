import 'dart:convert';
import 'dart:math';

import 'deck_document.dart';

/// Renders [deck] as a self-contained HTML preview: one absolutely-positioned
/// page per slide, sized 1280×720 (16:9) or 960×720 (4:3), with the same
/// inch-based coordinates the PPTX writer uses (1 inch = 96 px). The preview
/// and the exported .pptx are driven by the same source, so what the WebView
/// shows is what PowerPoint opens.
String renderDeckHtml(DeckDocument deck) {
  final pageW = (deck.layout.widthInches * 96).round();
  final pageH = (deck.layout.heightInches * 96).round();
  final buf = StringBuffer()
    ..write('<!DOCTYPE html><html><head><meta charset="utf-8">')
    ..write('<meta name="viewport" content="width=$pageW, initial-scale=1">')
    ..write('<title>${_esc(deck.title ?? 'Deck Preview')}</title>')
    ..write('<style>')
    ..write(
      'body{margin:0;background:#333;display:flex;flex-direction:column;'
      'align-items:center;gap:24px;padding:24px 0;'
      "font-family:'Microsoft YaHei','PingFang SC',sans-serif;}",
    )
    ..write(
      '.slide{position:relative;width:${pageW}px;height:${pageH}px;'
      'background:#fff;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,.4);}',
    )
    ..write('.el{position:absolute;box-sizing:border-box;}')
    ..write('table.deck{border-collapse:collapse;width:100%;height:100%;}')
    ..write('table.deck td{padding:2px 6px;vertical-align:middle;}')
    ..write(
      '.notes{width:${pageW}px;box-sizing:border-box;margin-top:-16px;'
      'padding:8px 12px;background:#222;color:#bbb;font-size:13px;'
      'white-space:pre-wrap;}',
    )
    ..write('</style></head><body>');
  for (final slide in deck.slides) {
    final bg = slide.background;
    buf.write(
      '<div class="slide"${bg == null ? '' : ' style="background:#${bg.value}"'}>',
    );
    for (final element in slide.elements) {
      buf.write(switch (element) {
        DeckTextElement() => _textHtml(element),
        DeckShapeElement() => _shapeHtml(element),
        DeckImageElement() => _imageHtml(element),
        DeckTableElement() => _tableHtml(element),
        DeckChartElement() => _chartHtml(element),
      });
    }
    buf.write('</div>');
    if (slide.notes != null) {
      buf.write('<div class="notes">备注：${_esc(slide.notes!)}</div>');
    }
  }
  buf.write('</body></html>');
  return buf.toString();
}

String _esc(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _px(double inches) => '${(inches * 96).toStringAsFixed(1)}px';

String _pos(DeckFrame f) =>
    'left:${_px(f.x)};top:${_px(f.y)};width:${_px(f.w)};height:${_px(f.h)};';

String _runHtml(DeckTextRun run) {
  final style = StringBuffer();
  if (run.bold) style.write('font-weight:bold;');
  if (run.italic) style.write('font-style:italic;');
  if (run.size != null) {
    style.write('font-size:${(run.size! * 96 / 72).toStringAsFixed(1)}px;');
  }
  if (run.color != null) style.write('color:#${run.color!.value};');
  if (run.font != null) style.write("font-family:'${_esc(run.font!)}';");
  return '<span style="$style">${_esc(run.text)}</span>';
}

String _textHtml(DeckTextElement element) {
  final style = StringBuffer(_pos(element.frame));
  if (element.fill != null) style.write('background:#${element.fill!.value};');
  style.write(switch (element.valign) {
    'middle' => 'display:flex;flex-direction:column;justify-content:center;',
    'bottom' => 'display:flex;flex-direction:column;justify-content:flex-end;',
    _ => '',
  });
  final buf = StringBuffer('<div class="el" style="$style">');
  for (final paragraph in element.paragraphs) {
    final pStyle = StringBuffer('margin:0;');
    if (paragraph.align != null) {
      pStyle.write('text-align:${paragraph.align};');
    }
    if (element.lineSpacing != null) {
      pStyle.write('line-height:${element.lineSpacing};');
    }
    if (paragraph.bullet) {
      pStyle.write('padding-left:${16 + paragraph.indentLevel * 24}px;');
    }
    final bullet = paragraph.bullet ? '• ' : '';
    buf.write(
      '<p style="$pStyle">$bullet${paragraph.runs.map(_runHtml).join()}</p>',
    );
  }
  buf.write('</div>');
  return buf.toString();
}

String _shapeHtml(DeckShapeElement element) {
  final style = StringBuffer(_pos(element.frame));
  if (element.fill != null) {
    if (element.fillTransparency > 0) {
      final alpha = ((100 - element.fillTransparency) * 255 / 100).round();
      style.write(
        'background:#${element.fill!.value}'
        '${alpha.toRadixString(16).padLeft(2, '0')};',
      );
    } else {
      style.write('background:#${element.fill!.value};');
    }
  }
  switch (element.kind) {
    case DeckShapeKind.roundRect:
      final shorter = element.frame.w < element.frame.h
          ? element.frame.w
          : element.frame.h;
      final radius = (element.radius ?? 0.1667) * shorter * 96;
      style.write('border-radius:${radius.toStringAsFixed(1)}px;');
    case DeckShapeKind.ellipse:
      style.write('border-radius:50%;');
    case DeckShapeKind.line:
      final color = element.lineColor?.value ?? '000000';
      final width = element.lineWidth ?? 1;
      style.write(
        'border-top:${(width * 96 / 72).toStringAsFixed(1)}px solid #$color;'
        'height:0;',
      );
    case DeckShapeKind.pie:
      return _pieShapeHtml(element);
    case DeckShapeKind.rect:
      break;
  }
  if (element.kind != DeckShapeKind.line && element.lineColor != null) {
    final width = element.lineWidth ?? 1;
    style.write(
      'border:${(width * 96 / 72).toStringAsFixed(1)}px solid '
      '#${element.lineColor!.value};',
    );
  }
  return '<div class="el" style="$style"></div>';
}

/// Renders a pie-wedge shape as an inline SVG path（角度语义对齐 OOXML：
/// 0 = 3 点钟方向，顺时针）.
String _pieShapeHtml(DeckShapeElement element) {
  final w = element.frame.w * 96;
  final h = element.frame.h * 96;
  final start = (element.angleStart ?? 0) * pi / 180;
  final end = (element.angleEnd ?? 270) * pi / 180;
  final cx = w / 2;
  final cy = h / 2;
  final rx = w / 2;
  final ry = h / 2;
  var sweep = end - start;
  if (sweep <= 0) sweep += 2 * pi;
  final x1 = cx + rx * cos(start);
  final y1 = cy + ry * sin(start);
  final x2 = cx + rx * cos(start + sweep);
  final y2 = cy + ry * sin(start + sweep);
  final largeArc = sweep > pi ? 1 : 0;
  final fill = element.fill == null ? 'none' : '#${element.fill!.value}';
  final opacity = element.fillTransparency > 0
      ? ' fill-opacity="${((100 - element.fillTransparency) / 100).toStringAsFixed(2)}"'
      : '';
  return '<div class="el" style="${_pos(element.frame)}">'
      '<svg width="100%" height="100%" viewBox="0 0 ${w.toStringAsFixed(0)} ${h.toStringAsFixed(0)}">'
      '<path d="M${cx.toStringAsFixed(1)},${cy.toStringAsFixed(1)} '
      'L${x1.toStringAsFixed(1)},${y1.toStringAsFixed(1)} '
      'A${rx.toStringAsFixed(1)},${ry.toStringAsFixed(1)} 0 $largeArc 1 '
      '${x2.toStringAsFixed(1)},${y2.toStringAsFixed(1)} Z" fill="$fill"$opacity/>'
      '</svg></div>';
}

String _imageHtml(DeckImageElement element) {
  if (!element.isResolved) {
    return '<div class="el" style="${_pos(element.frame)}display:flex;'
        'align-items:center;justify-content:center;border:1px dashed #999;'
        'color:#999;font-size:11px;">图片（src 未展开）</div>';
  }
  final format = detectImageFormat(element.bytes)!;
  final data = base64Encode(element.bytes);
  return '<img class="el" style="${_pos(element.frame)}object-fit:fill;" '
      'src="data:image/$format;base64,$data">';
}

/// Office-default accent palette — mirrors the PPTX writer's chart palette.
const List<String> _chartPalette = [
  '4472C4',
  'ED7D31',
  'A5A5A5',
  'FFC000',
  '5B9BD5',
  '70AD47',
];

String _seriesColor(
  DeckChartElement element,
  DeckChartSeries series,
  int index,
) => series.color?.value ?? _catColor(element, index);

String _catColor(DeckChartElement element, int index) {
  final palette = element.palette == null
      ? _chartPalette
      : [for (final c in element.palette!) c.value];
  return palette[index % palette.length];
}

/// Renders the chart as an inline SVG approximation of the native OOXML
/// chart (same data, palette and legend; PowerPoint owns the exact styling).
String _chartHtml(DeckChartElement element) {
  final w = element.frame.w * 96;
  final h = element.frame.h * 96;
  final buf = StringBuffer(
    '<div class="el" style="${_pos(element.frame)}">'
    '<svg width="100%" height="100%" viewBox="0 0 ${w.toStringAsFixed(0)} ${h.toStringAsFixed(0)}">',
  );
  final titleH = element.title == null ? 0.0 : 22.0;
  if (element.title != null) {
    buf.write(
      '<text x="${(w / 2).toStringAsFixed(1)}" y="16" text-anchor="middle" '
      'font-size="14" font-weight="bold">${_esc(element.title!)}</text>',
    );
  }
  final legendH = 18.0;
  final plotX = 30.0;
  final plotY = titleH + 4;
  final plotW = w - plotX - 8;
  final plotH = h - plotY - legendH - 16;
  switch (element.kind) {
    case DeckChartKind.bar:
      buf.write(_barSvg(element, plotX, plotY, plotW, plotH));
    case DeckChartKind.stackedBar:
      buf.write(_stackedBarSvg(element, plotX, plotY, plotW, plotH));
    case DeckChartKind.horizontalBar:
      buf.write(_horizontalBarSvg(element, plotX, plotY, plotW, plotH));
    case DeckChartKind.line:
      buf.write(_lineSvg(element, plotX, plotY, plotW, plotH));
    case DeckChartKind.area:
      buf.write(_lineSvg(element, plotX, plotY, plotW, plotH, area: true));
    case DeckChartKind.scatter:
      buf.write(_scatterSvg(element, plotX, plotY, plotW, plotH));
    case DeckChartKind.radar:
      buf.write(_radarSvg(element, w / 2, plotY + plotH / 2, plotH / 2));
    case DeckChartKind.pie:
      buf.write(_pieSvg(element, w / 2, plotY + plotH / 2, plotH / 2));
    case DeckChartKind.doughnut:
      buf.write(
        _pieSvg(element, w / 2, plotY + plotH / 2, plotH / 2, hole: 0.55),
      );
  }
  // Legend
  var lx = plotX;
  final ly = h - 10;
  final legendEntries =
      element.kind == DeckChartKind.pie ||
          element.kind == DeckChartKind.doughnut
      ? [
          for (final (i, cat) in element.categories.indexed)
            (cat, _catColor(element, i)),
        ]
      : [
          for (final (i, s) in element.series.indexed)
            (s.name, _seriesColor(element, s, i)),
        ];
  for (final (label, color) in legendEntries) {
    buf.write(
      '<rect x="${lx.toStringAsFixed(1)}" y="${(ly - 8).toStringAsFixed(1)}" '
      'width="8" height="8" fill="#$color"/>'
      '<text x="${(lx + 11).toStringAsFixed(1)}" y="${ly.toStringAsFixed(1)}" '
      'font-size="10">${_esc(label)}</text>',
    );
    lx += 22.0 + label.length * 10;
  }
  buf.write('</svg></div>');
  return buf.toString();
}

double _chartMax(DeckChartElement element) {
  var max = 0.0;
  for (final s in element.series) {
    for (final v in s.values) {
      if (v > max) max = v;
    }
  }
  return max <= 0 ? 1 : max;
}

String _barSvg(
  DeckChartElement element,
  double x,
  double y,
  double w,
  double h,
) {
  final max = _chartMax(element);
  final buf = StringBuffer(
    '<line x1="$x" y1="${(y + h).toStringAsFixed(1)}" '
    'x2="${(x + w).toStringAsFixed(1)}" y2="${(y + h).toStringAsFixed(1)}" stroke="#999"/>',
  );
  final catCount = element.categories.length;
  final groupW = w / catCount;
  final barW = groupW * 0.6 / element.series.length;
  for (final (ci, cat) in element.categories.indexed) {
    for (final (si, s) in element.series.indexed) {
      final v = s.values[ci];
      final barH = (v / max) * h;
      final bx = x + ci * groupW + groupW * 0.2 + si * barW;
      buf.write(
        '<rect x="${bx.toStringAsFixed(1)}" y="${(y + h - barH).toStringAsFixed(1)}" '
        'width="${barW.toStringAsFixed(1)}" height="${barH.toStringAsFixed(1)}" '
        'fill="#${_seriesColor(element, s, si)}"/>',
      );
    }
    buf.write(
      '<text x="${(x + ci * groupW + groupW / 2).toStringAsFixed(1)}" '
      'y="${(y + h + 12).toStringAsFixed(1)}" text-anchor="middle" '
      'font-size="10">${_esc(cat)}</text>',
    );
  }
  return buf.toString();
}

String _lineSvg(
  DeckChartElement element,
  double x,
  double y,
  double w,
  double h, {
  bool area = false,
}) {
  final max = _chartMax(element);
  final buf = StringBuffer(
    '<line x1="$x" y1="${(y + h).toStringAsFixed(1)}" '
    'x2="${(x + w).toStringAsFixed(1)}" y2="${(y + h).toStringAsFixed(1)}" stroke="#999"/>',
  );
  final catCount = element.categories.length;
  final stepX = catCount == 1 ? 0.0 : w / (catCount - 1);
  for (final (si, s) in element.series.indexed) {
    final points = [
      for (final (ci, v) in s.values.indexed)
        '${(x + ci * stepX).toStringAsFixed(1)},'
            '${(y + h - v / max * h).toStringAsFixed(1)}',
    ].join(' ');
    if (area) {
      buf.write(
        '<polygon points="${x.toStringAsFixed(1)},${(y + h).toStringAsFixed(1)} '
        '$points ${(x + (catCount - 1) * stepX).toStringAsFixed(1)},${(y + h).toStringAsFixed(1)}" '
        'fill="#${_seriesColor(element, s, si)}" fill-opacity="0.45"/>',
      );
    }
    buf.write(
      '<polyline points="$points" fill="none" '
      'stroke="#${_seriesColor(element, s, si)}" stroke-width="2"/>',
    );
  }
  for (final (ci, cat) in element.categories.indexed) {
    buf.write(
      '<text x="${(x + ci * stepX).toStringAsFixed(1)}" '
      'y="${(y + h + 12).toStringAsFixed(1)}" text-anchor="middle" '
      'font-size="10">${_esc(cat)}</text>',
    );
  }
  return buf.toString();
}

String _pieSvg(
  DeckChartElement element,
  double cx,
  double cy,
  double r, {
  double hole = 0,
}) {
  final values = element.series.first.values;
  final total = values.fold<double>(0, (a, b) => a + (b < 0 ? 0 : b));
  if (total <= 0) return '';
  final buf = StringBuffer();
  if (hole > 0) {
    // 环形图：用描边弧段避免依赖背景色遮挡。
    final ringR = r * (1 + hole) / 2;
    final strokeW = r * (1 - hole);
    var angle = -pi / 2;
    final circumference = 2 * pi * ringR;
    for (final (i, v) in values.indexed) {
      if (v <= 0) continue;
      final frac = v / total;
      buf.write(
        '<circle cx="${cx.toStringAsFixed(1)}" cy="${cy.toStringAsFixed(1)}" '
        'r="${ringR.toStringAsFixed(1)}" fill="none" '
        'stroke="#${_catColor(element, i)}" stroke-width="${strokeW.toStringAsFixed(1)}" '
        'stroke-dasharray="${(frac * circumference).toStringAsFixed(1)} ${circumference.toStringAsFixed(1)}" '
        'transform="rotate(${(angle * 180 / pi).toStringAsFixed(1)} ${cx.toStringAsFixed(1)} ${cy.toStringAsFixed(1)})"/>',
      );
      angle += frac * 2 * pi;
    }
    return buf.toString();
  }
  var angle = -pi / 2;
  for (final (i, v) in values.indexed) {
    if (v <= 0) continue;
    final sweep = v / total * 2 * pi;
    final x1 = cx + r * cos(angle);
    final y1 = cy + r * sin(angle);
    angle += sweep;
    final x2 = cx + r * cos(angle);
    final y2 = cy + r * sin(angle);
    final largeArc = sweep > pi ? 1 : 0;
    buf.write(
      '<path d="M${cx.toStringAsFixed(1)},${cy.toStringAsFixed(1)} '
      'L${x1.toStringAsFixed(1)},${y1.toStringAsFixed(1)} '
      'A${r.toStringAsFixed(1)},${r.toStringAsFixed(1)} 0 $largeArc 1 '
      '${x2.toStringAsFixed(1)},${y2.toStringAsFixed(1)} Z" '
      'fill="#${_catColor(element, i)}"/>',
    );
  }
  return buf.toString();
}

String _stackedBarSvg(
  DeckChartElement element,
  double x,
  double y,
  double w,
  double h,
) {
  // 堆叠最大值 = 各类别系列之和的最大值。
  var max = 0.0;
  for (var ci = 0; ci < element.categories.length; ci++) {
    var sum = 0.0;
    for (final s in element.series) {
      final v = s.values[ci];
      if (v > 0) sum += v;
    }
    if (sum > max) max = sum;
  }
  if (max <= 0) max = 1;
  final buf = StringBuffer(
    '<line x1="$x" y1="${(y + h).toStringAsFixed(1)}" '
    'x2="${(x + w).toStringAsFixed(1)}" y2="${(y + h).toStringAsFixed(1)}" stroke="#999"/>',
  );
  final catCount = element.categories.length;
  final groupW = w / catCount;
  final barW = groupW * 0.55;
  for (final (ci, cat) in element.categories.indexed) {
    var top = y + h;
    final bx = x + ci * groupW + (groupW - barW) / 2;
    for (final (si, s) in element.series.indexed) {
      final v = s.values[ci];
      if (v <= 0) continue;
      final segH = v / max * h;
      top -= segH;
      buf.write(
        '<rect x="${bx.toStringAsFixed(1)}" y="${top.toStringAsFixed(1)}" '
        'width="${barW.toStringAsFixed(1)}" height="${segH.toStringAsFixed(1)}" '
        'fill="#${_seriesColor(element, s, si)}"/>',
      );
    }
    buf.write(
      '<text x="${(x + ci * groupW + groupW / 2).toStringAsFixed(1)}" '
      'y="${(y + h + 12).toStringAsFixed(1)}" text-anchor="middle" '
      'font-size="10">${_esc(cat)}</text>',
    );
  }
  return buf.toString();
}

String _horizontalBarSvg(
  DeckChartElement element,
  double x,
  double y,
  double w,
  double h,
) {
  final max = _chartMax(element);
  const labelW = 52.0;
  final plotX = x + labelW;
  final plotW = w - labelW;
  final buf = StringBuffer(
    '<line x1="$plotX" y1="$y" x2="$plotX" y2="${(y + h).toStringAsFixed(1)}" stroke="#999"/>',
  );
  final catCount = element.categories.length;
  final groupH = h / catCount;
  final barH = groupH * 0.6 / element.series.length;
  for (final (ci, cat) in element.categories.indexed) {
    for (final (si, s) in element.series.indexed) {
      final v = s.values[ci];
      final barLen = (v / max) * plotW;
      final by = y + ci * groupH + groupH * 0.2 + si * barH;
      buf.write(
        '<rect x="${plotX.toStringAsFixed(1)}" y="${by.toStringAsFixed(1)}" '
        'width="${barLen.toStringAsFixed(1)}" height="${barH.toStringAsFixed(1)}" '
        'fill="#${_seriesColor(element, s, si)}"/>',
      );
    }
    buf.write(
      '<text x="${(plotX - 4).toStringAsFixed(1)}" '
      'y="${(y + ci * groupH + groupH / 2 + 3).toStringAsFixed(1)}" '
      'text-anchor="end" font-size="10">${_esc(cat)}</text>',
    );
  }
  return buf.toString();
}

String _scatterSvg(
  DeckChartElement element,
  double x,
  double y,
  double w,
  double h,
) {
  final xs = [
    for (final (i, cat) in element.categories.indexed)
      double.tryParse(cat) ?? (i + 1).toDouble(),
  ];
  final xMin = xs.reduce(min);
  final xMax = xs.reduce(max);
  final xRange = xMax - xMin <= 0 ? 1 : xMax - xMin;
  final yMax = _chartMax(element);
  final buf = StringBuffer(
    '<line x1="$x" y1="${(y + h).toStringAsFixed(1)}" '
    'x2="${(x + w).toStringAsFixed(1)}" y2="${(y + h).toStringAsFixed(1)}" stroke="#999"/>'
    '<line x1="$x" y1="$y" x2="$x" y2="${(y + h).toStringAsFixed(1)}" stroke="#999"/>',
  );
  for (final (si, s) in element.series.indexed) {
    for (final (ci, v) in s.values.indexed) {
      buf.write(
        '<circle cx="${(x + (xs[ci] - xMin) / xRange * w).toStringAsFixed(1)}" '
        'cy="${(y + h - v / yMax * h).toStringAsFixed(1)}" r="4" '
        'fill="#${_seriesColor(element, s, si)}"/>',
      );
    }
  }
  return buf.toString();
}

String _radarSvg(DeckChartElement element, double cx, double cy, double r) {
  final n = element.categories.length;
  final max = _chartMax(element);
  final buf = StringBuffer();
  // 网格（3 圈）+ 轴线 + 维度标签。
  for (final frac in [1.0, 2 / 3, 1 / 3]) {
    final pts = [
      for (var i = 0; i < n; i++)
        '${(cx + r * frac * cos(2 * pi * i / n - pi / 2)).toStringAsFixed(1)},'
            '${(cy + r * frac * sin(2 * pi * i / n - pi / 2)).toStringAsFixed(1)}',
    ].join(' ');
    buf.write(
      '<polygon points="$pts" fill="none" stroke="#bbb" stroke-width="0.5"/>',
    );
  }
  for (var i = 0; i < n; i++) {
    final ang = 2 * pi * i / n - pi / 2;
    buf.write(
      '<line x1="${cx.toStringAsFixed(1)}" y1="${cy.toStringAsFixed(1)}" '
      'x2="${(cx + r * cos(ang)).toStringAsFixed(1)}" '
      'y2="${(cy + r * sin(ang)).toStringAsFixed(1)}" stroke="#ccc" stroke-width="0.5"/>'
      '<text x="${(cx + (r + 10) * cos(ang)).toStringAsFixed(1)}" '
      'y="${(cy + (r + 10) * sin(ang)).toStringAsFixed(1)}" '
      'text-anchor="middle" font-size="9">${_esc(element.categories[i])}</text>',
    );
  }
  for (final (si, s) in element.series.indexed) {
    final pts = [
      for (final (i, v) in s.values.indexed)
        '${(cx + r * v / max * cos(2 * pi * i / n - pi / 2)).toStringAsFixed(1)},'
            '${(cy + r * v / max * sin(2 * pi * i / n - pi / 2)).toStringAsFixed(1)}',
    ].join(' ');
    final color = _seriesColor(element, s, si);
    buf.write(
      '<polygon points="$pts" fill="#$color" fill-opacity="0.25" '
      'stroke="#$color" stroke-width="2"/>',
    );
  }
  return buf.toString();
}

String _tableHtml(DeckTableElement element) {
  final buf = StringBuffer(
    '<div class="el" style="${_pos(element.frame)}">'
    '<table class="deck">',
  );
  final border = element.borderColor;
  final cellBorder = border == null ? '' : 'border:1px solid #${border.value};';
  for (final (rowIndex, row) in element.rows.indexed) {
    buf.write('<tr>');
    for (final cell in row) {
      final style = StringBuffer(cellBorder);
      final fill = cell.fill ?? (rowIndex == 0 ? element.headerFill : null);
      if (fill != null) style.write('background:#${fill.value};');
      if (cell.align != null) style.write('text-align:${cell.align};');
      final runs = cell.runs.map((r) {
        final styled =
            rowIndex == 0 && element.headerColor != null && r.color == null
            ? DeckTextRun(
                text: r.text,
                bold: r.bold,
                italic: r.italic,
                size: r.size,
                color: element.headerColor,
                font: r.font,
              )
            : r;
        return _runHtml(styled);
      }).join();
      buf.write('<td style="$style">$runs</td>');
    }
    buf.write('</tr>');
  }
  buf.write('</table></div>');
  return buf.toString();
}
