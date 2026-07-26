import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Thrown when [readPptxBytes] can't make sense of the input — not a zip, not
/// a pptx, or a required part is missing/unparsable. [message] is a
/// model-facing, actionable description.
class PptxReadException implements Exception {
  PptxReadException(this.message);

  final String message;

  @override
  String toString() => 'PptxReadException: $message';
}

/// One extracted table: plain-text cells, row-major.
class PptxTableContent {
  const PptxTableContent({required this.rows});

  final List<List<String>> rows;
}

/// One extracted chart series: name plus values (in category order).
class PptxChartSeriesContent {
  const PptxChartSeriesContent({required this.name, required this.values});

  final String name;
  final List<double> values;
}

/// One extracted chart, from the cached data in its `c:chartSpace` part.
class PptxChartContent {
  const PptxChartContent({
    required this.kind,
    required this.categories,
    required this.series,
    this.title,
  });

  /// Raw OOXML plot element name minus the `Chart` suffix — `bar` / `line` /
  /// `pie` / `doughnut` / `scatter` / `area`…（保留原始类型，不做映射）。
  final String kind;
  final String? title;
  final List<String> categories;
  final List<PptxChartSeriesContent> series;
}

/// Extracted content of one slide, in shape (z) order.
class PptxSlideContent {
  const PptxSlideContent({
    required this.texts,
    required this.tables,
    required this.charts,
    required this.imageCount,
    this.notes,
  });

  /// Plain text of each text-bearing shape (paragraphs joined by `\n`).
  final List<String> texts;
  final List<PptxTableContent> tables;
  final List<PptxChartContent> charts;
  final int imageCount;

  /// Speaker notes text, when the slide has a notesSlide part.
  final String? notes;
}

/// Structured content extracted from an existing .pptx package.
class PptxReadResult {
  const PptxReadResult({
    required this.slides,
    required this.slideWidthInches,
    required this.slideHeightInches,
    this.title,
  });

  final String? title;
  final double slideWidthInches;
  final double slideHeightInches;
  final List<PptxSlideContent> slides;
}

const String _relNs =
    'http://schemas.openxmlformats.org/package/2006/relationships';

/// Parses an existing .pptx (or .potx) package and extracts its text,
/// tables, cached chart data and speaker notes, slide by slide in
/// presentation order. Pure Dart and synchronous — call inside an isolate
/// for big files (e.g. `Isolate.run(() => readPptxBytes(bytes))`).
PptxReadResult readPptxBytes(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (e) {
    throw PptxReadException('不是合法的 zip/pptx 文件：$e');
  }
  final parts = <String, Uint8List>{
    for (final f in archive.files)
      if (f.isFile) f.name: f.readBytes() ?? Uint8List(0),
  };

  XmlDocument parseXml(String path) {
    final data = parts[path];
    if (data == null) {
      throw PptxReadException('pptx 包缺少必需部件: $path');
    }
    try {
      return XmlDocument.parse(utf8.decode(data));
    } catch (e) {
      throw PptxReadException('部件 $path 不是合法 XML：$e');
    }
  }

  // rels of presentation.xml: rId → target (resolved relative to ppt/).
  final presRels = _parseRels(parseXml('ppt/_rels/presentation.xml.rels'));

  final presentation = parseXml('ppt/presentation.xml');
  final sldSz = presentation
      .findAllElements('sldSz', namespace: '*')
      .firstOrNull;
  final widthEmu = int.tryParse(sldSz?.getAttribute('cx') ?? '') ?? 12192000;
  final heightEmu = int.tryParse(sldSz?.getAttribute('cy') ?? '') ?? 6858000;

  final slidePaths = <String>[];
  for (final sldId in presentation.findAllElements('sldId', namespace: '*')) {
    final rId = sldId.attributes
        .where((a) => a.name.local == 'id' && a.name.prefix == 'r')
        .firstOrNull
        ?.value;
    final target = rId == null ? null : presRels[rId];
    if (target == null) {
      throw PptxReadException('presentation.xml 的 sldId 引用了不存在的关系 "$rId"');
    }
    slidePaths.add(_resolvePath('ppt', target));
  }
  if (slidePaths.isEmpty) {
    throw PptxReadException('这个 pptx 没有任何幻灯片');
  }

  String? title;
  final coreData = parts['docProps/core.xml'];
  if (coreData != null) {
    try {
      final core = XmlDocument.parse(utf8.decode(coreData));
      final t = core.findAllElements('title', namespace: '*').firstOrNull;
      final text = t?.innerText.trim();
      if (text != null && text.isNotEmpty) title = text;
    } catch (_) {}
  }

  final slides = <PptxSlideContent>[];
  for (final slidePath in slidePaths) {
    final slideDoc = parseXml(slidePath);
    final relsPath = _relsPathFor(slidePath);
    final slideRels = parts.containsKey(relsPath)
        ? _parseRels(parseXml(relsPath))
        : const <String, String>{};
    final slideDir = _dirname(slidePath);

    final texts = <String>[];
    final tables = <PptxTableContent>[];
    final charts = <PptxChartContent>[];
    var imageCount = 0;

    final spTree = slideDoc
        .findAllElements('spTree', namespace: '*')
        .firstOrNull;
    if (spTree != null) {
      for (final node in spTree.childElements) {
        switch (node.name.local) {
          case 'sp':
            final text = _shapeText(node);
            if (text.isNotEmpty) texts.add(text);
          case 'pic':
            imageCount++;
          case 'graphicFrame':
            final tbl = node.findAllElements('tbl', namespace: '*').firstOrNull;
            if (tbl != null) {
              tables.add(_parseTable(tbl));
              break;
            }
            final chartRef = node
                .findAllElements('chart', namespace: '*')
                .firstOrNull;
            final rId = chartRef?.attributes
                .where((a) => a.name.local == 'id' && a.name.prefix == 'r')
                .firstOrNull
                ?.value;
            final target = rId == null ? null : slideRels[rId];
            if (target != null) {
              final chartPath = _resolvePath(slideDir, target);
              final data = parts[chartPath];
              if (data != null) {
                try {
                  charts.add(_parseChart(XmlDocument.parse(utf8.decode(data))));
                } catch (_) {}
              }
            }
        }
      }
    }

    String? notes;
    for (final entry in slideRels.entries) {
      if (!entry.value.contains('notesSlide')) continue;
      final notesPath = _resolvePath(slideDir, entry.value);
      final data = parts[notesPath];
      if (data == null) continue;
      try {
        final notesDoc = XmlDocument.parse(utf8.decode(data));
        final paras = <String>[];
        for (final sp in notesDoc.findAllElements('sp', namespace: '*')) {
          final phType = sp
              .findAllElements('ph', namespace: '*')
              .firstOrNull
              ?.getAttribute('type');
          // 备注正文在 body 占位符里；跳过页码/页眉等其他占位符。
          if (phType != null && phType != 'body') continue;
          final text = _shapeText(sp);
          if (text.isNotEmpty) paras.add(text);
        }
        final joined = paras.join('\n').trim();
        if (joined.isNotEmpty) notes = joined;
      } catch (_) {}
      break;
    }

    slides.add(
      PptxSlideContent(
        texts: texts,
        tables: tables,
        charts: charts,
        imageCount: imageCount,
        notes: notes,
      ),
    );
  }

  return PptxReadResult(
    title: title,
    slideWidthInches: widthEmu / 914400,
    slideHeightInches: heightEmu / 914400,
    slides: slides,
  );
}

/// Renders [result] as readable markdown — one section per slide (aligned
/// with markitdown's `<!-- Slide number: N -->` sectioning), tables as
/// markdown tables, charts as data summaries, notes as blockquotes.
String pptxToMarkdown(PptxReadResult result) {
  final buf = StringBuffer();
  if (result.title != null && result.title!.isNotEmpty) {
    buf.writeln('# ${result.title}');
    buf.writeln();
  }
  for (final (i, slide) in result.slides.indexed) {
    buf.writeln('<!-- Slide number: ${i + 1} -->');
    for (final text in slide.texts) {
      buf.writeln(text);
      buf.writeln();
    }
    for (final table in slide.tables) {
      if (table.rows.isEmpty) continue;
      String row(List<String> cells) =>
          '| ${cells.map((c) => c.replaceAll('|', r'\|').replaceAll('\n', ' ')).join(' | ')} |';
      buf.writeln(row(table.rows.first));
      buf.writeln('|${List.filled(table.rows.first.length, '---').join('|')}|');
      for (final r in table.rows.skip(1)) {
        buf.writeln(row(r));
      }
      buf.writeln();
    }
    for (final chart in slide.charts) {
      buf.writeln(
        '图表（${chart.kind}${chart.title == null ? '' : '：${chart.title}'}）',
      );
      for (final series in chart.series) {
        final pairs = <String>[];
        for (var c = 0; c < series.values.length; c++) {
          final cat = c < chart.categories.length
              ? chart.categories[c]
              : '#${c + 1}';
          pairs.add('$cat=${_fmtNum(series.values[c])}');
        }
        buf.writeln('- ${series.name}: ${pairs.join(', ')}');
      }
      buf.writeln();
    }
    if (slide.imageCount > 0) {
      buf.writeln('（含 ${slide.imageCount} 张图片）');
      buf.writeln();
    }
    if (slide.notes != null) {
      for (final line in slide.notes!.split('\n')) {
        buf.writeln('> 备注：$line');
      }
      buf.writeln();
    }
  }
  return buf.toString().trimRight();
}

/// Converts [result] into a deck.json skeleton the agent can iterate on:
/// text/table/chart elements with their original frames (inches). Images
/// are not embedded (bytes stay in the source file); unsupported chart
/// kinds fall back to `bar` so the skeleton always parses.
Map<String, Object?> pptxToDeckSkeleton(PptxReadResult result) {
  final is4x3 =
      (result.slideWidthInches - 10).abs() < 0.01 &&
      (result.slideHeightInches - 7.5).abs() < 0.01;
  return {
    'layout': is4x3 ? '4x3' : '16x9',
    if (result.title != null) 'title': result.title,
    'slides': [
      for (final slide in result.slides)
        {
          'elements': [
            for (final text in slide.texts)
              {
                'type': 'text',
                'x': 1,
                'y': 1,
                'w': result.slideWidthInches - 2,
                'h': 1,
                'paragraphs': [
                  for (final line in text.split('\n'))
                    {
                      'runs': [
                        {'text': line},
                      ],
                    },
                ],
              },
            for (final table in slide.tables)
              {
                'type': 'table',
                'x': 1,
                'y': 1,
                'w': result.slideWidthInches - 2,
                'h': 2,
                'rows': table.rows,
              },
            for (final chart in slide.charts)
              {
                'type': 'chart',
                'chart': const {'bar', 'line', 'pie'}.contains(chart.kind)
                    ? chart.kind
                    : 'bar',
                'x': 1,
                'y': 1,
                'w': 6,
                'h': 4.5,
                if (chart.title != null) 'title': chart.title,
                'categories': chart.categories.isEmpty
                    ? [
                        for (
                          var i = 0;
                          i < (chart.series.firstOrNull?.values.length ?? 0);
                          i++
                        )
                          '#${i + 1}',
                      ]
                    : chart.categories,
                'series': [
                  for (final s in chart.series)
                    {'name': s.name, 'values': s.values},
                ],
              },
          ],
          if (slide.notes != null) 'notes': slide.notes,
        },
    ],
  };
}

String _fmtNum(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toString();

/// rId → target of one .rels document (external targets skipped).
Map<String, String> _parseRels(XmlDocument doc) {
  final rels = <String, String>{};
  for (final rel in doc.findAllElements('Relationship', namespace: _relNs)) {
    if (rel.getAttribute('TargetMode') == 'External') continue;
    final id = rel.getAttribute('Id');
    final target = rel.getAttribute('Target');
    if (id != null && target != null) rels[id] = target;
  }
  return rels;
}

/// `ppt/slides/slide1.xml` → `ppt/slides/_rels/slide1.xml.rels`.
String _relsPathFor(String partPath) {
  final dir = _dirname(partPath);
  final name = partPath.substring(dir.isEmpty ? 0 : dir.length + 1);
  return dir.isEmpty ? '_rels/$name.rels' : '$dir/_rels/$name.rels';
}

String _dirname(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? '' : path.substring(0, i);
}

/// Resolves a (possibly `../`-relative) rels [target] against [baseDir].
String _resolvePath(String baseDir, String target) {
  if (target.startsWith('/')) return target.substring(1);
  final stack = baseDir.isEmpty ? <String>[] : baseDir.split('/');
  for (final seg in target.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') {
      if (stack.isNotEmpty) stack.removeLast();
      continue;
    }
    stack.add(seg);
  }
  return stack.join('/');
}

/// Plain text of a shape's txBody: runs joined per paragraph, paragraphs
/// joined by `\n`. Empty string when the shape has no text.
String _shapeText(XmlElement sp) {
  final txBody = sp.findAllElements('txBody', namespace: '*').firstOrNull;
  if (txBody == null) return '';
  final paras = <String>[];
  for (final p in txBody.childElements.where((e) => e.name.local == 'p')) {
    final runs = <String>[];
    for (final t in p.findAllElements('t', namespace: '*')) {
      runs.add(t.innerText);
    }
    final text = runs.join();
    if (text.trim().isNotEmpty) paras.add(text);
  }
  return paras.join('\n');
}

PptxTableContent _parseTable(XmlElement tbl) {
  final rows = <List<String>>[];
  for (final tr in tbl.childElements.where((e) => e.name.local == 'tr')) {
    final cells = <String>[];
    for (final tc in tr.childElements.where((e) => e.name.local == 'tc')) {
      cells.add(_shapeText(tc).replaceAll('\n', ' '));
    }
    rows.add(cells);
  }
  return PptxTableContent(rows: rows);
}

PptxChartContent _parseChart(XmlDocument chartDoc) {
  XmlElement? plot;
  for (final el
      in chartDoc
              .findAllElements('plotArea', namespace: '*')
              .firstOrNull
              ?.childElements ??
          const Iterable<XmlElement>.empty()) {
    if (el.name.local.endsWith('Chart')) {
      plot = el;
      break;
    }
  }
  final kind = plot == null
      ? 'unknown'
      : plot.name.local.substring(0, plot.name.local.length - 'Chart'.length);

  String? title;
  final titleEl = chartDoc.findAllElements('title', namespace: '*').firstOrNull;
  if (titleEl != null) {
    final text = titleEl
        .findAllElements('t', namespace: '*')
        .map((t) => t.innerText)
        .join();
    if (text.trim().isNotEmpty) title = text;
  }

  final categories = <String>[];
  final series = <PptxChartSeriesContent>[];
  if (plot != null) {
    for (final ser in plot.childElements.where((e) => e.name.local == 'ser')) {
      var name = '系列${series.length + 1}';
      final tx = ser.childElements
          .where((e) => e.name.local == 'tx')
          .firstOrNull;
      if (tx != null) {
        final t =
            tx.findAllElements('v', namespace: '*').firstOrNull?.innerText ??
            tx
                .findAllElements('t', namespace: '*')
                .map((e) => e.innerText)
                .join();
        if (t.trim().isNotEmpty) name = t;
      }
      if (categories.isEmpty) {
        final cat = ser.childElements
            .where((e) => e.name.local == 'cat')
            .firstOrNull;
        if (cat != null) {
          for (final pt in cat.findAllElements('pt', namespace: '*')) {
            categories.add(
              pt.findAllElements('v', namespace: '*').firstOrNull?.innerText ??
                  '',
            );
          }
        }
      }
      final values = <double>[];
      final val = ser.childElements
          .where((e) => e.name.local == 'val')
          .firstOrNull;
      if (val != null) {
        for (final pt in val.findAllElements('pt', namespace: '*')) {
          values.add(
            double.tryParse(
                  pt
                          .findAllElements('v', namespace: '*')
                          .firstOrNull
                          ?.innerText ??
                      '',
                ) ??
                0,
          );
        }
      }
      series.add(PptxChartSeriesContent(name: name, values: values));
    }
  }
  return PptxChartContent(
    kind: kind,
    title: title,
    categories: categories,
    series: series,
  );
}
