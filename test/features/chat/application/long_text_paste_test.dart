import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/chat/application/long_text_paste.dart';

void main() {
  group('convertPastedTextToAttachment', () {
    const threshold = 1500;

    test('returns null when 长文本粘贴为文件 is off', () {
      final result = convertPastedTextToAttachment(
        text: 'a' * (threshold + 100),
        enabled: false,
        threshold: threshold,
      );
      expect(result, isNull);
    });

    test('returns null at the threshold (strictly greater is required)', () {
      final result = convertPastedTextToAttachment(
        text: 'a' * threshold,
        enabled: true,
        threshold: threshold,
      );
      expect(result, isNull);
    });

    test('converts when longer than the threshold', () {
      final text = 'a' * (threshold + 1);
      final result = convertPastedTextToAttachment(
        text: text,
        enabled: true,
        threshold: threshold,
        now: DateTime.utc(2026, 6, 20, 6, 12, 5),
      );
      expect(result, isNotNull);
      expect(result!.text, text);
      expect(result.mimeType, 'text/plain');
      expect(result.size, text.length);
      expect(result.name, '粘贴的文本_20260620T061205.txt');
    });

    test('size is the UTF-8 byte length, not the char count', () {
      final text = '中文$threshold'.padRight(threshold + 1, '内');
      final result = convertPastedTextToAttachment(
        text: text,
        enabled: true,
        threshold: threshold,
      );
      expect(result, isNotNull);
      expect(result!.size, greaterThan(text.length));
    });
  });

  group('detectInsertion', () {
    test('returns null when text did not grow', () {
      expect(detectInsertion('hello', 'hello'), isNull);
      expect(detectInsertion('hello', 'hell'), isNull);
    });

    test('finds a run appended at the caret end', () {
      final r = detectInsertion('hi ', 'hi there');
      expect(r, isNotNull);
      expect(r!.inserted, 'there');
      expect(r.restored, 'hi ');
      expect(r.caret, 3);
    });

    test('finds a run pasted in the middle, keeping prefix and suffix', () {
      final r = detectInsertion('ab', 'aXYZb');
      expect(r, isNotNull);
      expect(r!.inserted, 'XYZ');
      expect(r.restored, 'ab');
      expect(r.caret, 1);
    });

    test('drops a replaced selection from the restored text', () {
      // "aSELb" with "SEL" selected, pasted the longer "WXYZ" → "aWXYZb".
      final r = detectInsertion('aSELb', 'aWXYZb');
      expect(r, isNotNull);
      expect(r!.inserted, 'WXYZ');
      expect(r.restored, 'ab');
      expect(r.caret, 1);
    });
  });

  test('pasteFileTimestamp formats as YYYYMMDDTHHMMSS in UTC', () {
    expect(
      pasteFileTimestamp(DateTime.utc(2026, 1, 2, 3, 4, 5)),
      '20260102T030405',
    );
  });
}
