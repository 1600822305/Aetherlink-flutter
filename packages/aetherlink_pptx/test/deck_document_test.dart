import 'dart:convert';
import 'dart:typed_data';

import 'package:aetherlink_pptx/aetherlink_pptx.dart';
import 'package:test/test.dart';

// A 1×1 transparent PNG.
const String kPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

void main() {
  group('DeckDocument.parse', () {
    test('parses a minimal valid deck', () {
      final deck = DeckDocument.parse(
        jsonEncode({
          'layout': '16x9',
          'title': '测试',
          'slides': [
            {
              'background': '0F1115',
              'elements': [
                {
                  'type': 'text',
                  'x': 1,
                  'y': 1,
                  'w': 8,
                  'h': 1.5,
                  'paragraphs': [
                    {
                      'runs': [
                        {
                          'text': '标题',
                          'bold': true,
                          'size': 36,
                          'color': 'FFFFFF',
                        },
                      ],
                      'align': 'center',
                    },
                  ],
                },
              ],
            },
          ],
        }),
      );
      expect(deck.layout, DeckLayout.layout16x9);
      expect(deck.title, '测试');
      expect(deck.slides, hasLength(1));
      final text = deck.slides.first.elements.single as DeckTextElement;
      expect(text.paragraphs.single.runs.single.text, '标题');
      expect(text.paragraphs.single.runs.single.color!.value, 'FFFFFF');
    });

    test('rejects invalid JSON', () {
      expect(
        () => DeckDocument.parse('not json'),
        throwsA(isA<DeckParseException>()),
      );
    });

    test('rejects missing slides', () {
      expect(
        () => DeckDocument.parse('{"layout":"16x9"}'),
        throwsA(isA<DeckParseException>()),
      );
    });

    test('rejects unknown layout', () {
      expect(
        () => DeckDocument.parse('{"layout":"A4","slides":[{"elements":[]}]}'),
        throwsA(isA<DeckParseException>()),
      );
    });

    test('rejects 8-digit hex colors (alpha must be a separate field)', () {
      expect(() => DeckColor('00000020'), throwsA(isA<DeckParseException>()));
      expect(() => DeckColor('FF00'), throwsA(isA<DeckParseException>()));
      expect(DeckColor('#1a73e8').value, '1A73E8');
    });

    test('rejects unknown element type with an actionable message', () {
      expect(
        () => DeckDocument.parse(
          '{"slides":[{"elements":[{"type":"chart","x":0,"y":0,"w":1,"h":1}]}]}',
        ),
        throwsA(
          isA<DeckParseException>().having(
            (e) => e.message,
            'message',
            contains('slides[0].elements[0]'),
          ),
        ),
      );
    });

    test('parses shapes, images, and tables', () {
      final deck = DeckDocument.parse(
        jsonEncode({
          'slides': [
            {
              'elements': [
                {
                  'type': 'shape',
                  'shape': 'roundRect',
                  'x': 0.5,
                  'y': 0.5,
                  'w': 3,
                  'h': 2,
                  'fill': '1A73E8',
                  'fillTransparency': 30,
                  'radius': 0.1,
                },
                {
                  'type': 'image',
                  'x': 4,
                  'y': 0.5,
                  'w': 2,
                  'h': 2,
                  'data': kPngBase64,
                },
                {
                  'type': 'table',
                  'x': 0.5,
                  'y': 3,
                  'w': 6,
                  'h': 2,
                  'headerFill': '1A73E8',
                  'headerColor': 'FFFFFF',
                  'rows': [
                    ['列1', '列2'],
                    [
                      {'text': '值1'},
                      {
                        'runs': [
                          {'text': '值2', 'bold': true},
                        ],
                        'align': 'right',
                      },
                    ],
                  ],
                },
              ],
            },
          ],
        }),
      );
      final elements = deck.slides.single.elements;
      expect(elements[0], isA<DeckShapeElement>());
      expect((elements[0] as DeckShapeElement).fillTransparency, 30);
      expect(elements[1], isA<DeckImageElement>());
      final table = elements[2] as DeckTableElement;
      expect(table.rows, hasLength(2));
      expect(table.rows[1][1].runs.single.bold, isTrue);
    });

    test('rejects ragged table rows', () {
      expect(
        () => DeckDocument.parse(
          jsonEncode({
            'slides': [
              {
                'elements': [
                  {
                    'type': 'table',
                    'x': 0,
                    'y': 0,
                    'w': 4,
                    'h': 2,
                    'rows': [
                      ['a', 'b'],
                      ['c'],
                    ],
                  },
                ],
              },
            ],
          }),
        ),
        throwsA(isA<DeckParseException>()),
      );
    });

    test('rejects non-image base64 data', () {
      expect(
        () => DeckDocument.parse(
          jsonEncode({
            'slides': [
              {
                'elements': [
                  {
                    'type': 'image',
                    'x': 0,
                    'y': 0,
                    'w': 1,
                    'h': 1,
                    'data': base64Encode(utf8.encode('hello')),
                  },
                ],
              },
            ],
          }),
        ),
        throwsA(isA<DeckParseException>()),
      );
    });
  });

  group('detectImageFormat', () {
    test('detects png and jpeg, rejects others', () {
      expect(
        detectImageFormat(Uint8List.fromList(base64Decode(kPngBase64))),
        'png',
      );
      expect(
        detectImageFormat(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
        'jpeg',
      );
      expect(detectImageFormat(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });
  });
}
