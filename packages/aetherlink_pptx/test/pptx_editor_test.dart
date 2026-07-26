import 'dart:convert';
import 'dart:typed_data';

import 'package:aetherlink_pptx/aetherlink_pptx.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'deck_document_test.dart' show kPngBase64;

/// 三页夹具：封面（标题+副标题）、正文（文本+图片，带备注）、结尾。
/// 用 buildPptxBytes 生成真包，编辑后再用 validatePptxPackage 端到端校验。
DeckDocument _fixtureDeck() => DeckDocument.parse(
  jsonEncode({
    'layout': '16x9',
    'title': '编辑夹具',
    'slides': [
      {
        'elements': [
          {
            'type': 'text',
            'x': 1,
            'y': 2.5,
            'w': 11.33,
            'h': 1.5,
            'paragraphs': [
              {
                'runs': [
                  {
                    'text': '原标题',
                    'bold': true,
                    'size': 44,
                    'color': 'FF0000',
                    'font': '微软雅黑',
                  },
                ],
              },
            ],
          },
        ],
      },
      {
        'notes': '这一页的原始备注',
        'elements': [
          {
            'type': 'text',
            'x': 1,
            'y': 1,
            'w': 6,
            'h': 1,
            'paragraphs': [
              {
                'runs': [
                  {'text': '正文占位', 'size': 20},
                ],
              },
            ],
          },
          {
            'type': 'image',
            'x': 8,
            'y': 1,
            'w': 2,
            'h': 2,
            'data': kPngBase64,
          },
        ],
      },
      {
        'elements': [
          {
            'type': 'text',
            'x': 1,
            'y': 3,
            'w': 11.33,
            'h': 1,
            'paragraphs': [
              {
                'runs': [
                  {'text': '谢谢观看', 'size': 32},
                ],
              },
            ],
          },
        ],
      },
    ],
  }),
);

Uint8List _fixtureBytes() => buildPptxBytes(_fixtureDeck());

PptxPackage _openFixture() => PptxPackage.open(_fixtureBytes());

/// 存盘再打开——确认改动落到字节里，并且包结构仍然合法。
PptxPackage _roundTrip(PptxPackage pkg) {
  final bytes = pkg.save();
  expect(
    validatePptxPackage(bytes).map((i) => '${i.part}: ${i.message}'),
    isEmpty,
    reason: '编辑后的包结构校验必须通过',
  );
  return PptxPackage.open(bytes);
}

void main() {
  group('PptxPackage 打开与保存', () {
    test('往返不丢部件', () {
      final pkg = _openFixture();
      final before = pkg.partNames.toSet();
      final after = PptxPackage.open(pkg.save()).partNames.toSet();
      expect(after, before);
    });

    test('非 zip 输入报可读错误', () {
      expect(
        () => PptxPackage.open(Uint8List.fromList(utf8.encode('not a pptx'))),
        throwsA(isA<PptxEditException>()),
      );
    });

    test('slidePaths 按放映顺序返回三页', () {
      expect(_openFixture().slidePaths(), hasLength(3));
    });
  });

  group('describePptxOutline', () {
    test('逐页列出 shape 的下标 / 类型 / 文本', () {
      final outline = describePptxOutline(_openFixture());
      expect(outline, hasLength(3));
      expect(outline[0].index, 0);
      expect(outline[0].shapes.first.index, 0);
      expect(outline[0].shapes.first.text, '原标题');
      // shape 下标必须连续从 0 起（nvGrpSpPr/grpSpPr 不算 shape）
      for (final slide in outline) {
        expect(
          [for (final s in slide.shapes) s.index],
          List.generate(slide.shapes.length, (i) => i),
        );
      }
    });

    test('图片计数与备注被提取出来', () {
      final outline = describePptxOutline(_openFixture());
      expect(outline[1].imageCount, 1);
      expect(outline[1].notes, '这一页的原始备注');
      expect(outline[0].notes, isNull);
      expect(outline[1].shapes.any((s) => s.kind == 'pic'), isTrue);
    });
  });

  group('setShapeText', () {
    test('改文字但保留原有格式（字号/颜色/加粗）', () {
      final pkg = _openFixture();
      setShapeText(pkg, 0, 0, '换过的标题');
      final reopened = _roundTrip(pkg);

      expect(describePptxOutline(reopened)[0].shapes[0].text, '换过的标题');

      // rPr 上的字号/颜色必须还在
      final doc = reopened.xml(reopened.slidePathAt(0));
      final rPr = doc.findAllElements('rPr', namespace: '*').first;
      expect(rPr.getAttribute('sz'), '4400');
      expect(rPr.getAttribute('b'), '1');
      expect(
        doc.findAllElements('srgbClr', namespace: '*').any(
          (e) => e.getAttribute('val') == 'FF0000',
        ),
        isTrue,
      );
    });

    test('\\n 拆成多个段落', () {
      final pkg = _openFixture();
      setShapeText(pkg, 0, 0, '第一行\n第二行\n第三行');
      final reopened = _roundTrip(pkg);
      expect(describePptxOutline(reopened)[0].shapes[0].text, '第一行\n第二行\n第三行');
      final body = reopened
          .xml(reopened.slidePathAt(0))
          .findAllElements('txBody', namespace: '*')
          .first;
      expect(
        body.childElements.where((e) => e.name.local == 'p'),
        hasLength(3),
      );
    });

    test('shape 下标越界报错并给出合法范围', () {
      expect(
        () => setShapeText(_openFixture(), 0, 99, 'x'),
        throwsA(
          isA<PptxEditException>().having(
            (e) => e.message,
            'message',
            allOf(contains('越界'), contains('合法')),
          ),
        ),
      );
    });

    test('对没有文本框的 shape（图片）报错', () {
      final pkg = _openFixture();
      final picIndex = describePptxOutline(pkg)[1].shapes
          .firstWhere((s) => s.kind == 'pic')
          .index;
      expect(
        () => setShapeText(pkg, 1, picIndex, 'x'),
        throwsA(isA<PptxEditException>()),
      );
    });
  });

  group('replaceTextEverywhere', () {
    test('全 deck 替换并返回次数', () {
      final pkg = _openFixture();
      expect(replaceTextEverywhere(pkg, '原标题', '新标题'), 1);
      expect(describePptxOutline(_roundTrip(pkg))[0].shapes[0].text, '新标题');
    });

    test('限定单页时不影响其他页', () {
      final pkg = _openFixture();
      expect(replaceTextEverywhere(pkg, '原标题', 'X', slide: 1), 0);
      expect(describePptxOutline(pkg)[0].shapes[0].text, '原标题');
    });

    test('找不到时返回 0，空 find 报错', () {
      final pkg = _openFixture();
      expect(replaceTextEverywhere(pkg, '不存在的文字', 'X'), 0);
      expect(
        () => replaceTextEverywhere(pkg, '', 'X'),
        throwsA(isA<PptxEditException>()),
      );
    });
  });

  group('setSlideNotes', () {
    test('改写已有备注', () {
      final pkg = _openFixture();
      setSlideNotes(pkg, 1, '换过的备注');
      expect(describePptxOutline(_roundTrip(pkg))[1].notes, '换过的备注');
    });

    test('给原本没有备注的页新建备注页', () {
      final pkg = _openFixture();
      expect(describePptxOutline(pkg)[0].notes, isNull);
      setSlideNotes(pkg, 0, '新加的备注');
      final reopened = _roundTrip(pkg);
      expect(describePptxOutline(reopened)[0].notes, '新加的备注');
      // 原有那页的备注不受影响
      expect(describePptxOutline(reopened)[1].notes, '这一页的原始备注');
    });
  });

  group('replaceSlideImage', () {
    test('换图后包仍合法，媒体部件被重指向', () {
      final pkg = _openFixture();
      final newBytes = base64Decode(kPngBase64);
      replaceSlideImage(pkg, 1, 0, Uint8List.fromList(newBytes), 'png');
      final reopened = _roundTrip(pkg);
      expect(describePptxOutline(reopened)[1].imageCount, 1);
      // 不该留下没人引用的孤儿媒体
      final media = reopened.partNames.where((p) => p.startsWith('ppt/media/'));
      expect(media, hasLength(1));
    });

    test('imageIndex 越界与不支持的扩展名都报错', () {
      final bytes = Uint8List.fromList(base64Decode(kPngBase64));
      expect(
        () => replaceSlideImage(_openFixture(), 1, 5, bytes, 'png'),
        throwsA(isA<PptxEditException>()),
      );
      expect(
        () => replaceSlideImage(_openFixture(), 1, 0, bytes, 'webp'),
        throwsA(
          isA<PptxEditException>().having(
            (e) => e.message,
            'message',
            contains('不支持的图片扩展名'),
          ),
        ),
      );
    });
  });

  group('duplicateSlide', () {
    test('复制页插到原页之后，内容一致且包合法', () {
      final pkg = _openFixture();
      expect(duplicateSlide(pkg, 0), 1);
      final outline = describePptxOutline(_roundTrip(pkg));
      expect(outline, hasLength(4));
      expect(outline[0].shapes[0].text, '原标题');
      expect(outline[1].shapes[0].text, '原标题');
      expect(outline[2].shapes[0].text, '正文占位');
    });

    test('可指定插入位置', () {
      final pkg = _openFixture();
      expect(duplicateSlide(pkg, 2, at: 0), 0);
      final outline = describePptxOutline(_roundTrip(pkg));
      expect(outline[0].shapes[0].text, '谢谢观看');
      expect(outline[1].shapes[0].text, '原标题');
    });

    test('复制带备注的页时另存备注，两页互不影响', () {
      final pkg = _openFixture();
      duplicateSlide(pkg, 1);
      var reopened = _roundTrip(pkg);
      expect(describePptxOutline(reopened)[1].notes, '这一页的原始备注');
      expect(describePptxOutline(reopened)[2].notes, '这一页的原始备注');

      // 改新页的备注不能连带改到原页
      setSlideNotes(reopened, 2, '只改副本');
      reopened = _roundTrip(reopened);
      final outline = describePptxOutline(reopened);
      expect(outline[1].notes, '这一页的原始备注');
      expect(outline[2].notes, '只改副本');
    });

    test('复制后改副本文字不影响原页（部件是独立的）', () {
      final pkg = _openFixture();
      duplicateSlide(pkg, 0);
      setShapeText(pkg, 1, 0, '副本标题');
      final outline = describePptxOutline(_roundTrip(pkg));
      expect(outline[0].shapes[0].text, '原标题');
      expect(outline[1].shapes[0].text, '副本标题');
    });

    test('插入位置越界报错', () {
      expect(
        () => duplicateSlide(_openFixture(), 0, at: 9),
        throwsA(isA<PptxEditException>()),
      );
    });
  });

  group('deleteSlide', () {
    test('删页后顺序正确、部件与 Override 一并清掉', () {
      final pkg = _openFixture();
      final removed = pkg.slidePathAt(1);
      final removedNotes = pkg.notesPathOf(removed);
      expect(removedNotes, isNotNull);

      deleteSlide(pkg, 1);
      final reopened = _roundTrip(pkg);

      final outline = describePptxOutline(reopened);
      expect(outline, hasLength(2));
      expect(outline[0].shapes[0].text, '原标题');
      expect(outline[1].shapes[0].text, '谢谢观看');
      expect(reopened.hasPart(removed), isFalse);
      expect(reopened.hasPart(PptxPackage.relsPathFor(removed)), isFalse);
      expect(reopened.hasPart(removedNotes!), isFalse);
      expect(
        reopened
            .xml('[Content_Types].xml')
            .toXmlString()
            .contains('/$removed'),
        isFalse,
      );
    });

    test('删掉带图表的页时回收孤儿 chart 部件（包自检不再报孤儿）', () {
      final deck = DeckDocument.parse(
        jsonEncode({
          'layout': '16x9',
          'slides': [
            {
              'elements': [
                {
                  'type': 'chart',
                  'chart': 'bar',
                  'x': 1,
                  'y': 1,
                  'w': 8,
                  'h': 4,
                  'categories': ['A', 'B'],
                  'series': [
                    {
                      'name': 'S1',
                      'values': [1, 2],
                    },
                  ],
                },
              ],
            },
            {
              'elements': [
                {
                  'type': 'text',
                  'x': 1,
                  'y': 1,
                  'w': 6,
                  'h': 1,
                  'paragraphs': [
                    {
                      'runs': [
                        {'text': '保留页'},
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        }),
      );
      final pkg = PptxPackage.open(buildPptxBytes(deck));
      expect(pkg.hasPart('ppt/charts/chart1.xml'), isTrue);

      deleteSlide(pkg, 0);
      final reopened = _roundTrip(pkg); // _roundTrip 断言包自检为空

      expect(reopened.hasPart('ppt/charts/chart1.xml'), isFalse);
      expect(describePptxOutline(reopened), hasLength(1));
    });

    test('删掉复制页时不回收仍被原页引用的图片', () {
      final pkg = _openFixture();
      duplicateSlide(pkg, 1); // 第 1 页带图片，复制后两页共用媒体部件
      final mediaBefore = pkg.partNames
          .where((p) => p.startsWith('ppt/media/'))
          .toSet();

      deleteSlide(pkg, 2); // 删掉副本
      final reopened = _roundTrip(pkg);

      final mediaAfter = reopened.partNames
          .where((p) => p.startsWith('ppt/media/'))
          .toSet();
      expect(mediaAfter, mediaBefore, reason: '共享图片不能被误回收');
    });

    test('不允许删掉最后一页', () {
      final pkg = _openFixture();
      deleteSlide(pkg, 2);
      deleteSlide(pkg, 1);
      expect(
        () => deleteSlide(pkg, 0),
        throwsA(
          isA<PptxEditException>().having(
            (e) => e.message,
            'message',
            contains('至少要保留一页'),
          ),
        ),
      );
    });
  });

  group('moveSlide', () {
    test('把末页挪到最前', () {
      final pkg = _openFixture();
      moveSlide(pkg, 2, 0);
      final outline = describePptxOutline(_roundTrip(pkg));
      expect(
        [for (final s in outline) s.shapes.first.text],
        ['谢谢观看', '原标题', '正文占位'],
      );
    });

    test('把首页挪到末尾', () {
      final pkg = _openFixture();
      moveSlide(pkg, 0, 2);
      final outline = describePptxOutline(_roundTrip(pkg));
      expect(
        [for (final s in outline) s.shapes.first.text],
        ['正文占位', '谢谢观看', '原标题'],
      );
    });

    test('from == to 是空操作；越界报错', () {
      final pkg = _openFixture();
      moveSlide(pkg, 1, 1);
      expect(describePptxOutline(pkg)[1].shapes[0].text, '正文占位');
      expect(
        () => moveSlide(pkg, 0, 7),
        throwsA(isA<PptxEditException>()),
      );
    });
  });

  group('组合编辑（模板填充场景）', () {
    test('复制模板页 → 填文字 → 删掉模板原页，结果合法', () {
      final pkg = _openFixture();
      // 把第 1 页当模板复制两份，各自填内容
      duplicateSlide(pkg, 1, at: 2);
      duplicateSlide(pkg, 1, at: 3);
      setShapeText(pkg, 2, 0, '第一章');
      setShapeText(pkg, 3, 0, '第二章');
      deleteSlide(pkg, 1);

      final reopened = _roundTrip(pkg);
      final outline = describePptxOutline(reopened);
      expect(
        [for (final s in outline) s.shapes.first.text],
        ['原标题', '第一章', '第二章', '谢谢观看'],
      );
      // 两个副本各自独立的备注部件（原模板页的那份随删页一起清掉）
      expect(
        reopened.partNames.where(
          (p) => p.startsWith('ppt/notesSlides/notesSlide'),
        ),
        hasLength(2),
      );
    });

    test('连续多次编辑后 sldId 仍然唯一', () {
      final pkg = _openFixture();
      duplicateSlide(pkg, 0);
      duplicateSlide(pkg, 0);
      deleteSlide(pkg, 1);
      duplicateSlide(pkg, 2);
      final reopened = _roundTrip(pkg);
      final ids = reopened
          .xml('ppt/presentation.xml')
          .findAllElements('sldId', namespace: '*')
          .map((e) => e.getAttribute('id'))
          .toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final id in ids) {
        expect(int.parse(id!), greaterThanOrEqualTo(256));
      }
    });
  });
}
