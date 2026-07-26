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
}
