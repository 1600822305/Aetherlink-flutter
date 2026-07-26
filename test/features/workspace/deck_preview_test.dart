// PPT deck 源预览：文件名判定 + 解析成功/失败两态的渲染。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/deck_preview.dart';

void main() {
  group('isDeckSourceFileName', () {
    test('matches *.deck.json only', () {
      expect(isDeckSourceFileName('主题.deck.json'), isTrue);
      expect(isDeckSourceFileName('A.DECK.JSON'), isTrue);
      expect(isDeckSourceFileName('deck.json'), isFalse);
      expect(isDeckSourceFileName('a.json'), isFalse);
      expect(isDeckSourceFileName('a.deck.json.bak'), isFalse);
    });
  });

  group('DeckPreview', () {
    testWidgets('renders slides and text from a valid deck source', (
      tester,
    ) async {
      final source = jsonEncode({
        'layout': '16x9',
        'slides': [
          {
            'background': '0F1115',
            'elements': [
              {
                'type': 'text',
                'x': 1,
                'y': 1,
                'w': 11,
                'h': 1.5,
                'paragraphs': [
                  {
                    'runs': [
                      {'text': '预览标题', 'bold': true, 'size': 32},
                    ],
                    'align': 'center',
                  },
                ],
              },
              {
                'type': 'shape',
                'shape': 'roundRect',
                'x': 1,
                'y': 4,
                'w': 3,
                'h': 1,
                'fill': '1A73E8',
              },
            ],
          },
          {
            'elements': [
              {
                'type': 'table',
                'x': 1,
                'y': 1,
                'w': 8,
                'h': 2,
                'rows': [
                  ['表头A', '表头B'],
                  ['值1', '值2'],
                ],
              },
            ],
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DeckPreview(content: source)),
        ),
      );
      expect(find.text('预览标题'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('表头A'), findsOneWidget);
    });

    testWidgets('renders the bundled sample deck without errors', (
      tester,
    ) async {
      final source = File(
        'packages/aetherlink_pptx/test/sample_deck.json',
      ).readAsStringSync();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DeckPreview(content: source)),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DeckPreview), findsOneWidget);
    });

    testWidgets('shows a readable error for invalid deck source', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DeckPreview(content: '{"layout": "16x9"}')),
        ),
      );
      expect(find.text('deck 源无法解析'), findsOneWidget);
    });
  });
}
