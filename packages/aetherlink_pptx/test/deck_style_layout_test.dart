import 'dart:convert';

import 'package:aetherlink_pptx/aetherlink_pptx.dart';
import 'package:test/test.dart';

Map<String, Object?> _deck(
  List<Map<String, Object?>> slides, {
  Object? style,
}) => {'layout': '16x9', 'style': ?style, 'slides': slides};

void main() {
  group('DeckStyle', () {
    test('内置风格 id 解析并推导颜色/字体/背景', () {
      final deck = DeckDocument.fromJson(
        _deck([
          {
            'elements': [
              {
                'type': 'text',
                'x': 1,
                'y': 1,
                'w': 4,
                'h': 1,
                'paragraphs': [
                  {
                    'runs': [
                      {'text': '标题'},
                    ],
                  },
                ],
              },
            ],
          },
        ], style: 'dark_tech'),
      );
      final style = deck.style!;
      expect(style.id, 'dark_tech');
      expect(deck.slides.first.background, style.background);
      final run = (deck.slides.first.elements.first as DeckTextElement)
          .paragraphs
          .first
          .runs
          .first;
      expect(run.color, style.textPrimary);
    });

    test('显式颜色不被风格覆盖', () {
      final deck = DeckDocument.fromJson(
        _deck([
          {
            'background': '112233',
            'elements': [
              {
                'type': 'text',
                'x': 1,
                'y': 1,
                'w': 4,
                'h': 1,
                'paragraphs': [
                  {
                    'runs': [
                      {'text': 'x', 'color': 'FF0000'},
                    ],
                  },
                ],
              },
            ],
          },
        ], style: 'dark_tech'),
      );
      expect(deck.slides.first.background!.value, '112233');
      final run = (deck.slides.first.elements.first as DeckTextElement)
          .paragraphs
          .first
          .runs
          .first;
      expect(run.color!.value, 'FF0000');
    });

    test('内联 style JSON 生效，未知 id 报错', () {
      final deck = DeckDocument.fromJson(
        _deck(
          [
            {'elements': <Object?>[]},
          ],
          style: {
            'background': '000000',
            'cardFill': '111111',
            'textPrimary': 'EEEEEE',
            'textSecondary': '999999',
            'accents': ['00E5FF'],
          },
        ),
      );
      expect(deck.style!.isDark, isTrue);
      expect(
        () => DeckDocument.fromJson(
          _deck([
            {'elements': <Object?>[]},
          ], style: 'nope'),
        ),
        throwsA(isA<DeckParseException>()),
      );
    });

    test('无 style 保持旧行为', () {
      final deck = DeckDocument.fromJson(
        _deck([
          {'elements': <Object?>[]},
        ]),
      );
      expect(deck.style, isNull);
      expect(deck.slides.first.background, isNull);
    });

    test('内置风格目录包含 12 个风格', () {
      expect(kBuiltinDeckStyles.length, 12);
      expect(builtinDeckStyleCatalog().length, 12);
    });
  });

  group('布局引擎', () {
    DeckDocument deckWithLayout(Map<String, Object?> layout) =>
        DeckDocument.fromJson(
          _deck([
            {'layout': layout},
          ], style: 'dark_tech'),
        );

    Map<String, Object?> card(String type) => switch (type) {
      'text' => {
        'type': 'text',
        'title': 'T',
        'body': ['b1', 'b2'],
      },
      'data' => {'type': 'data', 'value': '87%', 'label': 'L'},
      'list' => {
        'type': 'list',
        'items': ['a', 'b', 'c'],
      },
      'tags' => {
        'type': 'tags',
        'tags': ['x', 'y', 'z'],
      },
      'process' => {
        'type': 'process',
        'steps': ['s1', 's2', 's3'],
      },
      _ => {'type': 'big_number', 'value': '42', 'label': 'L'},
    };

    test('7 种内容布局元素全部在画布内且通过 QA 边界检查', () {
      const cases = {
        'focus': 1,
        'split': 2,
        'asymmetric': 2,
        'columns': 3,
        'hierarchy': 3,
        'hero': 4,
        'grid': 5,
      };
      final cardTypes = [
        'text',
        'data',
        'list',
        'tags',
        'process',
        'big_number',
      ];
      cases.forEach((type, n) {
        final deck = deckWithLayout({
          'type': type,
          'title': '页标题',
          'cards': [for (var i = 0; i < n; i++) card(cardTypes[i])],
        });
        final slide = deck.slides.first;
        expect(slide.elements, isNotEmpty, reason: type);
        final issues = runDeckQa(deck).where((i) => i.rule == 'out_of_bounds');
        expect(issues, isEmpty, reason: '$type 越界: $issues');
      });
    });

    test('cover/toc/section/end 页型可编译', () {
      for (final layout in [
        {'type': 'cover', 'title': 'T', 'subtitle': 'S', 'meta': 'M'},
        {
          'type': 'toc',
          'items': ['一', '二', '三', '四'],
        },
        {'type': 'section', 'title': 'T', 'label': 'PART 01'},
        {
          'type': 'end',
          'title': '谢谢',
          'items': ['联系我们'],
        },
      ]) {
        final deck = deckWithLayout(layout);
        expect(deck.slides.first.elements, isNotEmpty);
      }
    });

    test('卡片数量不匹配布局时报错', () {
      expect(
        () => deckWithLayout({
          'type': 'split',
          'title': 'T',
          'cards': [card('text')],
        }),
        throwsA(isA<DeckParseException>()),
      );
    });

    test('layout 元素与绝对定位 elements 可混用', () {
      final deck = DeckDocument.fromJson(
        _deck([
          {
            'layout': {
              'type': 'focus',
              'title': 'T',
              'cards': [card('text')],
            },
            'elements': [
              {
                'type': 'shape',
                'shape': 'rect',
                'x': 0,
                'y': 0,
                'w': 1,
                'h': 1,
                'fill': 'FF0000',
              },
            ],
          },
        ]),
      );
      expect(
        deck.slides.first.elements.whereType<DeckShapeElement>(),
        isNotEmpty,
      );
    });
  });

  group('图表扩展', () {
    Map<String, Object?> chart(String kind, {int cats = 3, int series = 1}) => {
      'type': 'chart',
      'chart': kind,
      'x': 1,
      'y': 1,
      'w': 6,
      'h': 4,
      'categories': [for (var i = 0; i < cats; i++) 'C$i'],
      'series': [
        for (var s = 0; s < series; s++)
          {
            'name': 'S$s',
            'values': [for (var i = 0; i < cats; i++) (i + 1) * (s + 1)],
          },
      ],
    };

    test('9 种原生图表都能生成并通过包结构自检', () {
      for (final kind in [
        'bar',
        'line',
        'pie',
        'doughnut',
        'area',
        'scatter',
        'stackedBar',
        'horizontalBar',
        'radar',
      ]) {
        final deck = DeckDocument.fromJson(
          _deck([
            {
              'elements': [
                chart(
                  kind,
                  series: kind == 'pie' || kind == 'doughnut' ? 1 : 2,
                ),
              ],
            },
          ], style: 'dark_tech'),
        );
        final bytes = buildPptxBytes(deck);
        expect(validatePptxPackage(bytes), isEmpty, reason: kind);
        final html = renderDeckHtml(deck);
        expect(html, contains('<svg'), reason: kind);
      }
    });

    test('雷达图少于 3 个维度报错', () {
      expect(
        () => DeckDocument.fromJson(
          _deck([
            {
              'elements': [chart('radar', cats: 2)],
            },
          ]),
        ),
        throwsA(isA<DeckParseException>()),
      );
    });

    test('风格 accents 作为图表默认配色写入 chart XML', () {
      final deck = DeckDocument.fromJson(
        _deck([
          {
            'elements': [chart('bar')],
          },
        ], style: 'dark_tech'),
      );
      final accent = deck.style!.accents.first.value;
      final html = renderDeckHtml(deck);
      expect(html, contains(accent.toLowerCase().toUpperCase()));
    });
  });

  group('infographic', () {
    Map<String, Object?> info(String kind, Map<String, Object?> extra) => {
      'type': 'infographic',
      'kind': kind,
      'x': 1,
      'y': 1,
      'w': 5,
      'h': 3,
      ...extra,
    };

    test('6 种形状合成图都能展开并导出合法 pptx', () {
      final specs = <Map<String, Object?>>[
        info('progress', {'value': 72, 'label': '进度'}),
        info('kpi', {'value': '1.2亿', 'label': '营收', 'trend': '+12%'}),
        info('waffle', {'value': 64, 'label': '占比'}),
        info('timeline', {
          'steps': [
            {'label': '2023', 'desc': '起步'},
            '2024',
            {'label': '2025', 'desc': '扩张'},
          ],
        }),
        info('funnel', {
          'stages': [
            {'label': '曝光', 'value': 100},
            {'label': '点击', 'value': 40},
            {'label': '转化', 'value': 12},
          ],
        }),
        info('gauge', {'value': 85, 'label': '完成率'}),
      ];
      final deck = DeckDocument.fromJson(
        _deck([
          for (final s in specs)
            {
              'elements': [s],
            },
        ], style: 'dark_tech'),
      );
      expect(deck.slides, hasLength(6));
      for (final slide in deck.slides) {
        expect(slide.elements.length, greaterThan(1));
      }
      final bytes = buildPptxBytes(deck);
      expect(validatePptxPackage(bytes), isEmpty);
    });

    test('未知 kind / 非法 value 报错', () {
      expect(
        () => DeckDocument.fromJson(
          _deck([
            {
              'elements': [info('nope', {})],
            },
          ]),
        ),
        throwsA(isA<DeckParseException>()),
      );
      expect(
        () => DeckDocument.fromJson(
          _deck([
            {
              'elements': [
                info('progress', {'value': 120}),
              ],
            },
          ]),
        ),
        throwsA(isA<DeckParseException>()),
      );
    });
  });

  test('parseDeckJson 端到端：style + layout + 新图表', () {
    final deck = DeckDocument.fromJson(
      jsonDecode(
            jsonEncode(
              _deck([
                {
                  'layout': {
                    'type': 'cover',
                    'title': '年度报告',
                    'subtitle': '2026',
                  },
                },
                {
                  'layout': {
                    'type': 'grid',
                    'title': '核心数据',
                    'cards': [
                      {'type': 'data', 'value': '87%', 'label': '增长'},
                      {'type': 'big_number', 'value': '42'},
                      {
                        'type': 'list',
                        'items': ['a', 'b'],
                      },
                      {
                        'type': 'text',
                        'body': ['正文'],
                      },
                    ],
                  },
                },
              ], style: 'ink_jade'),
            ),
          )
          as Map<String, Object?>,
    );
    final bytes = buildPptxBytes(deck);
    expect(validatePptxPackage(bytes), isEmpty);
    expect(runDeckQa(deck).where((i) => i.rule == 'out_of_bounds'), isEmpty);
  });

  test('image src 引用：解析为未展开元素，writer 拒绝导出', () {
    final deck = DeckDocument.fromJson(
      _deck([
        {
          'elements': [
            {
              'type': 'image',
              'x': 1,
              'y': 1,
              'w': 3,
              'h': 2,
              'src': 'https://example.com/a.png',
            },
          ],
        },
      ]),
    );
    final image = deck.slides.first.elements.single as DeckImageElement;
    expect(image.isResolved, isFalse);
    expect(image.src, 'https://example.com/a.png');
    expect(() => buildPptxBytes(deck), throwsA(isA<DeckParseException>()));
    expect(renderDeckHtml(deck), contains('src 未展开'));
  });

  test('image 缺 data 和 src 时报错', () {
    expect(
      () => DeckDocument.fromJson(
        _deck([
          {
            'elements': [
              {'type': 'image', 'x': 1, 'y': 1, 'w': 3, 'h': 2},
            ],
          },
        ]),
      ),
      throwsA(isA<DeckParseException>()),
    );
  });
}
