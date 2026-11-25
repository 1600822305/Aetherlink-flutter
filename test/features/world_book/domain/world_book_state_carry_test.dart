// 计时状态的继承（被跳过 / 没绑定的条目不丢状态），以及激活原因。

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation_state.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_settings.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_timed_selection.dart';

const _e = WorldBookEntry(
  id: '0',
  content: 'LORE',
  keywords: ['dragon'],
  scanDepth: 1,
);

WorldBookTimedResult _run(
  List<WorldBook> books, {
  required int turn,
  String text = 'a dragon',
  WorldBookActivationState previous = WorldBookActivationState.empty,
  String trigger = 'normal',
  WorldBookSettings settings = WorldBookSettings.defaults,
}) {
  final r = selectTimedWorldBookEntries(
    books: books,
    scanTexts: [text],
    turn: turn,
    previous: previous,
    trigger: trigger,
    settings: settings,
  );
  // 模拟存进消息元数据再读出来。
  return (
    entries: r.entries,
    reasons: r.reasons,
    state: WorldBookActivationState.fromJson(r.state.toJson()),
    budgetOverflowed: r.budgetOverflowed,
  );
}

void main() {
  group('计时状态继承', () {
    test('因生成类型被跳过的一轮，冷却不会被清掉', () {
      final entry = _e.copyWith(cooldown: 5, triggers: ['normal']);
      final books = [WorldBook(id: 'b', entries: [entry])];
      final first = _run(books, turn: 1);
      expect(first.entries, hasLength(1));
      // 第 3 条是「继续生成」：条目不参与，但冷却状态要保留。
      final skipped = _run(
        books,
        turn: 3,
        previous: first.state,
        trigger: 'continue',
      );
      expect(skipped.entries, isEmpty);
      expect(skipped.state.effects, isNotEmpty);
      // 第 5 条仍在冷却（5 < 1 + 5），第 7 条才能再激活。
      final cooling = _run(books, turn: 5, previous: skipped.state);
      expect(cooling.entries, isEmpty);
      expect(_run(books, turn: 7, previous: cooling.state).entries, hasLength(1));
    });

    test('持续中被关掉再打开：计时接着算（开关不算修改）', () {
      final entry = _e.copyWith(sticky: 9);
      final first = _run([WorldBook(id: 'b', entries: [entry])], turn: 1);
      final off = _run(
        [
          WorldBook(id: 'b', entries: [entry.copyWith(enabled: false)]),
        ],
        turn: 3,
        text: 'x',
        previous: first.state,
      );
      expect(off.entries, isEmpty);
      final on = _run(
        [WorldBook(id: 'b', entries: [entry])],
        turn: 5,
        text: 'x',
        previous: off.state,
      );
      // 第 5 条：5 < 1 + 9，仍在持续里。
      expect(on.entries, hasLength(1));
    });

    test('只有改关键词 / 内容 / 计时设置才重置计时', () {
      final entry = _e.copyWith(sticky: 9);
      final first = _run([WorldBook(id: 'b', entries: [entry])], turn: 1);
      List<WorldBookEntry> at3(WorldBookEntry e) => _run(
        [WorldBook(id: 'b', entries: [e])],
        turn: 3,
        text: 'x',
        previous: first.state,
      ).entries;
      expect(at3(entry.copyWith(order: 5, name: '改名')), hasLength(1));
      expect(at3(entry.copyWith(content: 'NEW')), isEmpty);
      expect(at3(entry.copyWith(keywords: ['phoenix'])), isEmpty);
      expect(at3(entry.copyWith(sticky: 8)), isEmpty);
    });

    test('这次没绑定的书，状态原样保留，换回来接着算', () {
      final entry = _e.copyWith(sticky: 9);
      final a = WorldBook(id: 'a', entries: [entry]);
      const other = WorldBook(id: 'o', entries: <WorldBookEntry>[]);
      final first = _run([a], turn: 1);
      final away = _run([other], turn: 3, text: 'x', previous: first.state);
      expect(away.state.effects.keys, first.state.effects.keys);
      // 第 5 条换回来：5 < 1 + 9，仍在持续里。
      final back = _run([a], turn: 5, text: 'x', previous: away.state);
      expect(back.entries, hasLength(1));
    });

    test('书还在、条目已删除的状态被丢弃', () {
      final entry = _e.copyWith(sticky: 9);
      final first = _run([WorldBook(id: 'b', entries: [entry])], turn: 1);
      final gone = _run(
        [const WorldBook(id: 'b', entries: <WorldBookEntry>[])],
        turn: 3,
        previous: first.state,
      );
      expect(gone.state.effects, isEmpty);
    });
  });

  group('激活原因', () {
    List<String> reasons(
      List<WorldBookEntry> entries, {
      String text = 'a dragon',
      WorldBookSettings settings = WorldBookSettings.defaults,
      String bookName = '',
    }) => _run(
      [WorldBook(id: 'b', name: bookName, entries: entries)],
      turn: 1,
      text: text,
      settings: settings,
    ).reasons;

    test('关键词：写出命中的那个', () {
      expect(
        reasons([
          _e.copyWith(keywords: ['phoenix', 'dragon']),
        ]),
        ['关键词「dragon」'],
      );
    });

    test('常驻 / @@activate', () {
      expect(reasons([_e.copyWith(constant: true)], text: 'x'), ['常驻']);
      expect(
        reasons([_e.copyWith(content: '@@activate\nLORE')], text: 'x'),
        ['@@activate'],
      );
    });

    test('次级关键词', () {
      final e = _e.copyWith(
        selective: true,
        secondaryKeywords: ['fire', 'ice'],
      );
      expect(reasons([e], text: 'dragon fire'), ['关键词「dragon」 + 次级「fire」']);
      expect(
        reasons([
          e.copyWith(secondaryLogic: WorldBookSecondaryLogic.notAny),
        ], text: 'dragon'),
        ['关键词「dragon」，且不含任何次级关键词'],
      );
    });

    test('递归触发', () {
      final a = _e.copyWith(id: '1', content: 'the castle');
      final b = _e.copyWith(id: '2', keywords: ['castle'], content: 'CASTLE');
      final r = reasons(
        [a, b],
        settings: WorldBookSettings.defaults.copyWith(recursive: true),
      );
      expect(r, contains('由其他条目内容触发：关键词「castle」'));
    });

    test('持续中', () {
      final entry = _e.copyWith(sticky: 9);
      final books = [WorldBook(id: 'b', entries: [entry])];
      final first = _run(books, turn: 1);
      final r = _run(books, turn: 3, text: 'x', previous: first.state);
      expect(r.reasons, ['持续中（第 1 条消息时激活）']);
    });

    test('附上所在的书名', () {
      expect(reasons([_e], bookName: '设定集'), ['关键词「dragon」 · 《设定集》']);
    });

    test('与 entries 一一对应', () {
      final r = _run(
        [
          WorldBook(
            id: 'b',
            entries: [
              _e.copyWith(id: '1', order: 5),
              _e.copyWith(id: '2', constant: true, order: 1),
            ],
          ),
        ],
        turn: 1,
      );
      expect(r.entries.map((e) => e.id), ['2', '1']);
      expect(r.reasons, ['常驻', '关键词「dragon」']);
    });
  });

  test('本应用没有对应位置的条目不参与激活（不占预算、不进「本轮注入」）', () {
    final r = _run(
      [
        WorldBook(
          id: 'b',
          entries: [
            _e.copyWith(id: '1', position: WorldBookInjectionPosition.authorNoteTop),
            _e.copyWith(id: '2'),
          ],
        ),
      ],
      turn: 1,
    );
    expect(r.entries.map((e) => e.id), ['2']);
  });

  test('没被提示词引用的 Outlet 条目不参与', () {
    final outlet = _e.copyWith(
      id: '1',
      constant: true,
      position: WorldBookInjectionPosition.outlet,
      outletName: 'Lore',
    );
    List<String> ids(Set<String>? names) => [
      for (final e in selectTimedWorldBookEntries(
        books: [WorldBook(id: 'b', entries: [outlet])],
        scanTexts: const ['x'],
        turn: 1,
        outletNames: names,
      ).entries)
        e.id,
    ];
    expect(ids(null), ['1']);
    expect(ids(const {}), isEmpty);
    expect(ids(worldBookOutletNamesIn(['前 {{outlet:: LORE }} 后'])), ['1']);
  });
}
