// 世界书导入 / 导出（world_book_import.dart / world_book_export.dart /
// WorldBook.toJson）：
// - SillyTavern 原生文件逐字段读入，未知键进 extra，再导出与原文件一致；
// - 字段缺失 / 类型不对时取 ST 默认值；
// - kelivo / RikkaHub 旧格式（entries 为数组）按映射规则转换；
// - 用到暂未实现功能的条目照常启用，只计入 pendingEntryCount；
// - normalizeImportedWorldBook 的 id 整理规则。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_export.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_import.dart';

/// 一条字段齐全的 ST 条目（取 ST 编辑器新建条目后再改过的值）。
Map<String, dynamic> stEntry(int uid, [Map<String, dynamic> overrides = const {}]) => {
  'uid': uid,
  'key': ['dragon', '/dra\\w+n/i'],
  'keysecondary': ['wing'],
  'comment': 'Dragon',
  'content': 'A dragon lives in the mountains.',
  'constant': false,
  'vectorized': false,
  'selective': true,
  'selectiveLogic': 2,
  'addMemo': true,
  'order': 250,
  'position': 4,
  'disable': false,
  'excludeRecursion': true,
  'preventRecursion': false,
  'delayUntilRecursion': 2,
  'probability': 60,
  'useProbability': true,
  'depth': 3,
  'outletName': '',
  'group': 'beasts,fire',
  'groupOverride': true,
  'groupWeight': 30,
  'scanDepth': 5,
  'caseSensitive': true,
  'matchWholeWords': false,
  'useGroupScoring': null,
  'automationId': 'qr-1',
  'role': 2,
  'sticky': 2,
  'cooldown': 1,
  'delay': null,
  'ignoreBudget': true,
  'triggers': ['normal', 'swipe'],
  'characterFilter': {
    'isExclude': true,
    'names': ['alice.png'],
    'tags': <String>[],
  },
  'matchPersonaDescription': false,
  'matchCharacterDescription': true,
  'matchCharacterPersonality': false,
  'matchCharacterDepthPrompt': false,
  'matchScenario': false,
  'matchCreatorNotes': false,
  'displayIndex': 0,
  ...overrides,
};

WorldBookImportResult parse(Object json, {String fileName = 'x.json'}) =>
    parseWorldBookImport(jsonDecode(jsonEncode(json)), fileName: fileName)!;

void main() {
  group('SillyTavern 原生文件', () {
    test('所有字段逐一读入', () {
      final e = parse({
        'entries': {'7': stEntry(7)},
      }).book.entries.single;
      expect(e.id, '7');
      expect(e.name, 'Dragon');
      expect(e.keywords, ['dragon', r'/dra\w+n/i']);
      expect(e.secondaryKeywords, ['wing']);
      expect(e.secondaryLogic, WorldBookSecondaryLogic.notAny);
      expect(e.addMemo, isTrue);
      expect(e.order, 250);
      expect(e.position, WorldBookInjectionPosition.atDepth);
      expect(e.depth, 3);
      expect(e.role, WorldBookInjectionRole.assistant);
      expect(e.excludeRecursion, isTrue);
      expect(e.delayUntilRecursion, 2);
      expect(e.probability, 60);
      expect(e.groups, ['beasts', 'fire']);
      expect(e.groupOverride, isTrue);
      expect(e.groupWeight, 30);
      expect(e.useGroupScoring, isNull);
      expect(e.scanDepth, 5);
      expect(e.caseSensitive, isTrue);
      expect(e.matchWholeWords, isFalse);
      expect(e.automationId, 'qr-1');
      expect([e.sticky, e.cooldown, e.delay], [2, 1, null]);
      expect(e.ignoreBudget, isTrue);
      expect(e.triggers, ['normal', 'swipe']);
      expect(e.characterFilter?['names'], ['alice.png']);
      expect(e.matchCharacterDescription, isTrue);
      expect(e.extra, isEmpty);
    });

    test('导入后条目保持原来的开关，不再因为「不支持」被禁用', () {
      final result = parse({
        'entries': {
          '0': stEntry(0),
          '1': stEntry(1, {'disable': true}),
          '2': stEntry(2, {
            'probability': 100,
            'group': '',
            'excludeRecursion': false,
            'delayUntilRecursion': 0,
            'sticky': null,
            'cooldown': null,
            'automationId': '',
            'triggers': <String>[],
            'characterFilter': null,
            'matchCharacterDescription': false,
          }),
        },
      });
      expect(result.book.entries.map((e) => e.enabled), [true, false, true]);
      // 0、1 用到了概率 / 包含组 / 递归等暂未实现的功能；2 全部已实现。
      expect(result.pendingEntryCount, 2);
      expect(worldBookPendingFeatures(result.book.entries[2]), isEmpty);
    });

    test('导出再导入完全一致，未知键原样保留', () {
      final file = {
        'entries': {
          '0': stEntry(0, {'futureField': 'kept', 'displayIndex': 1}),
          '3': stEntry(3, {'comment': 'Second', 'displayIndex': 0}),
        },
        'originalData': {'name': 'from a character card'},
      };
      final book = parse(file, fileName: '山海.json').book;
      expect(book.name, '山海');
      // 按 displayIndex 排序。
      expect(book.entries.map((e) => e.id), ['3', '0']);
      expect(book.entries[1].extra, {'futureField': 'kept'});
      expect(book.extra, {
        'originalData': {'name': 'from a character card'},
      });

      final exported =
          jsonDecode(encodeWorldBookExport(book)) as Map<String, dynamic>;
      final entries = (exported['entries'] as Map).cast<String, dynamic>();
      expect(entries.keys, ['3', '0']);
      expect(entries['0'], {...stEntry(0, {'futureField': 'kept'}), 'displayIndex': 1});
      expect(entries['3'], {...stEntry(3, {'comment': 'Second'}), 'displayIndex': 0});
      expect(exported['originalData'], {'name': 'from a character card'});

      final back = parse(exported).book;
      expect(back.entries, book.entries);
      expect(back.extra, book.extra);
    });

    test('缺失或类型不对的字段取 ST 默认值', () {
      final e = parse({
        'entries': {
          '5': {'content': 'x', 'order': 'oops', 'role': null, 'sticky': 'a'},
        },
      }).book.entries.single;
      expect(e.id, '5');
      expect(e.order, 100);
      expect(e.position, WorldBookInjectionPosition.beforeSystemPrompt);
      expect(e.depth, 4);
      expect(e.role, WorldBookInjectionRole.system);
      expect(e.selective, isTrue);
      expect(e.useProbability, isTrue);
      expect(e.probability, 100);
      expect(e.groupWeight, 100);
      expect(e.scanDepth, isNull);
      expect(e.caseSensitive, isNull);
      expect(e.sticky, isNull);
      expect(e.enabled, isTrue);
    });

    test('delayUntilRecursion：true 读作 1，false 读作 0', () {
      final book = parse({
        'entries': {
          '0': {'content': 'a', 'delayUntilRecursion': true},
          '1': {'content': 'b', 'delayUntilRecursion': false},
        },
      }).book;
      expect(book.entries.map((e) => e.delayUntilRecursion), [1, 0]);
    });

    test('外面包一层 data 的文件也能读', () {
      final result = parse({
        'version': 1,
        'data': {
          'entries': {'0': stEntry(0)},
        },
      });
      expect(result.book.entries, hasLength(1));
    });

    test('无法识别的文件返回 null', () {
      for (final bad in [
        <String, dynamic>{},
        {'entries': 'nope'},
        {
          'entries': {'0': 'not a map'},
        },
        [1, 2],
      ]) {
        expect(
          parseWorldBookImport(jsonDecode(jsonEncode(bad)), fileName: 'x'),
          isNull,
          reason: '$bad',
        );
      }
    });
  });

  group('kelivo / RikkaHub 旧格式', () {
    test('字段映射到 ST 结构', () {
      final book = parse({
        'id': 'old',
        'name': 'Legacy',
        'entries': [
          {
            'id': 'a',
            'name': 'Regex',
            'content': 'R',
            'keywords': ['dra\\w+', 'a/b'],
            'useRegex': true,
            'caseSensitive': false,
            'priority': 5,
            'position': 'AT_DEPTH',
            'injectDepth': 2,
            'role': 'ASSISTANT',
            'scanDepth': 6,
            'sticky': 0,
            'cooldown': 3,
          },
          {
            'id': 'b',
            'content': 'C',
            'constantActive': true,
            'position': 'BOTTOM_OF_CHAT',
          },
          {'id': 'c', 'content': 'T', 'position': 'TOP_OF_CHAT'},
        ],
      }).book;
      final a = book.entries[0];
      expect(a.keywords, [r'/dra\w+/i', r'/a\/b/i']);
      expect(a.order, -5);
      expect(a.position, WorldBookInjectionPosition.atDepth);
      expect(a.depth, 2);
      expect(a.role, WorldBookInjectionRole.assistant);
      expect(a.scanDepth, 6);
      expect(a.sticky, isNull);
      expect(a.cooldown, 3);
      final b = book.entries[1];
      expect(b.constant, isTrue);
      expect(b.position, WorldBookInjectionPosition.atDepth);
      expect(b.depth, 1);
      expect(b.role, WorldBookInjectionRole.user);
      expect(book.entries[2].position, WorldBookInjectionPosition.afterSystemPrompt);
    });
  });

  group('normalizeImportedWorldBook', () {
    test('书 id 冲突时重新生成，条目 uid 整理成不重复的数字', () {
      const book = WorldBook(
        id: 'dup',
        entries: [
          WorldBookEntry(id: '3'),
          WorldBookEntry(id: '3'),
          WorldBookEntry(id: 'abc'),
          WorldBookEntry(id: '1'),
        ],
      );
      final normalized = normalizeImportedWorldBook(
        book,
        existingBookIds: {'dup'},
      );
      expect(normalized.id, isNot('dup'));
      expect(normalized.entries.map((e) => e.id), ['3', '4', '5', '1']);
    });
  });

  test('WorldBook.nextEntryId 取最大数字 uid + 1', () {
    expect(const WorldBook(id: 'b').nextEntryId(), '0');
    expect(
      const WorldBook(
        id: 'b',
        entries: [WorldBookEntry(id: '2'), WorldBookEntry(id: 'x')],
      ).nextEntryId(),
      '3',
    );
  });
}
