import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Thrown when [bytes] is not a valid DOCX package (bad zip, or missing
/// `word/document.xml`).
class DocxParseException implements Exception {
  DocxParseException(this.message);

  final String message;

  @override
  String toString() => 'DocxParseException: $message';
}

/// Converts a DOCX (OOXML) document to Markdown.
///
/// Supported constructs: headings (via `Heading1..9` / `Title` paragraph
/// styles), bold / italic / strikethrough runs, hyperlinks, bullet and
/// numbered lists (with nesting), tables, line breaks and tabs. Everything
/// else degrades to its plain text content.
///
/// Pure Dart and synchronous — heavy documents should be converted inside an
/// isolate (e.g. `compute(DocxToMarkdown.convert, bytes)`).
class DocxToMarkdown {
  DocxToMarkdown._(this._relationships, this._bulletNumIds, this._styleNames);

  /// Converts DOCX [bytes] to Markdown.
  static String convert(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw DocxParseException('Not a valid zip archive: $e');
    }

    final document = _readXml(archive, 'word/document.xml');
    if (document == null) {
      throw DocxParseException('word/document.xml not found');
    }

    final converter = DocxToMarkdown._(
      _parseRelationships(_readXml(archive, 'word/_rels/document.xml.rels')),
      _parseBulletNumIds(_readXml(archive, 'word/numbering.xml')),
      _parseStyleNames(_readXml(archive, 'word/styles.xml')),
    );

    final body = document.rootElement.childElements
        .where((e) => e.localName == 'body')
        .firstOrNull;
    if (body == null) return '';
    return converter._convertBlocks(body.childElements);
  }

  /// Relationship id → target URL (external hyperlinks).
  final Map<String, String> _relationships;

  /// numIds whose level-0 numFmt is `bullet`; other known numIds are ordered.
  final Set<String> _bulletNumIds;

  /// styleId → style name from `word/styles.xml`. Localized Word builds use
  /// opaque styleIds (e.g. "1" for 标题 1) while the name stays "heading 1".
  final Map<String, String> _styleNames;

  /// Per-numId ordinal counters, so consecutive ordered items count up.
  final Map<String, Map<int, int>> _orderedCounters = {};

  String _convertBlocks(Iterable<XmlElement> elements) {
    final blocks = <String>[];
    String? previousNumId;

    for (final element in elements) {
      switch (element.localName) {
        case 'p':
          final numId = _paragraphNumId(element);
          if (numId == null && previousNumId != null) {
            _orderedCounters.remove(previousNumId);
          }
          previousNumId = numId;
          final markdown = _convertParagraph(element);
          if (markdown != null) blocks.add(markdown);
        case 'tbl':
          previousNumId = null;
          final markdown = _convertTable(element);
          if (markdown.isNotEmpty) blocks.add(markdown);
        default:
          break;
      }
    }

    return _joinBlocks(blocks);
  }

  /// Joins blocks with blank lines, but keeps consecutive list items adjacent.
  static String _joinBlocks(List<String> blocks) {
    final buffer = StringBuffer();
    String? previous;
    for (final block in blocks) {
      if (previous != null) {
        buffer.write(_isListItem(previous) && _isListItem(block) ? '\n' : '\n\n');
      }
      buffer.write(block);
      previous = block;
    }
    return buffer.toString();
  }

  static final _listItemPattern = RegExp(r'^\s*(?:[-*+]|\d+\.)\s');

  static bool _isListItem(String block) => _listItemPattern.hasMatch(block);

  String? _convertParagraph(XmlElement paragraph) {
    final text = _convertInlines(paragraph.childElements).trim();
    if (text.isEmpty) return null;

    final properties = _child(paragraph, 'pPr');
    final headingLevel = _headingLevel(properties);
    if (headingLevel != null) {
      return '${'#' * headingLevel} $text';
    }

    final listPrefix = _listPrefix(properties);
    if (listPrefix != null) {
      return '$listPrefix$text';
    }

    return text;
  }

  int? _headingLevel(XmlElement? properties) {
    final styleId = _child(properties, 'pStyle')?.getAttribute('w:val');
    if (styleId == null) return null;
    return _headingLevelOfStyle(styleId) ??
        _headingLevelOfStyle(_styleNames[styleId]);
  }

  static int? _headingLevelOfStyle(String? style) {
    if (style == null) return null;
    if (style.toLowerCase() == 'title') return 1;
    final match = RegExp(r'^[Hh]eading\s*([1-9])$').firstMatch(style);
    if (match != null) return int.parse(match.group(1)!);
    return null;
  }

  String? _paragraphNumId(XmlElement paragraph) {
    final numPr = _child(_child(paragraph, 'pPr'), 'numPr');
    return _child(numPr, 'numId')?.getAttribute('w:val');
  }

  String? _listPrefix(XmlElement? properties) {
    final numPr = _child(properties, 'numPr');
    if (numPr == null) return null;
    final numId = _child(numPr, 'numId')?.getAttribute('w:val');
    if (numId == null || numId == '0') return null;

    final level =
        int.tryParse(_child(numPr, 'ilvl')?.getAttribute('w:val') ?? '0') ?? 0;
    final indent = '  ' * level;

    if (_bulletNumIds.contains(numId)) return '$indent- ';

    final counters = _orderedCounters.putIfAbsent(numId, () => {});
    final ordinal = (counters[level] ?? 0) + 1;
    counters[level] = ordinal;
    // Entering a deeper item resets counters below it on the way back up.
    counters.removeWhere((l, _) => l > level);
    return '$indent$ordinal. ';
  }

  String _convertInlines(Iterable<XmlElement> elements) {
    final buffer = StringBuffer();
    for (final element in elements) {
      switch (element.localName) {
        case 'r':
          buffer.write(_convertRun(element));
        case 'hyperlink':
          buffer.write(_convertHyperlink(element));
        case 'smartTag':
        case 'ins':
        case 'sdt':
        case 'sdtContent':
          buffer.write(_convertInlines(element.childElements));
        default:
          break;
      }
    }
    return buffer.toString();
  }

  String _convertRun(XmlElement run) {
    final buffer = StringBuffer();
    for (final element in run.childElements) {
      switch (element.localName) {
        case 't':
          buffer.write(element.innerText);
        case 'br':
        case 'cr':
          buffer.write('\n');
        case 'tab':
          buffer.write('\t');
        default:
          break;
      }
    }
    final text = buffer.toString();
    if (text.trim().isEmpty) return text;

    final properties = _child(run, 'rPr');
    var (prefix, suffix) = ('', '');
    if (_flag(properties, 'b')) {
      prefix = '**$prefix';
      suffix = '$suffix**';
    }
    if (_flag(properties, 'i')) {
      prefix = '*$prefix';
      suffix = '$suffix*';
    }
    if (_flag(properties, 'strike')) {
      prefix = '~~$prefix';
      suffix = '$suffix~~';
    }
    if (prefix.isEmpty) return text;

    // Markdown emphasis breaks across leading/trailing whitespace; keep it outside.
    final leading = RegExp(r'^\s*').firstMatch(text)!.group(0)!;
    final trailing = RegExp(r'\s*$').firstMatch(text)!.group(0)!;
    final core = text.substring(leading.length, text.length - trailing.length);
    return '$leading$prefix$core$suffix$trailing';
  }

  String _convertHyperlink(XmlElement hyperlink) {
    final text = _convertInlines(hyperlink.childElements);
    final relationshipId = hyperlink.getAttribute('r:id');
    final target = relationshipId == null ? null : _relationships[relationshipId];
    if (target == null || text.trim().isEmpty) return text;
    return '[$text]($target)';
  }

  String _convertTable(XmlElement table) {
    final rows = <List<String>>[];
    for (final row in table.childElements.where((e) => e.localName == 'tr')) {
      final cells = <String>[];
      for (final cell in row.childElements.where((e) => e.localName == 'tc')) {
        final content = _convertBlocks(cell.childElements)
            .replaceAll('\n', ' ')
            .replaceAll('|', r'\|')
            .trim();
        cells.add(content);
      }
      if (cells.isNotEmpty) rows.add(cells);
    }
    if (rows.isEmpty) return '';

    final columnCount = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    String renderRow(List<String> cells) =>
        '| ${List.generate(columnCount, (i) => i < cells.length ? cells[i] : '').join(' | ')} |';

    final buffer = StringBuffer()
      ..writeln(renderRow(rows.first))
      ..writeln('| ${List.filled(columnCount, '---').join(' | ')} |');
    for (final row in rows.skip(1)) {
      buffer.writeln(renderRow(row));
    }
    return buffer.toString().trimRight();
  }

  static XmlElement? _child(XmlElement? parent, String localName) => parent
      ?.childElements
      .where((e) => e.localName == localName)
      .firstOrNull;

  /// OOXML boolean toggle: present with no `w:val` (or a truthy one) means on.
  static bool _flag(XmlElement? properties, String localName) {
    final element = _child(properties, localName);
    if (element == null) return false;
    final value = element.getAttribute('w:val');
    return value == null || value == '1' || value == 'true' || value == 'on';
  }

  static XmlDocument? _readXml(Archive archive, String path) {
    final file = archive.findFile(path);
    if (file == null) return null;
    try {
      var text = utf8.decode(file.content as List<int>);
      // Strip a UTF-8 BOM — XmlDocument.parse rejects it as leading content.
      if (text.startsWith('\uFEFF')) text = text.substring(1);
      return XmlDocument.parse(text);
    } catch (e) {
      throw DocxParseException('Failed to parse $path: $e');
    }
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

  static Map<String, String> _parseStyleNames(XmlDocument? styles) {
    if (styles == null) return const {};
    final result = <String, String>{};
    for (final style in styles.rootElement.childElements
        .where((e) => e.localName == 'style')) {
      final id = style.getAttribute('w:styleId');
      final name = _child(style, 'name')?.getAttribute('w:val');
      if (id != null && name != null) result[id] = name;
    }
    return result;
  }

  /// numIds resolving (via abstractNumId) to a level-0 `bullet` numFmt.
  static Set<String> _parseBulletNumIds(XmlDocument? numbering) {
    if (numbering == null) return const {};

    final bulletAbstractIds = <String>{};
    final root = numbering.rootElement;
    for (final abstract in root.childElements
        .where((e) => e.localName == 'abstractNum')) {
      final abstractId = abstract.getAttribute('w:abstractNumId');
      if (abstractId == null) continue;
      final level0 = abstract.childElements.where(
        (e) => e.localName == 'lvl' && e.getAttribute('w:ilvl') == '0',
      );
      final format = level0.isEmpty
          ? null
          : _child(level0.first, 'numFmt')?.getAttribute('w:val');
      if (format == 'bullet') bulletAbstractIds.add(abstractId);
    }

    final bulletNumIds = <String>{};
    for (final num in root.childElements.where((e) => e.localName == 'num')) {
      final numId = num.getAttribute('w:numId');
      final abstractId = _child(num, 'abstractNumId')?.getAttribute('w:val');
      if (numId != null && bulletAbstractIds.contains(abstractId)) {
        bulletNumIds.add(numId);
      }
    }
    return bulletNumIds;
  }
}

