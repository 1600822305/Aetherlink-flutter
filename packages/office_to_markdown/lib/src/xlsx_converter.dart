import 'dart:typed_data';

import 'package:xml/xml.dart';

import 'office_parse_exception.dart';
import 'zip_xml.dart';

/// Converts an XLSX (OOXML spreadsheet) to Markdown.
///
/// Each sheet becomes a `## sheetName` section followed by a Markdown table
/// of its cells (in workbook order, resolving shared strings and inline
/// strings; formula cells contribute their cached value). Empty sheets are
/// skipped, and fully empty trailing columns are trimmed.
///
/// Pure Dart and synchronous — heavy documents should be converted inside an
/// isolate (e.g. `compute(XlsxToMarkdown.convert, bytes)`).
class XlsxToMarkdown {
  XlsxToMarkdown._();

  /// Converts XLSX [bytes] to Markdown.
  static String convert(Uint8List bytes) {
    final archive = decodeZip(bytes);
    final workbook = readXml(archive, 'xl/workbook.xml');
    if (workbook == null) {
      throw OfficeParseException('xl/workbook.xml not found');
    }
    final relationships = _parseRelationships(
      readXml(archive, 'xl/_rels/workbook.xml.rels'),
    );
    final sharedStrings = _parseSharedStrings(
      readXml(archive, 'xl/sharedStrings.xml'),
    );

    final sections = <String>[];
    var fallbackIndex = 0;
    for (final sheet in workbook.rootElement.findAllElements('*').where(
      (e) => e.localName == 'sheet',
    )) {
      fallbackIndex++;
      final name = sheet.getAttribute('name') ?? 'Sheet$fallbackIndex';
      final relationshipId = sheet.attributes
          .where((a) => a.localName == 'id')
          .map((a) => a.value)
          .firstOrNull;
      final target = relationshipId == null
          ? null
          : relationships[relationshipId];
      final path = target == null
          ? 'xl/worksheets/sheet$fallbackIndex.xml'
          : _resolveTarget(target);
      final worksheet = readXml(archive, path);
      if (worksheet == null) continue;
      final table = _convertSheet(worksheet, sharedStrings);
      if (table.isEmpty) continue;
      sections.add('## $name\n\n$table');
    }
    return sections.join('\n\n');
  }

  /// Workbook relationship targets are relative to `xl/`.
  static String _resolveTarget(String target) {
    if (target.startsWith('/')) return target.substring(1);
    return 'xl/${target.replaceFirst(RegExp(r'^\./'), '')}';
  }

  static String _convertSheet(
    XmlDocument worksheet,
    List<String> sharedStrings,
  ) {
    final rows = <List<String>>[];
    var columnCount = 0;
    for (final row in worksheet.rootElement.findAllElements('*').where(
      (e) => e.localName == 'row',
    )) {
      final cells = <String>[];
      for (final cell in row.childElements.where((e) => e.localName == 'c')) {
        final column = _columnIndex(cell.getAttribute('r'));
        final value = _cellValue(cell, sharedStrings)
            .replaceAll('\n', ' ')
            .replaceAll('|', r'\|')
            .trim();
        final index = column ?? cells.length;
        while (cells.length < index) {
          cells.add('');
        }
        if (cells.length == index) {
          cells.add(value);
        } else {
          cells[index] = value;
        }
      }
      while (cells.isNotEmpty && cells.last.isEmpty) {
        cells.removeLast();
      }
      if (cells.length > columnCount) columnCount = cells.length;
      rows.add(cells);
    }
    while (rows.isNotEmpty && rows.last.isEmpty) {
      rows.removeLast();
    }
    if (rows.isEmpty || columnCount == 0) return '';

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

  /// Zero-based column index from a cell reference like `B3`, or null when
  /// the reference is absent (cells then just append in document order).
  static int? _columnIndex(String? reference) {
    if (reference == null) return null;
    var index = 0;
    var seen = false;
    for (final code in reference.codeUnits) {
      if (code >= 0x41 && code <= 0x5A) {
        index = index * 26 + (code - 0x40);
        seen = true;
      } else {
        break;
      }
    }
    return seen ? index - 1 : null;
  }

  static String _cellValue(XmlElement cell, List<String> sharedStrings) {
    final type = cell.getAttribute('t');
    if (type == 'inlineStr') {
      final inline = childElement(cell, 'is');
      return inline == null ? '' : _richText(inline);
    }
    final value = childElement(cell, 'v')?.innerText ?? '';
    switch (type) {
      case 's':
        final index = int.tryParse(value);
        return (index != null && index >= 0 && index < sharedStrings.length)
            ? sharedStrings[index]
            : '';
      case 'b':
        return value == '1' ? 'TRUE' : 'FALSE';
      default:
        return value;
    }
  }

  static List<String> _parseSharedStrings(XmlDocument? sharedStrings) {
    if (sharedStrings == null) return const [];
    return [
      for (final si in sharedStrings.rootElement.childElements.where(
        (e) => e.localName == 'si',
      ))
        _richText(si),
    ];
  }

  /// Concatenates the `t` runs of an `si` / `is` element (plain or rich text).
  static String _richText(XmlElement element) {
    final buffer = StringBuffer();
    for (final t in element.findAllElements('*').where(
      (e) => e.localName == 't',
    )) {
      buffer.write(t.innerText);
    }
    return buffer.toString();
  }

  static Map<String, String> _parseRelationships(XmlDocument? relationships) {
    if (relationships == null) return const {};
    final result = <String, String>{};
    for (final element in relationships.rootElement.childElements) {
      if (element.localName != 'Relationship') continue;
      final id = element.getAttribute('Id');
      final target = element.getAttribute('Target');
      if (id != null && target != null) result[id] = target;
    }
    return result;
  }
}
