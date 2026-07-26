import 'dart:convert';

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
      });
    }
    buf.write('</div>');
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
