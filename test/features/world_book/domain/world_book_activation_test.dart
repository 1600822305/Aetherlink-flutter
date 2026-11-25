// 关键词匹配（world_book_activation.dart），对照 SillyTavern `matchKeys` 与
// `checkWorldInfo` 的次级关键词判定；以及按 order 排列注入顺序。

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_macros.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_settings.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_timed_selection.dart';

const _e = WorldBookEntry(id: '0', content: 'LORE', keywords: ['dragon']);

bool hit(WorldBookEntry e, String text, [WorldBookSettings? s]) =>
    WorldBookActivation.matches(
      e,
      text,
      settings: s ?? WorldBookSettings.defaults,
    );

void main() {
  group('普通关键词', () {
    test('默认不区分大小写的子串匹配', () {
      expect(hit(_e, 'A DRAGONFLY'), isTrue);
      expect(hit(_e, 'no match'), isFalse);
    });

    test('区分大小写：条目设置优先，null 跟随全局', () {
      final cs = _e.copyWith(caseSensitive: true);
      expect(hit(cs, 'A DRAGON'), isFalse);
      expect(hit(cs, 'a dragon'), isTrue);
      const globalCs = WorldBookSettings(caseSensitive: true);
      expect(hit(_e, 'A DRAGON', globalCs), isFalse);
      expect(hit(_e.copyWith(caseSensitive: false), 'A DRAGON', globalCs), isTrue);
    });

    test('全词匹配只对单个词生效，含空格的关键词仍是子串', () {
      final whole = _e.copyWith(matchWholeWords: true);
      expect(hit(whole, 'a dragonfly'), isFalse);
      expect(hit(whole, 'a dragon, flying'), isTrue);
      expect(hit(whole, 'dragon'), isTrue);
      final phrase = whole.copyWith(keywords: ['red dragon']);
      expect(hit(phrase, 'the red dragonfly'), isTrue);
      const globalWhole = WorldBookSettings(matchWholeWords: true);
      expect(hit(_e, 'a dragonfly', globalWhole), isFalse);
    });

    test('空白关键词被忽略；没有主关键词的非常驻条目不激活', () {
      expect(hit(_e.copyWith(keywords: ['  ']), 'anything'), isFalse);
      expect(hit(_e.copyWith(keywords: const []), 'dragon'), isFalse);
    });
  });

  group('正则关键词 /pattern/flags', () {
    test('按 flags 决定大小写，不受条目「区分大小写」影响', () {
      final re = _e.copyWith(keywords: [r'/dra\w+n/']);
      expect(hit(re, 'a dragon'), isTrue);
      expect(hit(re, 'A DRAGON'), isFalse);
      expect(hit(re.copyWith(keywords: [r'/dra\w+n/i']), 'A DRAGON'), isTrue);
      expect(
        hit(re.copyWith(keywords: [r'/dra\w+n/i'], caseSensitive: true), 'A DRAGON'),
        isTrue,
      );
    });

    test('正则与普通关键词可以混写', () {
      final mixed = _e.copyWith(keywords: ['knight', r'/^\d+$/']);
      expect(hit(mixed, 'a KNIGHT'), isTrue);
      expect(hit(mixed, '42'), isTrue);
      expect(hit(mixed, 'nothing'), isFalse);
    });

    test('写法不合法时当作普通文本', () {
      expect(WorldBookActivation.parseRegex('/(/'), isNull);
      expect(hit(_e.copyWith(keywords: ['/(/']), 'literal /(/ here'), isTrue);
      expect(WorldBookActivation.parseRegex('/a/ii'), isNull);
      expect(WorldBookActivation.parseRegex('/a/b/'), isNull);
      expect(WorldBookActivation.parseRegex(r'/a\/b/'), isNotNull);
      expect(WorldBookActivation.parseRegex('plain'), isNull);
    });

    test('looksLikeRegex 用于编辑器提示', () {
      expect(WorldBookActivation.looksLikeRegex('/(/'), isTrue);
      expect(WorldBookActivation.looksLikeRegex('/ok/gi'), isTrue);
      expect(WorldBookActivation.looksLikeRegex('dragon'), isFalse);
    });
  });

  group('次级关键词', () {
    final base = _e.copyWith(secondaryKeywords: ['wing', 'fire']);
    WorldBookEntry withLogic(WorldBookSecondaryLogic l) =>
        base.copyWith(secondaryLogic: l);

    test('主关键词没命中时不激活', () {
      for (final l in WorldBookSecondaryLogic.values) {
        expect(hit(withLogic(l), 'wing fire'), isFalse, reason: '$l');
      }
    });

    test('四种逻辑', () {
      const none = 'dragon';
      const one = 'dragon wing';
      const both = 'dragon wing fire';
      final cases = {
        WorldBookSecondaryLogic.andAny: [false, true, true],
        WorldBookSecondaryLogic.andAll: [false, false, true],
        WorldBookSecondaryLogic.notAny: [true, false, false],
        WorldBookSecondaryLogic.notAll: [true, true, false],
      };
      for (final MapEntry(key: logic, value: want) in cases.entries) {
        expect(
          [for (final t in [none, one, both]) hit(withLogic(logic), t)],
          want,
          reason: '$logic',
        );
      }
    });

    test('关闭 selective 或次级列表为空时只看主关键词', () {
      expect(hit(base.copyWith(selective: false), 'dragon'), isTrue);
      expect(
        hit(withLogic(WorldBookSecondaryLogic.andAll).copyWith(secondaryKeywords: const []), 'dragon'),
        isTrue,
      );
    });
  });

  test('常驻总是激活，关闭的条目从不激活', () {
    expect(hit(_e.copyWith(constant: true, keywords: const []), ''), isTrue);
    expect(hit(_e.copyWith(constant: true, enabled: false), 'dragon'), isFalse);
  });

  group('selectTimedWorldBookEntries', () {
    List<String> ids(List<WorldBook> books, {List<String> texts = const ['dragon']}) => [
      for (final e
          in selectTimedWorldBookEntries(books: books, scanTexts: texts, turn: 1).entries)
        e.id,
    ];

    test('按 order 从小到大注入；同 order 时书序优先，书内 uid 大的在前', () {
      final b1 = WorldBook(
        id: 'b1',
        entries: [
          _e.copyWith(id: '0', order: 100),
          _e.copyWith(id: '1', order: 100),
          _e.copyWith(id: '2', order: 50),
          _e.copyWith(id: '3', order: 300),
        ],
      );
      final b2 = WorldBook(id: 'b2', entries: [_e.copyWith(id: '9', order: 100)]);
      expect(ids([b1, b2]), ['2', '1', '0', '9', '3']);
    });

    test('扫描深度 null 跟随全局（默认最近 2 条）', () {
      final books = [WorldBook(id: 'b', entries: [_e])];
      expect(ids(books, texts: ['dragon', 'a', 'b']), isEmpty);
      expect(ids(books, texts: ['a', 'dragon', 'b']), ['0']);
      final deep = [WorldBook(id: 'b', entries: [_e.copyWith(scanDepth: 3)])];
      expect(ids(deep, texts: ['dragon', 'a', 'b']), ['0']);
      final zero = [WorldBook(id: 'b', entries: [_e.copyWith(scanDepth: 0)])];
      expect(ids(zero, texts: ['dragon']), isEmpty);
    });

    test('扫描文本：最近的在前，\x01 开头、\n\x01 分隔（可按消息锚定正则）', () {
      // 只匹配「某条消息以 hello 开头」。
      final anchored = WorldBook(
        id: 'b',
        entries: [_e.copyWith(keywords: [r'/\x01hello/'], scanDepth: 5)],
      );
      expect(ids([anchored], texts: ['say hello', 'x']), isEmpty);
      expect(ids([anchored], texts: ['x', 'hello there']), ['0']);
      // 最近的在前：跨两条消息的「b\n\x01a」只在 a 早于 b 时出现。
      final order = WorldBook(
        id: 'b',
        entries: [_e.copyWith(keywords: [r'/b\n\x01a/'], scanDepth: 5)],
      );
      expect(ids([order], texts: ['a', 'b']), ['0']);
      expect(ids([order], texts: ['b', 'a']), isEmpty);
    });

    test('名字前缀由调用方加好后可以按说话人匹配', () {
      final byUser = WorldBook(
        id: 'b',
        entries: [_e.copyWith(keywords: [r'/\x01小明:[^\x01]*hello/'], scanDepth: 5)],
      );
      final texts = [
        worldBookScanLine('hello', name: '莉娜'),
        worldBookScanLine('hi', name: '小明'),
      ];
      expect(ids([byUser], texts: texts), isEmpty);
      expect(
        ids([byUser], texts: [...texts, worldBookScanLine('well hello', name: '小明')]),
        ['0'],
      );
    });

    test('宏：关键词匹配前替换，触发条目的内容返回前替换', () {
      const macros = WorldBookMacroContext(user: '小明', char: '莉娜');
      final book = WorldBook(
        id: 'b',
        entries: [
          _e.copyWith(keywords: ['{{char}}'], content: '{{user}} 认识 {{char}}'),
        ],
      );
      final hit = selectTimedWorldBookEntries(
        books: [book],
        scanTexts: const ['我是莉娜'],
        turn: 1,
        macros: macros,
      );
      expect(hit.entries.single.content, '小明 认识 莉娜');
      final miss = selectTimedWorldBookEntries(
        books: [book],
        scanTexts: const ['{{char}}'],
        turn: 1,
        macros: macros,
      );
      expect(miss.entries, isEmpty);
      // 不给 macros 时原样匹配、原样返回。
      final raw = selectTimedWorldBookEntries(
        books: [book],
        scanTexts: const ['{{char}}'],
        turn: 1,
      );
      expect(raw.entries.single.content, '{{user}} 认识 {{char}}');
    });

    test('关闭的书、关闭或空内容的条目不参与', () {
      expect(
        ids([
          WorldBook(id: 'off', enabled: false, entries: [_e]),
          WorldBook(
            id: 'b',
            entries: [
              _e.copyWith(id: '1', enabled: false),
              _e.copyWith(id: '2', content: '  ', constant: true),
            ],
          ),
        ]),
        isEmpty,
      );
    });
  });
}
