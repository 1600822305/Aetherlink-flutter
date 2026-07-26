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

DeckDocument _deckSlides(List<Map<String, Object?>> slides) =>
    DeckDocument.parse(jsonEncode({'layout': '16x9', 'slides': slides}));

Map<String, Object?> _layoutSlide(
  String type,
  List<Map<String, Object?>> cards,
) => {
  'layout': {'type': type, 'title': '标题', 'cards': cards},
};

Map<String, Object?> _textCard() => {
  'type': 'text',
  'title': '小标题',
  'body': ['这是一段足够长的卡片正文内容，用来避免触发内容太薄的警告'],
};

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
                  {'text': '这是一页内容充实的幻灯片标题，配有足够的支撑文字说明', 'size': 32},
                ],
              },
            ],
          },
        ]),
      );
      expect(issues, isEmpty);
    });

    test('over_density 豁免布局引擎生成的页（grid 卡片展开元素多是引擎行为）', () {
      final deck = _deckSlides([
        _layoutSlide('grid', [
          for (var i = 0; i < 4; i++)
            {'type': 'data', 'value': '${i + 10}%', 'label': '指标$i', 'desc': '同比提升'},
        ]),
      ]);
      expect(
        deck.slides.first.elements.length,
        greaterThan(kQaMaxElementsPerSlide),
        reason: '前提：卡片展开后的原子元素数超过阈值，才能验证豁免',
      );
      final issues = runDeckQa(deck);
      expect(issues.map((i) => i.rule), isNot(contains('over_density')));
    });

    test('flags out-of-bounds elements as errors', () {
      final issues = runDeckQa(
        _deck([
          {'type': 'shape', 'shape': 'rect', 'x': 12, 'y': 1, 'w': 3, 'h': 1},
        ]),
      );
      final issue = issues.singleWhere((i) => i.rule == 'out_of_bounds');
      expect(issue.severity, DeckQaSeverity.error);
      expect(issue.toJson()['slide'], 1);
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

  group('失败模式规则', () {
    test('underfill 升级：内容页文字太少且无图表/表格/图片', () {
      final thin = runDeckQa(
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
      expect(thin.map((i) => i.rule), contains('underfill'));

      final withChart = runDeckQa(
        _deck([
          {
            'type': 'text',
            'x': 1,
            'y': 0.5,
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
          {
            'type': 'chart',
            'chart': 'bar',
            'x': 1,
            'y': 2,
            'w': 6,
            'h': 4,
            'categories': ['Q1', 'Q2'],
            'series': [
              {
                'name': '营收',
                'values': [1, 2],
              },
            ],
          },
        ]),
      );
      expect(withChart.map((i) => i.rule), isNot(contains('underfill')));
    });

    test('support_collapse：多卡内容页卡片类型单一', () {
      final monotype = runDeckQa(
        _deckSlides([
          _layoutSlide('grid', [
            _textCard(),
            _textCard(),
            _textCard(),
            _textCard(),
          ]),
        ]),
      );
      expect(monotype.map((i) => i.rule), contains('support_collapse'));

      final mixed = runDeckQa(
        _deckSlides([
          _layoutSlide('grid', [
            _textCard(),
            {'type': 'data', 'value': '87%', 'label': '增长率'},
            {
              'type': 'list',
              'title': '要点',
              'items': ['第一条要点说明', '第二条要点说明'],
            },
            _textCard(),
          ]),
        ]),
      );
      expect(mixed.map((i) => i.rule), isNot(contains('support_collapse')));

      // split 本身就是 2 卡布局，不设卡数下限。
      final split = runDeckQa(
        _deckSlides([
          _layoutSlide('split', [
            _textCard(),
            {'type': 'data', 'value': '3x', 'label': '提速'},
          ]),
        ]),
      );
      expect(split.map((i) => i.rule), isNot(contains('support_collapse')));
    });

    test('anchor_overexpansion：手写坐标页单元素霸占画布', () {
      final issues = runDeckQa(
        _deck([
          {
            'type': 'shape',
            'shape': 'rect',
            'x': 0.5,
            'y': 0.5,
            'w': 11,
            'h': 6,
            'fill': '1A73E8',
          },
          {
            'type': 'text',
            'x': 1,
            'y': 1,
            'w': 10,
            'h': 1,
            'paragraphs': [
              {
                'runs': [
                  {'text': '这是一页有足够文字支撑的幻灯片标题内容说明', 'size': 32},
                ],
              },
            ],
          },
          {
            'type': 'shape',
            'shape': 'rect',
            'x': 1,
            'y': 6.6,
            'w': 2,
            'h': 0.5,
            'fill': '00E5FF',
          },
        ]),
      );
      expect(issues.map((i) => i.rule), contains('anchor_overexpansion'));
    });

    test('deck_rhythm_clone：连续三页同一内容布局', () {
      final cards = [
        _textCard(),
        {'type': 'data', 'value': '87%', 'label': '增长率'},
        {
          'type': 'list',
          'title': '要点',
          'items': ['第一条要点说明', '第二条要点说明'],
        },
        _textCard(),
      ];
      final cloned = runDeckQa(
        _deckSlides([
          _layoutSlide('grid', cards),
          _layoutSlide('grid', cards),
          _layoutSlide('grid', cards),
        ]),
      );
      expect(cloned.where((i) => i.rule == 'deck_rhythm_clone').length, 1);

      final varied = runDeckQa(
        _deckSlides([
          _layoutSlide('grid', cards),
          _layoutSlide('columns', cards.sublist(0, 3)),
          _layoutSlide('grid', cards),
        ]),
      );
      expect(varied.map((i) => i.rule), isNot(contains('deck_rhythm_clone')));
    });
  });
}
