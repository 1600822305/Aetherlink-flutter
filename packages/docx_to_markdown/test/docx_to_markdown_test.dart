import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:docx_to_markdown/docx_to_markdown.dart';
import 'package:test/test.dart';

const _wNs = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';

Uint8List buildDocx({
  required String body,
  String? relationships,
  String? numbering,
}) {
  final archive = Archive();

  void addFile(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  addFile(
    'word/document.xml',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:document $_wNs><w:body>$body</w:body></w:document>',
  );
  if (relationships != null) {
    addFile(
      'word/_rels/document.xml.rels',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '$relationships</Relationships>',
    );
  }
  if (numbering != null) {
    addFile(
      'word/numbering.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:numbering $_wNs>$numbering</w:numbering>',
    );
  }

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String p(String runs, {String? properties}) =>
    '<w:p>${properties == null ? '' : '<w:pPr>$properties</w:pPr>'}$runs</w:p>';

String r(String text, {String? properties}) =>
    '<w:r>${properties == null ? '' : '<w:rPr>$properties</w:rPr>'}'
    '<w:t xml:space="preserve">$text</w:t></w:r>';

void main() {
  group('DocxToMarkdown.convert', () {
    test('throws on invalid zip bytes', () {
      expect(
        () => DocxToMarkdown.convert(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<DocxParseException>()),
      );
    });

    test('throws when word/document.xml is missing', () {
      final archive = Archive();
      final bytes = utf8.encode('hi');
      archive.addFile(ArchiveFile('other.txt', bytes.length, bytes));
      expect(
        () => DocxToMarkdown.convert(
          Uint8List.fromList(ZipEncoder().encode(archive)),
        ),
        throwsA(isA<DocxParseException>()),
      );
    });

    test('converts plain paragraphs separated by blank lines', () {
      final bytes = buildDocx(body: p(r('First')) + p(r('Second')));
      expect(DocxToMarkdown.convert(bytes), 'First\n\nSecond');
    });

    test('skips empty paragraphs', () {
      final bytes = buildDocx(body: p(r('A')) + p(r('  ')) + p(r('B')));
      expect(DocxToMarkdown.convert(bytes), 'A\n\nB');
    });

    test('converts heading styles and Title', () {
      final bytes = buildDocx(
        body: p(r('Top'), properties: '<w:pStyle w:val="Title"/>') +
            p(r('One'), properties: '<w:pStyle w:val="Heading1"/>') +
            p(r('Three'), properties: '<w:pStyle w:val="Heading3"/>'),
      );
      expect(DocxToMarkdown.convert(bytes), '# Top\n\n# One\n\n### Three');
    });

    test('converts bold, italic and strikethrough runs', () {
      final bytes = buildDocx(
        body: p(
          r('plain ') +
              r('bold', properties: '<w:b/>') +
              r(' and ') +
              r('italic', properties: '<w:i/>') +
              r(' and ') +
              r('gone', properties: '<w:strike/>'),
        ),
      );
      expect(
        DocxToMarkdown.convert(bytes),
        'plain **bold** and *italic* and ~~gone~~',
      );
    });

    test('ignores explicitly disabled toggles', () {
      final bytes = buildDocx(body: p(r('off', properties: '<w:b w:val="0"/>')));
      expect(DocxToMarkdown.convert(bytes), 'off');
    });

    test('keeps emphasis inside surrounding whitespace', () {
      final bytes = buildDocx(
        body: p(r('a') + r(' spaced ', properties: '<w:b/>') + r('b')),
      );
      expect(DocxToMarkdown.convert(bytes), 'a **spaced** b');
    });

    test('converts hyperlinks via relationships', () {
      final bytes = buildDocx(
        body: p('<w:hyperlink r:id="rId1">${r('site')}</w:hyperlink>'),
        relationships:
            '<Relationship Id="rId1" Target="https://example.com" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink"/>',
      );
      expect(DocxToMarkdown.convert(bytes), '[site](https://example.com)');
    });

    test('hyperlink without relationship degrades to plain text', () {
      final bytes = buildDocx(
        body: p('<w:hyperlink r:id="rId9">${r('site')}</w:hyperlink>'),
      );
      expect(DocxToMarkdown.convert(bytes), 'site');
    });

    test('converts line breaks and tabs inside runs', () {
      final bytes = buildDocx(
        body: p('<w:r><w:t>a</w:t><w:br/><w:t>b</w:t><w:tab/><w:t>c</w:t></w:r>'),
      );
      expect(DocxToMarkdown.convert(bytes), 'a\nb\tc');
    });

    const bulletNumbering =
        '<w:abstractNum w:abstractNumId="0">'
        '<w:lvl w:ilvl="0"><w:numFmt w:val="bullet"/></w:lvl>'
        '</w:abstractNum>'
        '<w:abstractNum w:abstractNumId="1">'
        '<w:lvl w:ilvl="0"><w:numFmt w:val="decimal"/></w:lvl>'
        '</w:abstractNum>'
        '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>'
        '<w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num>';

    String listItem(String text, {required String numId, int level = 0}) => p(
          r(text),
          properties:
              '<w:numPr><w:ilvl w:val="$level"/><w:numId w:val="$numId"/></w:numPr>',
        );

    test('converts bullet lists with nesting', () {
      final bytes = buildDocx(
        body: listItem('one', numId: '1') +
            listItem('one-a', numId: '1', level: 1) +
            listItem('two', numId: '1'),
        numbering: bulletNumbering,
      );
      expect(DocxToMarkdown.convert(bytes), '- one\n  - one-a\n- two');
    });

    test('converts ordered lists with incrementing ordinals', () {
      final bytes = buildDocx(
        body: listItem('first', numId: '2') +
            listItem('second', numId: '2') +
            listItem('third', numId: '2'),
        numbering: bulletNumbering,
      );
      expect(DocxToMarkdown.convert(bytes), '1. first\n2. second\n3. third');
    });

    test('ordered counters reset after the list is interrupted', () {
      final bytes = buildDocx(
        body: listItem('first', numId: '2') +
            p(r('interlude')) +
            listItem('again', numId: '2'),
        numbering: bulletNumbering,
      );
      expect(
        DocxToMarkdown.convert(bytes),
        '1. first\n\ninterlude\n\n1. again',
      );
    });

    test('numbered paragraphs without numbering.xml default to ordered', () {
      final bytes = buildDocx(
        body: listItem('a', numId: '5') + listItem('b', numId: '5'),
      );
      expect(DocxToMarkdown.convert(bytes), '1. a\n2. b');
    });

    test('converts tables with header separator and pipe escaping', () {
      String cell(String text) => '<w:tc>${p(r(text))}</w:tc>';
      final bytes = buildDocx(
        body: '<w:tbl>'
            '<w:tr>${cell('Name')}${cell('Value')}</w:tr>'
            '<w:tr>${cell('a|b')}${cell('2')}</w:tr>'
            '</w:tbl>',
      );
      expect(
        DocxToMarkdown.convert(bytes),
        '| Name | Value |\n| --- | --- |\n| a\\|b | 2 |',
      );
    });

    test('pads ragged table rows to the widest row', () {
      String cell(String text) => '<w:tc>${p(r(text))}</w:tc>';
      final bytes = buildDocx(
        body: '<w:tbl>'
            '<w:tr>${cell('A')}${cell('B')}${cell('C')}</w:tr>'
            '<w:tr>${cell('1')}</w:tr>'
            '</w:tbl>',
      );
      expect(
        DocxToMarkdown.convert(bytes),
        '| A | B | C |\n| --- | --- | --- |\n| 1 |  |  |',
      );
    });

    test('converts a mixed document end to end', () {
      final bytes = buildDocx(
        body: p(r('Doc'), properties: '<w:pStyle w:val="Heading1"/>') +
            p(r('Intro with ') + r('bold', properties: '<w:b/>') + r('.')) +
            listItem('item', numId: '1'),
        numbering: bulletNumbering,
      );
      expect(
        DocxToMarkdown.convert(bytes),
        '# Doc\n\nIntro with **bold**.\n\n- item',
      );
    });
  });
}
