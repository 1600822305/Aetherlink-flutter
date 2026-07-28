// deck 单页离屏截图：无窗口渲染管线产出合法 PNG，尺寸按画布比例。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_pptx/aetherlink_pptx.dart';

import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/deck_snapshot.dart';

const List<int> kPngMagic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

void main() {
  DeckDocument deck() => DeckDocument.parse(
    jsonEncode({
      'layout': '16x9',
      'style': 'dark_tech',
      'slides': [
        {
          'layout': {'type': 'cover', 'title': '视觉自检', 'subtitle': '离屏渲染'},
        },
        {
          'layout': {
            'type': 'split',
            'title': '两栏',
            'cards': [
              {
                'type': 'text',
                'title': '左',
                'body': ['内容 A'],
              },
              {'type': 'data', 'value': '87%', 'label': '增长'},
            ],
          },
        },
      ],
    }),
  );

  testWidgets('renderDeckSlidePng 产出合法 PNG', (tester) async {
    final png = await tester.runAsync(
      () => renderDeckSlidePng(deck(), 0, width: 640),
    );
    expect(png, isNotNull);
    expect(png!.length, greaterThan(kPngMagic.length));
    expect(png.sublist(0, kPngMagic.length), kPngMagic);
  });

  testWidgets('每页独立渲染，第二页同样成功', (tester) async {
    final png = await tester.runAsync(
      () => renderDeckSlidePng(deck(), 1, width: 640),
    );
    expect(png!.sublist(0, kPngMagic.length), kPngMagic);
  });
}
