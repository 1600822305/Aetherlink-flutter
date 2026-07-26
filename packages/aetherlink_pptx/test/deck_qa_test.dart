import 'dart:convert';

import 'package:aetherlink_pptx/aetherlink_pptx.dart';
import 'package:test/test.dart';

DeckDocument _deck(List<Map<String, Object?>> elements) => DeckDocument.parse(
  jsonEncode({
    'layout': '16x9',
    'slides': [
      {'elements': elements},
    ],
  }),
);

void main() {
  group('runDeckQa', () {
    test('passes a well-formed slide', () {
      final issues = runDeckQa(
        _deck([
          {
            'type': 'text',
            'x': 1,
            'y': 1,
            'w': 10,
            'h': 1,
            'paragraphs': [
              {
                'runs': [
                  {'text': '标题', 'size': 32},
                ],
              },
            ],
          },
        ]),
      );
      expect(issues, isEmpty);
    });

    test('flags out-of-bounds elements as errors', () {
      final issues = runDeckQa(
        _deck([
          {'type': 'shape', 'shape': 'rect', 'x': 12, 'y': 1, 'w': 3, 'h': 1},
        ]),
      );
      expect(issues.single.rule, 'out_of_bounds');
      expect(issues.single.severity, DeckQaSeverity.error);
      expect(issues.single.toJson()['slide'], 1);
    });

    test('flags estimated text overflow as an error', () {
      final issues = runDeckQa(
        _deck([
          {
            'type': 'text',
            'x': 1,
            'y': 1,
            'w': 3,
            'h': 0.4,
            'paragraphs': [
              {
                'runs': [
                  {'text': '这是一段非常非常长的文字' * 8, 'size': 24},
                ],
              },
            ],
          },
        ]),
      );
      expect(issues.map((i) => i.rule), contains('text_overflow'));
    });

    test('warns on tiny fonts and empty slides', () {
      final tiny = runDeckQa(
        _deck([
          {
            'type': 'text',
            'x': 1,
            'y': 1,
            'w': 10,
            'h': 1,
            'paragraphs': [
              {
                'runs': [
                  {'text': '注脚', 'size': 8},
                ],
              },
            ],
          },
        ]),
      );
      expect(tiny.map((i) => i.rule), contains('font_too_small'));

      final empty = runDeckQa(_deck([]));
      expect(empty.single.rule, 'underfill');
      expect(empty.single.severity, DeckQaSeverity.warning);
    });
  });
}
