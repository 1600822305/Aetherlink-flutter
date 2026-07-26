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
  _infographicSelfCheckTests();

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

/// 引擎自产元素必须过得了自己的 QA：6 种 infographic × 全部内置 style
/// （+ 无 style、+ 大字号自定义 style）各跑一次 check，不允许任何 error。
void _infographicSelfCheckTests() {
  const kindPayloads = <String, Map<String, Object?>>{
    // value 62.5 → "62.5%" 5 字符，是 QA 宽度启发式下的最长常见形态。
    'progress': {'x': 1, 'y': 2, 'w': 5, 'h': 1, 'value': 62.5, 'label': '完成度'},
    'kpi': {'x': 1, 'y': 2, 'w': 3.2, 'h': 1.7, 'value': '1,234', 'label': '月活', 'trend': '+12%'},
    'waffle': {'x': 1, 'y': 1.5, 'w': 3.6, 'h': 3.6, 'value': 45, 'label': '覆盖率'},
    'timeline': {
      'x': 1, 'y': 2, 'w': 10, 'h': 2.4,
      'steps': [
        {'label': '调研', 'desc': '用户访谈'},
        {'label': '设计', 'desc': '方案评审'},
        {'label': '开发', 'desc': '两周迭代'},
        {'label': '上线', 'desc': '灰度发布'},
      ],
    },
    'funnel': {
      'x': 1, 'y': 1.5, 'w': 5, 'h': 3.6,
      'stages': [
        {'label': '曝光', 'value': 100},
        {'label': '点击', 'value': 40},
        {'label': '转化', 'value': 12},
      ],
    },
    'gauge': {'x': 1, 'y': 1.5, 'w': 3.6, 'h': 2.4, 'value': 72, 'label': '达成率'},
  };

  group('infographic 自产元素 QA 自检', () {
    final styleVariants = <String, Object?>{
      '无 style': null,
      for (final id in kBuiltinDeckStyles.keys) 'style=$id': id,
      '自定义大字号': {
        'id': 'big', 'name': '大字号', 'category': 'light_clean',
        'background': 'FFFFFF', 'cardFill': 'F5F7FA',
        'textPrimary': '111111', 'textSecondary': '555555',
        'accents': ['4472C4'],
        'cardTitleSize': 28, 'bodySize': 16,
      },
    };
    for (final MapEntry(key: styleName, value: style)
        in styleVariants.entries) {
      for (final MapEntry(key: kind, value: payload)
          in kindPayloads.entries) {
        test('$kind / $styleName 无 error', () {
          final deck = DeckDocument.parse(
            jsonEncode({
              'layout': '16x9',
              'style': ?style,
              'slides': [
                {
                  'elements': [
                    {'type': 'infographic', 'kind': kind, ...payload},
                  ],
                },
              ],
            }),
          );
          final errors = runDeckQa(deck)
              .where((i) => i.severity == DeckQaSeverity.error)
              .toList();
          expect(
            errors.map((i) => '${i.rule}@${i.elementIndex}: ${i.message}'),
            isEmpty,
          );
        });
      }
    }

    test('小框降级：矮 kpi / 窄 progress / 浅 gauge 均无 error 且框合法', () {
      final deck = DeckDocument.parse(
        jsonEncode({
          'layout': '16x9',
          'slides': [
            {
              'elements': [
                // 矮 kpi（带 trend）：旧实现产出负高度值框 + 必然 text_overflow。
                {
                  'type': 'infographic', 'kind': 'kpi',
                  'x': 0.5, 'y': 0.5, 'w': 2.9, 'h': 1.2,
                  'value': '1,234', 'label': '月活', 'trend': '+12%',
                },
                // 窄 progress：旧实现百分比框 x 越界（out_of_bounds）。
                {
                  'type': 'infographic', 'kind': 'progress',
                  'x': 0.5, 'y': 2.2, 'w': 1.2, 'h': 0.8, 'value': 62.5,
                },
                // 浅框 gauge 顶着上缘：旧实现 topY 为负。
                {
                  'type': 'infographic', 'kind': 'gauge',
                  'x': 4, 'y': 0.1, 'w': 6, 'h': 1.5, 'value': 72,
                },
              ],
            },
          ],
        }),
      );
      final errors = runDeckQa(
        deck,
      ).where((i) => i.severity == DeckQaSeverity.error);
      expect(errors.map((i) => '${i.rule}: ${i.message}'), isEmpty);
      for (final el in deck.slides.single.elements) {
        expect(el.frame.w, greaterThan(0));
        expect(el.frame.h, greaterThan(0));
        expect(el.frame.y, greaterThanOrEqualTo(0));
        expect(el.frame.x, greaterThanOrEqualTo(0));
      }
    });

    test('progress 槽宽与值无关：99% 的填充必须比 100% 短', () {
      DeckDocument deckFor(num v) => DeckDocument.parse(
        jsonEncode({
          'layout': '16x9',
          'slides': [
            {
              'elements': [
                {
                  'type': 'infographic', 'kind': 'progress',
                  'x': 1, 'y': 2, 'w': 5, 'h': 1, 'value': v,
                },
              ],
            },
          ],
        }),
      );
      double fillW(DeckDocument d) {
        final shapes = d.slides.single.elements
            .whereType<DeckShapeElement>()
            .toList();
        // 元素顺序：底槽、填充。填充是第二个 shape。
        return shapes[1].frame.w;
      }

      double trackW(DeckDocument d) => d.slides.single.elements
          .whereType<DeckShapeElement>()
          .first
          .frame
          .w;

      expect(trackW(deckFor(7)), trackW(deckFor(62.5)));
      expect(fillW(deckFor(99)), lessThan(fillW(deckFor(100))));
    });

    test('layout 卡片路径（大字号 style）无 error', () {
      final bigStyle = {
        'id': 'big', 'name': '大字号', 'category': 'light_clean',
        'background': 'FFFFFF', 'cardFill': 'F5F7FA',
        'textPrimary': '111111', 'textSecondary': '555555',
        'accents': ['4472C4', 'ED7D31', 'FFC000', '70AD47', '5B9BD5'],
        'cardTitleSize': 28, 'bodySize': 16,
      };
      final deck = DeckDocument.parse(
        jsonEncode({
          'layout': '16x9',
          'style': bigStyle,
          'slides': [
            {
              'layout': {
                'type': 'cover',
                'title': '一个足够长的封面主标题用来验证换行与缩放逻辑',
                'subtitle': '副标题也写得比较长一些，覆盖两行的估算路径，不至于太短',
                'meta': '2026 年 7 月',
              },
            },
            {
              'layout': {
                'type': 'split', 'title': '双栏标题',
                'cards': [
                  {
                    'type': 'text', 'title': '带标题的文本卡',
                    'body': ['这是一段足够长的卡片正文内容，用来避免触发内容太薄的警告'],
                  },
                  {
                    'type': 'list', 'title': '带标题的列表卡',
                    'items': ['第一条内容', '第二条内容', '第三条内容'],
                  },
                ],
              },
            },
            {
              'layout': {
                'type': 'columns', 'title': '三列数据',
                'cards': [
                  {'type': 'data', 'value': '12,345,678', 'label': '总量'},
                  {'type': 'data', 'value': '98.5%', 'label': '达成率'},
                  {'type': 'data', 'value': '1,234'},
                ],
              },
            },
            {
              'layout': {
                'type': 'hero', 'title': '主次布局',
                'cards': [
                  {
                    'type': 'text', 'title': '主卡',
                    'body': ['主卡正文内容，长度适中，用于占位与字数检查通过'],
                  },
                  {'type': 'big_number', 'value': '1,234万+', 'label': '累计'},
                  {'type': 'big_number', 'value': '99.99%'},
                  {'type': 'big_number', 'value': '42'},
                  {'type': 'big_number', 'value': '7×24', 'label': '服务'},
                ],
              },
            },
            {
              'layout': {
                'type': 'toc',
                'items': ['市场与竞品分析', '产品方案', '商业模式与定价策略', '路线图'],
              },
            },
            {
              'layout': {
                'type': 'end', 'title': '谢谢观看',
                'items': ['联系邮箱：hello@example.com', '一条比较长的补充说明文字，验证结尾条目的宽度估算'],
                'meta': 'AetherLink',
              },
            },
          ],
        }),
      );
      final errors = runDeckQa(
        deck,
      ).where((i) => i.severity == DeckQaSeverity.error).toList();
      expect(
        errors.map((i) => 's${i.slideIndex} ${i.rule}: ${i.message}'),
        isEmpty,
      );
    });

    test('贴底放置：kpi/progress/gauge/timeline 元素不越出画布', () {
      final deck = DeckDocument.parse(
        jsonEncode({
          'layout': '16x9',
          'slides': [
            {
              'elements': [
                {
                  'type': 'infographic', 'kind': 'kpi',
                  'x': 0.5, 'y': 6.2, 'w': 2.9, 'h': 1.2,
                  'value': '1,234', 'trend': '+12%',
                },
                // h=0.5 + label：矮框自动丢 label，条不越出容器/画布。
                {
                  'type': 'infographic', 'kind': 'progress',
                  'x': 4, 'y': 6.9, 'w': 4, 'h': 0.5,
                  'value': 62.5, 'label': '进度',
                },
                // 下半屏 gauge：pie 整圆边界盒（含不可见下半圆）不出画布。
                {
                  'type': 'infographic', 'kind': 'gauge',
                  'x': 9, 'y': 4.8, 'w': 3.5, 'h': 2.4, 'value': 72,
                },
                // 贴底 timeline：圆点/轴线不越界。
                {
                  'type': 'infographic', 'kind': 'timeline',
                  'x': 0.5, 'y': 6.0, 'w': 8, 'h': 1.0,
                  'steps': ['一', '二', '三'],
                },
              ],
            },
          ],
        }),
      );
      final errors = runDeckQa(
        deck,
      ).where((i) => i.severity == DeckQaSeverity.error);
      expect(errors.map((i) => '${i.rule}: ${i.message}'), isEmpty);
      for (final el in deck.slides.single.elements) {
        expect(el.frame.w, greaterThan(0));
        expect(el.frame.h, greaterThan(0));
        expect(el.frame.y + el.frame.h, lessThanOrEqualTo(7.51));
      }
    });

    test('矮 timeline 丢 desc 且无负高度框；过密 funnel/process 解析期报错', () {
      final deck = DeckDocument.parse(
        jsonEncode({
          'layout': '16x9',
          'slides': [
            {
              'elements': [
                {
                  'type': 'infographic', 'kind': 'timeline',
                  'x': 0.5, 'y': 1, 'w': 10, 'h': 0.9,
                  'steps': [
                    {'label': '一', 'desc': '这段说明在矮框里应被丢弃'},
                    {'label': '二', 'desc': '同上'},
                  ],
                },
              ],
            },
          ],
        }),
      );
      for (final el in deck.slides.single.elements) {
        expect(el.frame.h, greaterThan(0), reason: '不允许负高度框');
      }
      expect(
        runDeckQa(deck).where((i) => i.severity == DeckQaSeverity.error),
        isEmpty,
      );

      expect(
        () => DeckDocument.parse(
          jsonEncode({
            'layout': '16x9',
            'slides': [
              {
                'elements': [
                  {
                    'type': 'infographic', 'kind': 'funnel',
                    'x': 0.5, 'y': 1, 'w': 8, 'h': 1.5,
                    'stages': [
                      for (var i = 0; i < 8; i++)
                        {'label': '层$i', 'value': 100 - i * 10},
                    ],
                  },
                ],
              },
            ],
          }),
        ),
        throwsA(isA<DeckParseException>()),
      );
      expect(
        () => DeckDocument.parse(
          jsonEncode({
            'layout': '16x9',
            'slides': [
              {
                'layout': {
                  'type': 'grid', 'title': '标题',
                  'cards': [
                    for (var c = 0; c < 5; c++)
                      {
                        'type': 'text', 'title': '卡$c',
                        'body': ['占位内容足够长避免其他告警干扰'],
                      },
                    {
                      'type': 'process', 'title': '过密流程',
                      'steps': [for (var i = 0; i < 12; i++) '步骤$i'],
                    },
                  ],
                },
              },
            ],
          }),
        ),
        throwsA(isA<DeckParseException>()),
      );
    });

    test('密集内容卡片（list/text/process/data desc/big_number 标签/长 tag）无 error', () {
      final deck = DeckDocument.parse(
        jsonEncode({
          'layout': '16x9',
          'slides': [
            {
              'layout': {
                'type': 'grid', 'title': '密集内容',
                'cards': [
                  {
                    'type': 'list', 'title': '七条列表',
                    'items': [for (var i = 1; i <= 7; i++) '列表条目内容$i'],
                  },
                  {
                    'type': 'text', 'title': '长正文',
                    'body': [List.filled(18, '很长的正文内容').join()],
                  },
                  {
                    'type': 'process', 'title': '五步流程',
                    'steps': [for (var i = 1; i <= 5; i++) '这是第$i步的比较长的说明文字'],
                  },
                  {
                    'type': 'data', 'value': '42%', 'label': '占比',
                    'desc': List.filled(14, '详细说明文字').join(),
                  },
                  {
                    'type': 'big_number', 'value': '1,234万+',
                    'label': List.filled(8, '很长标签').join(),
                  },
                  {
                    'type': 'tags', 'title': '标签',
                    'tags': ['短', '这是一个特别特别特别特别特别特别长的标签文本', '中等标签'],
                  },
                ],
              },
            },
          ],
        }),
      );
      final errors = runDeckQa(
        deck,
      ).where((i) => i.severity == DeckQaSeverity.error).toList();
      expect(
        errors.map((i) => 'e${i.elementIndex} ${i.rule}: ${i.message}'),
        isEmpty,
      );
      // 长 tag 药丸被钳在画布内。
      for (final el in deck.slides.single.elements) {
        expect(el.frame.x + el.frame.w, lessThanOrEqualTo(13.34));
      }
    });

    test('99.95 显示为 99.9% 而不是进位成 100.0%', () {
      final deck = DeckDocument.parse(
        jsonEncode({
          'layout': '16x9',
          'slides': [
            {
              'elements': [
                {
                  'type': 'infographic', 'kind': 'progress',
                  'x': 1, 'y': 2, 'w': 5, 'h': 1, 'value': 99.95,
                },
              ],
            },
          ],
        }),
      );
      final texts = [
        for (final el in deck.slides.single.elements)
          if (el is DeckTextElement)
            for (final para in el.paragraphs)
              for (final run in para.runs) run.text,
      ];
      expect(texts, contains('99.9%'));
      expect(texts, isNot(contains('100.0%')));
    });

    test('progress 边界值（100 / 0 / 0.5 / 99.9）均无 text_overflow', () {
      for (final value in [100, 0, 0.5, 99.9]) {
        final deck = DeckDocument.parse(
          jsonEncode({
            'layout': '16x9',
            'slides': [
              {
                'elements': [
                  {
                    'type': 'infographic', 'kind': 'progress',
                    'x': 1, 'y': 2, 'w': 5, 'h': 1,
                    'value': value, 'label': '进度',
                  },
                ],
              },
            ],
          }),
        );
        expect(
          runDeckQa(deck).where((i) => i.rule == 'text_overflow'),
          isEmpty,
          reason: 'value=$value',
        );
      }
    });
  });
}
