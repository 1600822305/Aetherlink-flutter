import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf_to_markdown/pdf_to_markdown.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:test/test.dart';

/// 手工构造一个带文本层的最小单页 PDF（Helvetica，两行文本）。
Uint8List buildMinimalPdf(List<String> lines) {
  final content = StringBuffer('BT /F1 12 Tf 72 720 Td 14 TL\n');
  for (var i = 0; i < lines.length; i++) {
    if (i > 0) content.write('T*\n');
    final escaped = lines[i].replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');
    content.write('($escaped) Tj\n');
  }
  content.write('ET');
  final stream = content.toString();

  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${stream.length} >>\nstream\n$stream\nendstream',
  ];

  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(buffer.length);
    buffer.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xrefOffset = buffer.length;
  buffer.write('xref\n0 ${objects.length + 1}\n');
  buffer.write('0000000000 65535 f \n');
  for (final offset in offsets) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n',
  );
  return Uint8List.fromList(latin1.encode(buffer.toString()));
}

void main() {
  setUpAll(() async {
    await pdfrxInitialize();
  });

  group('PdfToMarkdown.convert', () {
    test('extracts and reflows the text layer', () async {
      final bytes = buildMinimalPdf(['Hello from the PDF text', 'layer of Aetherlink.']);
      final result = await PdfToMarkdown.convert(bytes);
      expect(result, 'Hello from the PDF text layer of Aetherlink.');
    });

    test('throws PdfParseException for invalid bytes', () async {
      final bytes = Uint8List.fromList(utf8.encode('not a pdf at all'));
      expect(() => PdfToMarkdown.convert(bytes), throwsA(isA<PdfParseException>()));
    });
  });
}
