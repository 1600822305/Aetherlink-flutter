import 'dart:convert';
import 'dart:typed_data';

import 'package:aetherlink_pptx/aetherlink_pptx.dart';
import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

DeckDocument _deckWithEverything() => DeckDocument.parse(
  jsonEncode({
    'layout': '16x9',
    'title': '读取测试',
    'slides': [
      {
        'notes': '第一页备注\n第二行',
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
                  {'text': '大标题', 'bold': true, 'size': 40},
                ],
              },
              {
                'runs': [
                  {'text': '副标题', 'size': 16},
                ],
              },
            ],
          },
          {
            'type': 'table',
            'x': 1,
            'y': 3,
            'w': 7,
            'h': 2,
            'rows': [
              ['指标', '数值'],
              ['营收', '120'],
            ],
          },
        ],
      },
      {
        'elements': [
          {
            'type': 'chart',
            'chart': 'bar',
            'x': 1,
            'y': 1.5,
            'w': 6,
            'h': 4.5,
            'title': '季度营收',
            'categories': ['Q1', 'Q2'],
            'series': [
              {
                'name': '2025',
                'values': [12, 18],
              },
            ],
          },
        ],
      },
    ],
  }),
);

void main() {
  group('readPptxBytes', () {
    test('roundtrip：writer 输出可被 reader 完整读回', () {
      final bytes = buildPptxBytes(_deckWithEverything());
      final result = readPptxBytes(bytes);

      expect(result.title, '读取测试');
      expect(result.slides, hasLength(2));
      expect(result.slideWidthInches, closeTo(13.333, 0.01));

      final s1 = result.slides[0];
      expect(s1.texts.single, '大标题\n副标题');
      expect(s1.tables.single.rows, [
        ['指标', '数值'],
        ['营收', '120'],
      ]);
      expect(s1.notes, '第一页备注\n第二行');

      final s2 = result.slides[1];
      final chart = s2.charts.single;
      expect(chart.kind, 'bar');
      expect(chart.title, '季度营收');
      expect(chart.categories, ['Q1', 'Q2']);
      expect(chart.series.single.name, '2025');
      expect(chart.series.single.values, [12, 18]);
      expect(s2.notes, isNull);
    });

    test('非 zip 输入抛 PptxReadException', () {
      expect(
        () => readPptxBytes(utf8.encode('not a zip')),
        throwsA(isA<PptxReadException>()),
      );
    });

    test('pptxToMarkdown 含幻灯片分节、表格与备注', () {
      final md = pptxToMarkdown(
        readPptxBytes(buildPptxBytes(_deckWithEverything())),
      );
      expect(md, contains('<!-- Slide number: 1 -->'));
      expect(md, contains('| 指标 | 数值 |'));
      expect(md, contains('> 备注：第一页备注'));
      expect(md, contains('图表（bar：季度营收）'));
      expect(md, contains('Q1=12'));
    });

    test('pptxToDeckSkeleton 输出可再次被 DeckDocument 解析', () {
      final skeleton = pptxToDeckSkeleton(
        readPptxBytes(buildPptxBytes(_deckWithEverything())),
      );
      final deck = DeckDocument.fromJson(skeleton);
      expect(deck.slides, hasLength(2));
      expect(deck.slides[0].notes, '第一页备注\n第二行');
      expect(deck.slides[1].elements.single, isA<DeckChartElement>());
    });
  });

  group('notes 写入', () {
    test('有 notes 时生成 notesSlide/notesMaster 部件与关系', () {
      final bytes = buildPptxBytes(_deckWithEverything());
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = {for (final f in archive.files) f.name};
      expect(names, contains('ppt/notesSlides/notesSlide1.xml'));
      expect(names, contains('ppt/notesSlides/_rels/notesSlide1.xml.rels'));
      expect(names, contains('ppt/notesMasters/notesMaster1.xml'));
      expect(names, contains('ppt/theme/theme2.xml'));
      // 第二页没有 notes，不应有 notesSlide2。
      expect(names, isNot(contains('ppt/notesSlides/notesSlide2.xml')));

      String read(String name) => utf8.decode(
        archive.files.firstWhere((f) => f.name == name).readBytes()!,
      );
      expect(
        read('[Content_Types].xml'),
        contains('/ppt/notesSlides/notesSlide1.xml'),
      );
      expect(read('ppt/presentation.xml'), contains('notesMasterIdLst'));
      expect(
        read('ppt/slides/_rels/slide1.xml.rels'),
        contains('notesSlide1.xml'),
      );
      final notesXml = XmlDocument.parse(
        read('ppt/notesSlides/notesSlide1.xml'),
      );
      final texts = notesXml
          .findAllElements('t', namespace: '*')
          .map((t) => t.innerText)
          .toList();
      expect(texts, ['第一页备注', '第二行']);
    });

    test('没有 notes 时不生成任何 notes 部件', () {
      final deck = DeckDocument.parse(
        jsonEncode({
          'layout': '16x9',
          'slides': [
            {
              'elements': [
                {
                  'type': 'text',
                  'x': 1,
                  'y': 1,
                  'w': 5,
                  'h': 1,
                  'paragraphs': [
                    {
                      'runs': [
                        {'text': 'hi'},
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        }),
      );
      final archive = ZipDecoder().decodeBytes(buildPptxBytes(deck));
      expect(archive.files.any((f) => f.name.contains('notes')), isFalse);
    });
  });

  group('validatePptxPackage', () {
    test('writer 输出（含 notes/chart/table）通过结构自检', () {
      final issues = validatePptxPackage(buildPptxBytes(_deckWithEverything()));
      expect(issues, isEmpty);
    });

    test('缺失关系目标 / 内容类型会被报告', () {
      final bytes = buildPptxBytes(_deckWithEverything());
      final src = ZipDecoder().decodeBytes(bytes);
      final broken = Archive();
      for (final f in src.files) {
        // 删掉 chart 部件：slide rels 指向它 → 关系断裂 + Override 悬空。
        if (f.name == 'ppt/charts/chart1.xml') continue;
        broken.add(ArchiveFile.bytes(f.name, f.readBytes()!));
      }
      final issues = validatePptxPackage(
        Uint8List.fromList(ZipEncoder().encode(broken)),
      );
      expect(
        issues.any((i) => i.message.contains('ppt/charts/chart1.xml')),
        isTrue,
      );
    });

    test('非 pptx 输入返回问题而不是抛异常', () {
      final issues = validatePptxPackage(utf8.encode('junk'));
      expect(issues, isNotEmpty);
      expect(issues.any((i) => i.part == 'ppt/presentation.xml'), isTrue);
    });
  });
}
