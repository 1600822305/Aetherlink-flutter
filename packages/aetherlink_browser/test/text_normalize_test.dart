import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_browser/aetherlink_browser.dart';

void main() {
  test('normalizeExtractedText 压缩空行、去行尾空白、统一 CRLF', () {
    expect(
      normalizeExtractedText('a  \t\r\n\r\n\r\n\r\nb\n\nc  '),
      'a\n\nb\n\nc',
    );
  });

  test('normalizeExtractedText 保留段落间单个空行与行内空格', () {
    expect(
      normalizeExtractedText('第一段 有 空格\n\n第二段'),
      '第一段 有 空格\n\n第二段',
    );
  });
}
