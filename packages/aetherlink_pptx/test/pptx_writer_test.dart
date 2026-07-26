import 'dart:convert';

import 'package:aetherlink_pptx/aetherlink_pptx.dart';
import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'deck_document_test.dart' show kPngBase64;

DeckDocument _sampleDeck() => DeckDocument.parse(
  jsonEncode({
    'layout': '16x9',
    'title': '样例演示',
    'slides': [
      {
        'background': '0F1115',
        'elements': [
          {
            'type': 'text',
            'x': 1,
            'y': 2.5,
            'w': 11.33,
            'h': 1.5,
            'valign': 'middle',
            'paragraphs': [
              {
                'runs': [
                  {
                    'text': 'AetherLink PPT',
                    'bold': true,
                    'size': 44,
                    'color': 'FFFFFF',
                    'font': '微软雅黑',
                  },
                ],
                'align': 'center',
              },
            ],
          },
          {
            'type': 'shape',
            'shape': 'roundRect',
            'x': 5.17,
            'y': 4.5,
            'w': 3,
            'h': 0.6,
            'fill': '1A73E8',
            'fillTransparency': 20,
            'radius': 0.25,
          },
          {
            'type': 'shape',
            'shape': 'line',
            'x': 1,
            'y': 5.5,
            'w': 11.33,
            'h': 0,
            'lineColor': '5F6368',
            'lineWidth': 2,
          },
        ],
      },
      {
        'elements': [
          {
            'type': 'text',
            'x': 0.8,
            'y': 0.6,
            'w': 11.7,
            'h': 1,
            'paragraphs': [
              {
                'runs': [
                  {'text': '要点', 'bold': true, 'size': 28},
                ],
              },
              {
                'runs': [
                  {'text': '第一条', 'size': 18},
                ],
                'bullet': true,
              },
              {
                'runs': [
                  {'text': '子项', 'size': 16},
                ],
                'bullet': true,
                'indentLevel': 1,
              },
            ],
          },
          {'type': 'image', 'x': 9, 'y': 3, 'w': 2, 'h': 2, 'data': kPngBase64},
          {
            'type': 'table',
            'x': 0.8,
            'y': 3,
            'w': 7,
            'h': 2,
            'colWidths': [3, 4],
            'headerFill': '1A73E8',
            'headerColor': 'FFFFFF',
            'borderColor': 'DADCE0',
            'rows': [
              ['指标', '数值'],
              ['收入', '120 万'],
            ],
          },
        ],
      },
    ],
  }),
);

void main() {
  group('buildPptxBytes', () {
    late Archive archive;

    XmlDocument part(String path) {
      final file = archive.files.where((f) => f.name == path).firstOrNull;
      expect(file, isNotNull, reason: '$path missing from package');
      return XmlDocument.parse(utf8.decode(file!.readBytes()!));
    }

    setUpAll(() {
      archive = ZipDecoder().decodeBytes(buildPptxBytes(_sampleDeck()));
    });

    test('package has all required parts and they are well-formed XML', () {
      for (final path in [
        '[Content_Types].xml',
        '_rels/.rels',
        'ppt/presentation.xml',
        'ppt/_rels/presentation.xml.rels',
        'ppt/slideMasters/slideMaster1.xml',
        'ppt/slideMasters/_rels/slideMaster1.xml.rels',
        'ppt/slideLayouts/slideLayout1.xml',
        'ppt/slideLayouts/_rels/slideLayout1.xml.rels',
        'ppt/theme/theme1.xml',
        'ppt/slides/slide1.xml',
        'ppt/slides/slide2.xml',
        'ppt/slides/_rels/slide1.xml.rels',
        'ppt/slides/_rels/slide2.xml.rels',
        'docProps/core.xml',
        'docProps/app.xml',
      ]) {
        part(path); // throws if missing or malformed
      }
    });

    test('content types cover every slide and the png media', () {
      final xml = part('[Content_Types].xml').toXmlString();
      expect(xml, contains('/ppt/slides/slide1.xml'));
      expect(xml, contains('/ppt/slides/slide2.xml'));
      expect(xml, contains('Extension="png"'));
    });

    test('presentation lists both slides with 16:9 size', () {
      final doc = part('ppt/presentation.xml');
      final sldIds = doc.findAllElements('p:sldId');
      expect(sldIds, hasLength(2));
      final size = doc.findAllElements('p:sldSz').single;
      expect(size.getAttribute('cx'), '12192000');
      expect(size.getAttribute('cy'), '6858000');
    });

    test('text becomes native runs with color, font, bullet and alignment', () {
      final slide1 = part('ppt/slides/slide1.xml').toXmlString();
      expect(slide1, contains('<a:t>AetherLink PPT</a:t>'));
      expect(slide1, contains('sz="4400"'));
      expect(slide1, contains('b="1"'));
      expect(slide1, contains('val="FFFFFF"'));
      expect(slide1, contains('typeface="微软雅黑"'));
      expect(slide1, contains('algn="ctr"'));

      final slide2 = part('ppt/slides/slide2.xml').toXmlString();
      expect(slide2, contains('<a:buChar char="•"/>'));
      expect(slide2, contains('lvl="1"'));
    });

    test(
      'shape carries preset geometry, alpha transparency and adj radius',
      () {
        final slide1 = part('ppt/slides/slide1.xml').toXmlString();
        expect(slide1, contains('prst="roundRect"'));
        expect(slide1, contains('<a:alpha val="80000"/>'));
        expect(slide1, contains('fmla="val 25000"'));
        expect(slide1, contains('prst="line"'));
      },
    );

    test('slide background is a solid fill', () {
      final slide1 = part('ppt/slides/slide1.xml').toXmlString();
      expect(slide1, contains('<p:bg>'));
      expect(slide1, contains('val="0F1115"'));
    });

    test('image is embedded as media with a slide relationship', () {
      expect(
        archive.files.any((f) => f.name == 'ppt/media/image1.png'),
        isTrue,
      );
      final rels = part('ppt/slides/_rels/slide2.xml.rels').toXmlString();
      expect(rels, contains('../media/image1.png'));
      final slide2 = part('ppt/slides/slide2.xml').toXmlString();
      expect(slide2, contains('r:embed='));
    });

    test('table renders a native a:tbl with grid, header fill and borders', () {
      final slide2 = part('ppt/slides/slide2.xml').toXmlString();
      expect(slide2, contains('<a:tbl>'));
      expect(slide2, contains('<a:gridCol w="2743200"/>'));
      expect(slide2, contains('<a:t>指标</a:t>'));
      expect(slide2, contains('val="1A73E8"'));
      expect(slide2, contains('<a:lnL'));
    });

    test('XML special characters in text are escaped', () {
      final deck = DeckDocument.parse(
        jsonEncode({
          'slides': [
            {
              'elements': [
                {
                  'type': 'text',
                  'x': 0,
                  'y': 0,
                  'w': 5,
                  'h': 1,
                  'paragraphs': [
                    {
                      'runs': [
                        {'text': 'a < b & "c"'},
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        }),
      );
      final bytes = buildPptxBytes(deck);
      final files = ZipDecoder().decodeBytes(bytes);
      final slide = utf8.decode(
        files.files
            .firstWhere((f) => f.name == 'ppt/slides/slide1.xml')
            .readBytes()!,
      );
      expect(slide, contains('a &lt; b &amp; &quot;c&quot;'));
      XmlDocument.parse(slide); // must stay well-formed
    });
  });

  group('renderDeckHtml', () {
    test('renders one absolutely-positioned page per slide', () {
      final html = renderDeckHtml(_sampleDeck());
      expect('class="slide"'.allMatches(html), hasLength(2));
      expect(html, contains('AetherLink PPT'));
      expect(html, contains('data:image/png;base64,'));
      expect(html, contains('<table class="deck">'));
    });
  });

  group('charts', () {
    DeckDocument chartDeck(String kind, {int seriesCount = 2}) =>
        DeckDocument.parse(
          jsonEncode({
            'layout': '16x9',
            'slides': [
              {
                'elements': [
                  {
                    'type': 'chart',
                    'chart': kind,
                    'x': 1,
                    'y': 1,
                    'w': 8,
                    'h': 4.5,
                    'title': '季度对比',
                    'categories': ['Q1', 'Q2', 'Q3'],
                    'series': [
                      for (
                        var i = 0;
                        i < (kind == 'pie' ? 1 : seriesCount);
                        i++
                      )
                        {
                          'name': '系列${i + 1}',
                          'values': [10 + i, 20 + i, 15 + i],
                          if (i == 0) 'color': '1A73E8',
                        },
                    ],
                  },
                ],
              },
            ],
          }),
        );

    Map<String, String> partsOf(DeckDocument deck) {
      final files = ZipDecoder().decodeBytes(buildPptxBytes(deck));
      return {
        for (final f in files.files.where((f) => f.isFile))
          f.name: f.name.endsWith('.xml') || f.name.endsWith('.rels')
              ? utf8.decode(f.readBytes()!)
              : '',
      };
    }

    test('bar chart emits a native chart part wired via graphicFrame', () {
      final parts = partsOf(chartDeck('bar'));
      expect(parts, contains('ppt/charts/chart1.xml'));
      expect(
        parts['[Content_Types].xml'],
        contains(
          '/ppt/charts/chart1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawingml.chart+xml"',
        ),
      );
      final slide = parts['ppt/slides/slide1.xml']!;
      expect(slide, contains('<p:graphicFrame>'));
      expect(slide, contains('drawingml/2006/chart'));
      expect(
        parts['ppt/slides/_rels/slide1.xml.rels'],
        contains('Target="../charts/chart1.xml"'),
      );
      final chart = parts['ppt/charts/chart1.xml']!;
      XmlDocument.parse(chart);
      expect(chart, contains('<c:barChart>'));
      expect(chart, contains('<c:v>Q1</c:v>'));
      expect(chart, contains('<c:v>系列1</c:v>'));
      expect(chart, contains('val="1A73E8"'));
      expect(chart, contains('<c:catAx>'));
      expect(chart, contains('<c:valAx>'));
      expect(chart, contains('季度对比'));
    });

    test('line and pie charts map to their OOXML chart types', () {
      final line = partsOf(chartDeck('line'))['ppt/charts/chart1.xml']!;
      XmlDocument.parse(line);
      expect(line, contains('<c:lineChart>'));

      final pie = partsOf(chartDeck('pie'))['ppt/charts/chart1.xml']!;
      XmlDocument.parse(pie);
      expect(pie, contains('<c:pieChart>'));
      expect(pie, isNot(contains('<c:catAx>')));
    });

    test('multiple charts across slides get distinct parts', () {
      final deck = DeckDocument.parse(
        jsonEncode({
          'layout': '16x9',
          'slides': [
            for (var s = 0; s < 2; s++)
              {
                'elements': [
                  {
                    'type': 'chart',
                    'chart': 'bar',
                    'x': 1,
                    'y': 1,
                    'w': 6,
                    'h': 4,
                    'categories': ['A'],
                    'series': [
                      {
                        'name': 'S',
                        'values': [s + 1],
                      },
                    ],
                  },
                ],
              },
          ],
        }),
      );
      final parts = partsOf(deck);
      expect(parts, contains('ppt/charts/chart1.xml'));
      expect(parts, contains('ppt/charts/chart2.xml'));
      expect(
        parts['ppt/slides/_rels/slide2.xml.rels'],
        contains('Target="../charts/chart2.xml"'),
      );
    });

    test('chart source validation is strict and actionable', () {
      Map<String, Object?> element(Map<String, Object?> patch) => {
        'layout': '16x9',
        'slides': [
          {
            'elements': [
              {
                'type': 'chart',
                'chart': 'bar',
                'x': 1,
                'y': 1,
                'w': 6,
                'h': 4,
                'categories': ['A', 'B'],
                'series': [
                  {
                    'name': 'S',
                    'values': [1, 2],
                  },
                ],
                ...patch,
              },
            ],
          },
        ],
      };

      expect(
        () => DeckDocument.parse(jsonEncode(element({'chart': 'radar'}))),
        throwsA(isA<DeckParseException>()),
      );
      expect(
        () => DeckDocument.parse(jsonEncode(element({'categories': []}))),
        throwsA(isA<DeckParseException>()),
      );
      expect(
        () => DeckDocument.parse(
          jsonEncode(
            element({
              'series': [
                {
                  'name': 'S',
                  'values': [1],
                },
              ],
            }),
          ),
        ),
        throwsA(isA<DeckParseException>()),
      );
      expect(
        () => DeckDocument.parse(
          jsonEncode(
            element({
              'chart': 'pie',
              'series': [
                {
                  'name': 'A',
                  'values': [1, 2],
                },
                {
                  'name': 'B',
                  'values': [3, 4],
                },
              ],
            }),
          ),
        ),
        throwsA(isA<DeckParseException>()),
      );
    });

    test('HTML preview renders charts as inline SVG', () {
      final html = renderDeckHtml(chartDeck('pie'));
      expect(html, contains('<svg'));
      expect(html, contains('<path'));
      final barHtml = renderDeckHtml(chartDeck('bar'));
      expect(barHtml, contains('<rect'));
      expect(barHtml, contains('季度对比'));
    });
  });
}
