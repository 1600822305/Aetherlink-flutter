import 'dart:convert';
import 'dart:typed_data';

import 'package:aetherlink_flutter/features/knowledge/data/knowledge_document_converter.dart';
import 'package:archive/archive.dart';
import 'package:docx_to_markdown/docx_to_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
