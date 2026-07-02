import 'dart:convert';
import 'dart:typed_data';

import 'package:aetherlink_flutter/features/knowledge/data/knowledge_document_converter.dart';
import 'package:archive/archive.dart';
import 'package:docx_to_markdown/docx_to_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:office_to_markdown/office_to_markdown.dart';

const _wNs =
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

Uint8List buildDocx(String body) {
  final content = utf8.encode(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:document $_wNs><w:body>$body</w:body></w:document>',
  );
  final archive = Archive()
    ..addFile(ArchiveFile('word/document.xml', content.length, content));
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  group('isDocxFileName', () {
    test('matches .docx regardless of case and surrounding whitespace', () {
      expect(isDocxFileName('report.docx'), isTrue);
      expect(isDocxFileName('REPORT.DOCX '), isTrue);
      expect(isDocxFileName('/some/path/一 份 报告.docx'), isTrue);
    });

    test('rejects other extensions', () {
      expect(isDocxFileName('note.txt'), isFalse);
      expect(isDocxFileName('doc.md'), isFalse);
      expect(isDocxFileName('legacy.doc'), isFalse);
      expect(isDocxFileName('archive.docx.zip'), isFalse);
    });
  });

  group('isCloudOnlyKnowledgeFileName', () {
    test('matches cloud-only legacy rich-doc extensions regardless of case',
        () {
      expect(isCloudOnlyKnowledgeFileName('legacy.doc'), isTrue);
      expect(isCloudOnlyKnowledgeFileName('OLD.PPT '), isTrue);
      expect(isCloudOnlyKnowledgeFileName('/sheets/老表格.xls'), isTrue);
    });

    test('rejects locally-parsed and other extensions', () {
      expect(isCloudOnlyKnowledgeFileName('report.docx'), isFalse);
      expect(isCloudOnlyKnowledgeFileName('paper.pdf'), isFalse);
      expect(isCloudOnlyKnowledgeFileName('slides.pptx'), isFalse);
      expect(isCloudOnlyKnowledgeFileName('sheet.xlsx'), isFalse);
      expect(isCloudOnlyKnowledgeFileName('book.epub'), isFalse);
      expect(isCloudOnlyKnowledgeFileName('note.txt'), isFalse);
      expect(isCloudOnlyKnowledgeFileName('old.ppt.zip'), isFalse);
    });
  });

  group('isPptxFileName / isXlsxFileName / isEpubFileName', () {
    test('match their extension regardless of case and whitespace', () {
      expect(isPptxFileName('slides.pptx'), isTrue);
      expect(isPptxFileName('SLIDES.PPTX '), isTrue);
      expect(isXlsxFileName('/sheets/成绩.xlsx'), isTrue);
      expect(isEpubFileName('一本书.EPUB'), isTrue);
    });

    test('reject other extensions', () {
      expect(isPptxFileName('old.ppt'), isFalse);
      expect(isXlsxFileName('old.xls'), isFalse);
      expect(isEpubFileName('book.epub.zip'), isFalse);
    });
  });

  group('convertDocxBytesToMarkdown', () {
    test('converts a docx document to markdown off the main isolate',
        () async {
      final bytes = buildDocx(
        '<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr>'
        '<w:r><w:t>标题</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>正文 </w:t></w:r>'
        '<w:r><w:rPr><w:b/></w:rPr><w:t>加粗</w:t></w:r></w:p>',
      );
      expect(
        await convertDocxBytesToMarkdown(bytes),
        '# 标题\n\n正文 **加粗**',
      );
    });

    test('propagates DocxParseException for invalid bytes', () async {
      await expectLater(
        convertDocxBytesToMarkdown(Uint8List.fromList([0, 1, 2])),
        throwsA(isA<DocxParseException>()),
      );
    });
  });

  group('convertPptx/Xlsx/EpubBytesToMarkdown', () {
    test('converts a pptx slide to markdown off the main isolate', () async {
      const aNs =
          'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
          'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"';
      final content = utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<p:sld $aNs><p:cSld><p:spTree>'
        '<p:sp><p:nvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>'
        '<p:txBody><a:p><a:r><a:t>标题页</a:t></a:r></a:p></p:txBody></p:sp>'
        '<p:sp><p:nvSpPr><p:nvPr/></p:nvSpPr>'
        '<p:txBody><a:p><a:r><a:t>要点</a:t></a:r></a:p></p:txBody></p:sp>'
        '</p:spTree></p:cSld></p:sld>',
      );
      final archive = Archive()
        ..addFile(
          ArchiveFile('ppt/slides/slide1.xml', content.length, content),
        );
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
      expect(
        await convertPptxBytesToMarkdown(bytes),
        '## 标题页\n\n- 要点',
      );
    });

    test('propagates OfficeParseException for invalid bytes', () async {
      await expectLater(
        convertPptxBytesToMarkdown(Uint8List.fromList([0, 1, 2])),
        throwsA(isA<OfficeParseException>()),
      );
      await expectLater(
        convertXlsxBytesToMarkdown(Uint8List.fromList([0, 1, 2])),
        throwsA(isA<OfficeParseException>()),
      );
      await expectLater(
        convertEpubBytesToMarkdown(Uint8List.fromList([0, 1, 2])),
        throwsA(isA<OfficeParseException>()),
      );
    });
  });
}
