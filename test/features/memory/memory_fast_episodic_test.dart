import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/memory/domain/memory_extraction.dart';

void main() {
  group('fastEpisodicContent', () {
    test('keeps a substantive statement verbatim (whitespace collapsed)', () {
      expect(
        fastEpisodicContent('  我下周二要去  日本出差 '),
        '我下周二要去 日本出差',
      );
    });

    test('drops too-short turns (greetings/acks)', () {
      expect(fastEpisodicContent('好的'), isNull);
      expect(fastEpisodicContent('  hi '), isNull);
      expect(fastEpisodicContent('   '), isNull);
    });

    test('drops a bare question (a query, not an event)', () {
      expect(fastEpisodicContent('今天天气怎么样？'), isNull);
      expect(fastEpisodicContent('what is the capital of France?'), isNull);
    });

    test('truncates an over-long turn with an ellipsis', () {
      final long = 'a' * 500;
      final result = fastEpisodicContent(long)!;
      expect(result.endsWith('…'), isTrue);
      // 200 kept chars + the ellipsis.
      expect(result.length, 201);
    });
  });
}
