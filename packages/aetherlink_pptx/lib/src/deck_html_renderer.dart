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

String _imageHtml(DeckImageElement element) {
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

String _seriesColor(DeckChartSeries series, int index) =>
    series.color?.value ?? _chartPalette[index % _chartPalette.length];

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
    case DeckChartKind.line:
      buf.write(_lineSvg(element, plotX, plotY, plotW, plotH));
    case DeckChartKind.pie:
      buf.write(_pieSvg(element, w / 2, plotY + plotH / 2, plotH / 2));
  }
  // Legend
  var lx = plotX;
  final ly = h - 10;
  final legendEntries = element.kind == DeckChartKind.pie
      ? [
          for (final (i, cat) in element.categories.indexed)
            (cat, _chartPalette[i % _chartPalette.length]),
        ]
      : [
          for (final (i, s) in element.series.indexed)
            (s.name, _seriesColor(s, i)),
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
        'fill="#${_seriesColor(s, si)}"/>',
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
  double h,
) {
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
    buf.write(
      '<polyline points="$points" fill="none" '
      'stroke="#${_seriesColor(s, si)}" stroke-width="2"/>',
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

String _pieSvg(DeckChartElement element, double cx, double cy, double r) {
  final values = element.series.first.values;
  final total = values.fold<double>(0, (a, b) => a + (b < 0 ? 0 : b));
  if (total <= 0) return '';
  final buf = StringBuffer();
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
      'fill="#${_chartPalette[i % _chartPalette.length]}"/>',
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
