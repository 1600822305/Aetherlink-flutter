import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:office_to_markdown/office_to_markdown.dart';
import 'package:test/test.dart';

Uint8List buildZip(Map<String, String> files) {
  final archive = Archive();
  files.forEach((path, content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  });
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

const _aNs = 'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
    'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"';

String slideXml(String shapes) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<p:sld $_aNs><p:cSld><p:spTree>$shapes</p:spTree></p:cSld></p:sld>';

String sp(String paragraphs, {String? placeholder}) =>
    '<p:sp><p:nvSpPr><p:nvPr>'
    '${placeholder == null ? '' : '<p:ph type="$placeholder"/>'}'
    '</p:nvPr></p:nvSpPr><p:txBody>$paragraphs</p:txBody></p:sp>';

String ap(String text, {String? properties}) =>
    '<a:p>${properties ?? ''}<a:r><a:t>$text</a:t></a:r></a:p>';

void main() {
  group('PptxToMarkdown.convert', () {
    test('throws on invalid zip / missing slides', () {
      expect(
        () => PptxToMarkdown.convert(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<OfficeParseException>()),
      );
      expect(
        () => PptxToMarkdown.convert(buildZip({'other.txt': 'hi'})),
        throwsA(isA<OfficeParseException>()),
      );
    });

    test('renders titles, bullets and slide order', () {
      final bytes = buildZip({
        // slide10 before slide2 in the archive — output must sort numerically.
        'ppt/slides/slide10.xml': slideXml(
          sp(ap('Last slide'), placeholder: 'title'),
        ),
        'ppt/slides/slide2.xml': slideXml(
          sp(ap('Agenda'), placeholder: 'title') +
              sp(
                ap('First point') +
                    ap('Nested point', properties: '<a:pPr lvl="1"/>'),
              ),
        ),
        'ppt/slides/slide1.xml': slideXml(
          sp(ap('Cover'), placeholder: 'ctrTitle'),
        ),
      });
      expect(
        PptxToMarkdown.convert(bytes),
        '## Cover\n\n'
        '## Agenda\n\n- First point\n  - Nested point\n\n'
        '## Last slide',
      );
    });

    test('untitled slide with body falls back to Slide N; empty slides are '
        'skipped', () {
      final bytes = buildZip({
        'ppt/slides/slide1.xml': slideXml(sp(ap('Only body'))),
        'ppt/slides/slide2.xml': slideXml(''),
      });
      expect(PptxToMarkdown.convert(bytes), '## Slide 1\n\n- Only body');
    });

    test('buNone paragraphs render without bullet; tables become Markdown '
        'tables', () {
      final bytes = buildZip({
        'ppt/slides/slide1.xml': slideXml(
          '${sp(ap('Plain text', properties: '<a:pPr><a:buNone/></a:pPr>'))}'
          '<p:graphicFrame><a:graphic><a:graphicData><a:tbl>'
          '<a:tr><a:tc><a:txBody>${ap('H1')}</a:txBody></a:tc>'
          '<a:tc><a:txBody>${ap('H2')}</a:txBody></a:tc></a:tr>'
          '<a:tr><a:tc><a:txBody>${ap('a')}</a:txBody></a:tc>'
          '<a:tc><a:txBody>${ap('b')}</a:txBody></a:tc></a:tr>'
          '</a:tbl></a:graphicData></a:graphic></p:graphicFrame>',
        ),
      });
      expect(
        PptxToMarkdown.convert(bytes),
        '## Slide 1\n\n'
        'Plain text\n\n'
        '| H1 | H2 |\n| --- | --- |\n| a | b |',
      );
    });
  });

  group('XlsxToMarkdown.convert', () {
    const ssNs =
        'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';

    test('throws on invalid zip / missing workbook', () {
      expect(
        () => XlsxToMarkdown.convert(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<OfficeParseException>()),
      );
      expect(
        () => XlsxToMarkdown.convert(buildZip({'other.txt': 'hi'})),
        throwsA(isA<OfficeParseException>()),
      );
    });

    test('renders sheets as Markdown tables with shared strings, gaps and '
        'booleans', () {
      final bytes = buildZip({
        'xl/workbook.xml':
            '<workbook $ssNs><sheets>'
            '<sheet name="成绩" sheetId="1" r:id="rId1"/>'
            '</sheets></workbook>',
        'xl/_rels/workbook.xml.rels':
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Target="worksheets/sheet1.xml"/>'
            '</Relationships>',
        'xl/sharedStrings.xml':
            '<sst $ssNs><si><t>姓名</t></si>'
            '<si><r><t>分</t></r><r><t>数</t></r></si></sst>',
        'xl/worksheets/sheet1.xml':
            '<worksheet $ssNs><sheetData>'
            '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c>'
            '<c r="C1" t="inlineStr"><is><t>及格</t></is></c></row>'
            // B2 skipped → renders as an empty cell.
            '<row r="2"><c r="A2" t="str"><v>Ada</v></c>'
            '<c r="C2" t="b"><v>1</v></c></row>'
            '</sheetData></worksheet>',
      });
      expect(
        XlsxToMarkdown.convert(bytes),
        '## 成绩\n\n'
        '| 姓名 | 分数 | 及格 |\n| --- | --- | --- |\n| Ada |  | TRUE |',
      );
    });

    test('empty sheets are skipped', () {
      final bytes = buildZip({
        'xl/workbook.xml':
            '<workbook $ssNs><sheets>'
            '<sheet name="空表" sheetId="1" r:id="rId1"/>'
            '</sheets></workbook>',
        'xl/worksheets/sheet1.xml':
            '<worksheet $ssNs><sheetData/></worksheet>',
      });
      expect(XlsxToMarkdown.convert(bytes), '');
    });
  });

  group('EpubToMarkdown.convert', () {
    const container =
        '<?xml version="1.0"?>'
        '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
        '<rootfiles><rootfile full-path="OEBPS/content.opf" '
        'media-type="application/oebps-package+xml"/></rootfiles></container>';

    String opf({required String manifest, required String spine}) =>
        '<?xml version="1.0"?>'
        '<package xmlns="http://www.idpf.org/2007/opf" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<metadata><dc:title>示例书</dc:title></metadata>'
        '<manifest>$manifest</manifest><spine>$spine</spine></package>';

    test('throws on invalid zip / missing container', () {
      expect(
        () => EpubToMarkdown.convert(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<OfficeParseException>()),
      );
      expect(
        () => EpubToMarkdown.convert(buildZip({'other.txt': 'hi'})),
        throwsA(isA<OfficeParseException>()),
      );
    });

    test('walks container → OPF → spine and converts XHTML in spine order', () {
      final bytes = buildZip({
        'META-INF/container.xml': container,
        'OEBPS/content.opf': opf(
          manifest:
              '<item id="c1" href="ch1.xhtml" media-type="application/xhtml+xml"/>'
              '<item id="c2" href="text/ch2.xhtml" media-type="application/xhtml+xml"/>',
          spine: '<itemref idref="c2"/><itemref idref="c1"/>',
        ),
        'OEBPS/ch1.xhtml':
            '<html><head><style>p{}</style></head>'
            '<body><h1>第一章</h1><p>正文 &amp; <b>重点</b></p></body></html>',
        'OEBPS/text/ch2.xhtml': '<html><body><p>序言</p></body></html>',
      });
      expect(
        EpubToMarkdown.convert(bytes),
        '# 示例书\n\n序言\n\n# 第一章\n\n正文 & **重点**',
      );
    });
  });
}
