import 'package:aetherlink_pptx/aetherlink_pptx.dart';
import 'package:test/test.dart';

Map<String, Object?> layoutOf(Map<String, Object?> deck, int i) =>
    ((deck['slides']! as List)[i]! as Map).cast<String, Object?>()['layout']!
        as Map<String, Object?>;

void main() {
  group('buildDeckDraft — 大纲展开', () {
    Map<String, Object?> outline() => {
      'title': '年度汇报',
      'style': 'dark_tech',
      'slides': [
        {'kind': 'cover', 'title': '年度汇报', 'subtitle': '2026', 'meta': '7 月'},
        {'kind': 'toc'},
        {'kind': 'section', 'title': '业务回顾', 'lead': '三条业务线'},
        {
          'title': '核心数据',
          'points': [
            {'value': '87%', 'label': '增长率'},
            {'value': '12 亿', 'label': '营收'},
          ],
          'notes': '强调增长率',
        },
        {
          'title': '关键举措',
          'points': [
            '出海',
            {'title': '降本', 'desc': '供应链重构'},
            {
              'title': '路线',
              'steps': ['立项', '试点', '推广'],
            },
          ],
        },
        {'kind': 'section', 'title': '明年计划'},
        {
          'title': '两个方向',
          'points': [
            {
              'title': '方向一',
              'items': ['子项 A', '子项 B'],
            },
            {
              'title': '方向二',
              'tags': ['AI', '出海', '生态'],
            },
          ],
        },
        {
          'kind': 'end',
          'title': '谢谢',
          'items': ['联系我们'],
        },
      ],
    };

    test('展开为合法 deck：元信息透传、页数一致、可直接解析', () {
      final deck = buildDeckDraft(outline());
      expect(deck['title'], '年度汇报');
      expect(deck['style'], 'dark_tech');
      expect((deck['slides']! as List).length, 8);
      expect(() => DeckDocument.fromJson(deck), returnsNormally);
      final s3 = ((deck['slides']! as List)[3]! as Map).cast<String, Object?>();
      expect(s3['notes'], '强调增长率');
    });

    test('页型映射与要点→卡片分派正确', () {
      final deck = buildDeckDraft(outline());
      expect(layoutOf(deck, 0)['type'], 'cover');
      expect(layoutOf(deck, 2)['type'], 'section');
      final cards = layoutOf(deck, 3)['cards']! as List;
      expect((cards[0] as Map)['type'], 'data');
      expect((cards[0] as Map)['value'], '87%');
      final mixed = layoutOf(deck, 4)['cards']! as List;
      expect(
        [for (final c in mixed) (c as Map)['type']],
        ['text', 'text', 'process'],
      );
      final last = layoutOf(deck, 6)['cards']! as List;
      expect([for (final c in last) (c as Map)['type']], ['list', 'tags']);
    });

    test('叙事节奏：同数量布局在内容页序列上交替，显式 layout 优先', () {
      // 3 个双卡内容页 → split / asymmetric / split 交替。
      Map<String, Object?> page(String t) => {
        'title': t,
        'points': ['a', 'b'],
      };
      final deck = buildDeckDraft({
        'slides': [page('一'), page('二'), page('三')],
      });
      expect(
        [for (var i = 0; i < 3; i++) layoutOf(deck, i)['type']],
        ['split', 'asymmetric', 'split'],
      );
      final forced = buildDeckDraft({
        'slides': [
          {
            'title': '一',
            'layout': 'asymmetric',
            'points': ['a', 'b'],
          },
        ],
      });
      expect(layoutOf(forced, 0)['type'], 'asymmetric');
    });

    test('section 序号自动递进，toc 自动取 section 标题', () {
      final deck = buildDeckDraft(outline());
      expect(layoutOf(deck, 2)['label'], '01');
      expect(layoutOf(deck, 5)['label'], '02');
      expect(layoutOf(deck, 1)['items'], ['业务回顾', '明年计划']);
    });

    test('非法大纲报带定位的错误', () {
      expect(
        () => buildDeckDraft({'slides': <Object?>[]}),
        throwsA(isA<DeckParseException>()),
      );
      for (final (slide, fragment) in [
        (<String, Object?>{'kind': 'cover'}, 'slides[0](cover)'),
        (<String, Object?>{'title': 't'}, 'points'),
        (
          <String, Object?>{
            'title': 't',
            'points': [for (var i = 0; i < 7; i++) 'p$i'],
          },
          '最多 6 条',
        ),
        (
          <String, Object?>{
            'title': 't',
            'points': [
              {'foo': 'bar'},
            ],
          },
          'points[0]',
        ),
        (<String, Object?>{'kind': 'weird', 'title': 't'}, '未知 kind'),
      ]) {
        expect(
          () => buildDeckDraft({
            'slides': [slide],
          }),
          throwsA(
            isA<DeckParseException>().having(
              (e) => e.message,
              'message',
              contains(fragment),
            ),
          ),
          reason: '大纲页 $slide 应当被拒绝',
        );
      }
    });
  });
}
