// 第五阶段：生成类型、角色筛选、额外匹配源（world_book_scan_context.dart +
// selectTimedWorldBookEntries），以及 Outlet（WorldBookInjector.fillOutlets）。

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/world_book/application/world_book_injector.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_import.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_scan_context.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_timed_selection.dart';

const _e = WorldBookEntry(id: '0', content: 'LORE', keywords: ['dragon']);

List<String> ids(
  List<WorldBookEntry> entries, {
  List<String> texts = const ['a dragon'],
  String trigger = WorldBookTrigger.normal,
  WorldBookCharacter? character,
  WorldBookScanSources sources = WorldBookScanSources.none,
}) => [
  for (final e
      in selectTimedWorldBookEntries(
        books: [WorldBook(id: 'b', entries: entries)],
        scanTexts: texts,
        turn: 1,
        trigger: trigger,
        character: character,
        sources: sources,
      ).entries)
    e.id,
];

void main() {
  group('生成类型', () {
    test('不限定时所有类型都可以激活', () {
      for (final t in ['normal', 'continue', 'regenerate', 'swipe']) {
        expect(ids([_e], trigger: t), ['0'], reason: t);
      }
    });

    test('限定后只在列出的类型下激活', () {
      final only = _e.copyWith(triggers: ['regenerate', 'continue']);
      expect(ids([only]), isEmpty);
      expect(ids([only], trigger: WorldBookTrigger.regenerate), ['0']);
      expect(ids([only], trigger: WorldBookTrigger.continueGeneration), ['0']);
    });

    test('常驻条目同样受限', () {
      final c = _e.copyWith(constant: true, triggers: ['continue']);
      expect(ids([c]), isEmpty);
    });
  });

  group('角色筛选', () {
    const lina = WorldBookCharacter(names: ['莉娜', 'asst-1'], tags: ['奇幻']);

    test('没有筛选或不知道当前角色时不筛选', () {
      expect(ids([_e], character: lina), ['0']);
      final f = _e.copyWith(characterFilter: {'names': ['别人']});
      expect(ids([f]), ['0']);
    });

    test('包含模式：名字（不区分大小写，名字或 id 都行）', () {
      expect(
        ids([_e.copyWith(characterFilter: {'names': ['莉娜']})], character: lina),
        ['0'],
      );
      expect(
        ids([_e.copyWith(characterFilter: {'names': ['ASST-1']})], character: lina),
        ['0'],
      );
      expect(
        ids([_e.copyWith(characterFilter: {'names': ['别人']})], character: lina),
        isEmpty,
      );
    });

    test('排除模式反过来', () {
      final f = _e.copyWith(
        characterFilter: {
          'isExclude': true,
          'names': ['莉娜'],
        },
      );
      expect(ids([f], character: lina), isEmpty);
      expect(
        ids([f], character: const WorldBookCharacter(names: ['别人'])),
        ['0'],
      );
    });

    test('标签：助手没有标签信息时跳过标签筛选（同 ST）', () {
      final f = _e.copyWith(characterFilter: {'tags': ['科幻']});
      expect(ids([f], character: lina), isEmpty);
      expect(ids([f.copyWith(characterFilter: {'tags': ['奇幻']})], character: lina), ['0']);
      expect(
        ids([f], character: const WorldBookCharacter(names: ['莉娜'])),
        ['0'],
      );
    });

    test('名字和标签都要通过', () {
      final f = _e.copyWith(
        characterFilter: {
          'names': ['莉娜'],
          'tags': ['科幻'],
        },
      );
      expect(ids([f], character: lina), isEmpty);
    });
  });

  group('额外匹配源', () {
    const sources = WorldBookScanSources(
      characterDescription: '她是一条龙 dragon',
      scenario: '王都 castle',
    );

    test('只在条目勾选的来源里额外查找', () {
      final castle = _e.copyWith(keywords: ['castle']);
      expect(ids([castle], texts: ['x'], sources: sources), isEmpty);
      expect(
        ids([castle.copyWith(matchScenario: true)], texts: ['x'], sources: sources),
        ['0'],
      );
      expect(
        ids(
          [castle.copyWith(matchCharacterDescription: true)],
          texts: ['x'],
          sources: sources,
        ),
        isEmpty,
      );
    });

    test('扫描深度为 0 时不扫描（同 ST），额外来源也不看', () {
      final e = _e.copyWith(scanDepth: 0, matchCharacterDescription: true);
      expect(ids([e], texts: ['x'], sources: sources), isEmpty);
    });

    test('来源按 \\x01 分隔追加在聊天记录之后', () {
      final anchored = _e.copyWith(
        keywords: [r'/\x01王都/'],
        matchScenario: true,
      );
      expect(ids([anchored], texts: ['x'], sources: sources), ['0']);
    });
  });

  group('Outlet', () {
    WorldBookEntry outlet(String id, String name, String content, {int order = 100}) =>
        WorldBookEntry(
          id: id,
          content: content,
          constant: true,
          position: WorldBookInjectionPosition.outlet,
          outletName: name,
          order: order,
        );

    test('替换系统提示词里的 {{outlet::名字}}，不区分大小写', () {
      final entries = [outlet('0', 'Lore', 'A'), outlet('1', 'lore', 'B')];
      expect(
        WorldBookInjector.injectSystem('前 {{outlet::LORE}} 后', entries),
        '前 A\nB 后',
      );
    });

    test('没有对应条目时替换为空，没有条目时也一样', () {
      expect(WorldBookInjector.injectSystem('x{{outlet::none}}y', const []), 'xy');
      expect(
        WorldBookInjector.injectSystem('x{{outlet::none}}y', [outlet('0', 'other', 'A')]),
        'xy',
      );
    });

    test('Outlet 条目不出现在聊天消息和系统提示词前后', () {
      final o = outlet('0', 'lore', 'A');
      expect(WorldBookInjector.injectSystem('base', [o]), 'base');
      expect(WorldBookInjector.injectMessages(const [], [o]), isEmpty);
    });

    test('Outlet 位置已生效，导入时不算「暂不生效」', () {
      expect(WorldBookInjectionPosition.outlet.isImplemented, isTrue);
      expect(worldBookPendingFeatures(outlet('0', 'x', 'A')), isEmpty);
    });
  });

  test('暂不生效判定：只剩本应用没有对应概念的功能', () {
    expect(worldBookPendingFeatures(_e.copyWith(triggers: ['normal'])), isEmpty);
    expect(
      worldBookPendingFeatures(_e.copyWith(triggers: ['quiet'])),
      isNotEmpty,
    );
    expect(
      worldBookPendingFeatures(_e.copyWith(characterFilter: {'names': ['x']})),
      isEmpty,
    );
    expect(worldBookPendingFeatures(_e.copyWith(matchScenario: true)), isEmpty);
    expect(
      worldBookPendingFeatures(_e.copyWith(matchPersonaDescription: true)),
      isNotEmpty,
    );
    expect(
      worldBookPendingFeatures(
        _e.copyWith(position: WorldBookInjectionPosition.authorNoteTop),
      ),
      isNotEmpty,
    );
  });
}
