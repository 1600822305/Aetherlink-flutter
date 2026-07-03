import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'office_parse_exception.dart';
import 'zip_xml.dart';

/// Converts a PPTX (OOXML presentation) to Markdown.
///
/// Slides are emitted in `ppt/slides/slideN.xml` numeric order. The slide's
/// title placeholder becomes a `## ` heading (falling back to `## Slide N`
/// when a slide has body text but no title), body paragraphs keep their
/// bullet/ordinal prefixes as list items, and tables become Markdown tables.
/// Slides with no text at all (e.g. pure images) are skipped.
///
/// Pure Dart and synchronous — heavy documents should be converted inside an
/// isolate (e.g. `compute(PptxToMarkdown.convert, bytes)`).
class PptxToMarkdown {
  PptxToMarkdown._();

  /// Converts PPTX [bytes] to Markdown.
  static String convert(Uint8List bytes) {
    final archive = decodeZip(bytes);
    final slidePattern = RegExp(r'^ppt/slides/slide(\d+)\.xml$');
    final slides = <(int, ArchiveFile)>[];
    for (final file in archive.files) {
      final match = slidePattern.firstMatch(file.name);
      if (match != null) slides.add((int.parse(match.group(1)!), file));
    }
    if (slides.isEmpty) {
      throw OfficeParseException('No ppt/slides/slideN.xml found');
    }
    slides.sort((a, b) => a.$1.compareTo(b.$1));

    final sections = <String>[];
    for (final (number, file) in slides) {
      final document = parseXml(readString(file), file.name);
      final section = _convertSlide(document, number);
      if (section.isNotEmpty) sections.add(section);
    }
    return sections.join('\n\n');
  }

  static String _convertSlide(XmlDocument document, int number) {
    String? title;
    final blocks = <String>[];
    for (final shape in document.rootElement.findAllElements('*')) {
      if (shape.localName == 'sp') {
        if (title == null && _isTitleShape(shape)) {
          final text = _shapePlainText(shape);
          if (text.isNotEmpty) title = text;
          continue;
        }
        final text = _convertShapeParagraphs(shape);
        if (text.isNotEmpty) blocks.add(text);
      } else if (shape.localName == 'graphicFrame') {
        final table = shape.findAllElements('*').where(
          (e) => e.localName == 'tbl',
        );
        for (final tbl in table) {
          final markdown = _convertTable(tbl);
          if (markdown.isNotEmpty) blocks.add(markdown);
        }
      }
    }
    if (title == null && blocks.isEmpty) return '';
    final buffer = StringBuffer('## ${title ?? 'Slide $number'}');
    for (final block in blocks) {
      buffer
        ..write('\n\n')
        ..write(block);
    }
    return buffer.toString();
  }

  /// A shape whose placeholder type is `title` / `ctrTitle` holds the slide
  /// title (ECMA-376 `p:ph/@type`).
  static bool _isTitleShape(XmlElement shape) {
    for (final ph in shape.findAllElements('*')) {
      if (ph.localName != 'ph') continue;
      final type = ph.getAttribute('type');
      if (type == 'title' || type == 'ctrTitle') return true;
    }
    return false;
  }

  /// Paragraph texts of a shape joined with spaces, no list formatting —
  /// used for the title placeholder.
  static String _shapePlainText(XmlElement shape) {
    final body = shape.findAllElements('*').where(
      (e) => e.localName == 'txBody',
    );
    if (body.isEmpty) return '';
    return [
      for (final paragraph in body.first.childElements.where(
        (e) => e.localName == 'p',
      ))
        _paragraphText(paragraph).replaceAll('\n', ' ').trim(),
    ].where((t) => t.isNotEmpty).join(' ');
  }

  static String _convertShapeParagraphs(XmlElement shape) {
    final body = shape.findAllElements('*').where(
      (e) => e.localName == 'txBody',
    );
    if (body.isEmpty) return '';
    final lines = <String>[];
    for (final paragraph in body.first.childElements.where(
      (e) => e.localName == 'p',
    )) {
      final text = _paragraphText(paragraph).trim();
      if (text.isEmpty) continue;
      final level = _paragraphLevel(paragraph);
      lines.add(level == null ? text : '${'  ' * level}- $text');
    }
    return lines.join('\n');
  }

  /// Indentation level for bulleted body paragraphs, or null when the
  /// paragraph explicitly disables bullets (`a:buNone`).
  static int? _paragraphLevel(XmlElement paragraph) {
    final properties = childElement(paragraph, 'pPr');
    if (childElement(properties, 'buNone') != null) return null;
    return int.tryParse(properties?.getAttribute('lvl') ?? '0') ?? 0;
  }

  static String _paragraphText(XmlElement paragraph) {
    final buffer = StringBuffer();
    for (final element in paragraph.childElements) {
      switch (element.localName) {
        case 'r':
        case 'fld':
          final t = childElement(element, 't');
          if (t != null) buffer.write(t.innerText);
        case 'br':
          buffer.write('\n');
        default:
          break;
      }
    }
    return buffer.toString();
  }

  static String _convertTable(XmlElement table) {
    final rows = <List<String>>[];
    for (final row in table.childElements.where((e) => e.localName == 'tr')) {
      final cells = <String>[];
      for (final cell in row.childElements.where((e) => e.localName == 'tc')) {
        final texts = <String>[
          for (final p in cell.findAllElements('*').where(
            (e) => e.localName == 'p',
          ))
            _paragraphText(p),
        ];
        cells.add(
          texts.join(' ').replaceAll('\n', ' ').replaceAll('|', r'\|').trim(),
        );
      }
      if (cells.isNotEmpty) rows.add(cells);
    }
    if (rows.isEmpty) return '';
    final columnCount = rows
        .map((r) => r.length)
        .reduce((a, b) => a > b ? a : b);
    String render(List<String> cells) =>
        '| ${List.generate(columnCount, (i) => i < cells.length ? cells[i] : '').join(' | ')} |';
    final buffer = StringBuffer()
      ..writeln(render(rows.first))
      ..writeln('| ${List.filled(columnCount, '---').join(' | ')} |');
    for (final row in rows.skip(1)) {
      buffer.writeln(render(row));
    }
    return buffer.toString().trimRight();
  }
}
