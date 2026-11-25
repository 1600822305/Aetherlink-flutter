// 计时器（持续 / 冷却 / 延迟），逐条对照 SillyTavern `WorldInfoTimedEffects`：
// 全部按消息条数（ST `chat.length`）计算。模拟一来一回的普通对话：第 k 次生成时
// 的消息序号是 2k-1（1、3、5、7…）。

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation_state.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_timed_selection.dart';

const _base = WorldBookEntry(
  id: 'e',
  content: 'LORE',
  keywords: ['dragon'],
  scanDepth: 1,
);

/// Drives [entry] across [hits] (true = keyword present at that generation),
/// threading the state; generation i is evaluated at message number 2i+1.
List<bool> run(WorldBookEntry entry, List<bool> hits) {
  var state = WorldBookActivationState.empty;
  final out = <bool>[];
  for (var i = 0; i < hits.length; i++) {
    final result = selectTimedWorldBookEntries(
      books: [WorldBook(id: 'b', entries: [entry])],
      scanTexts: [hits[i] ? 'a dragon' : 'nothing'],
      turn: 2 * i + 1,
      previous: state,
    );
    out.add(result.entries.isNotEmpty);
    state = WorldBookActivationState.fromJson(result.state.toJson());
  }
  return out;
}

void main() {
  group('持续（sticky）', () {
    test('0 = 不保持', () {
      expect(run(_base, [true, false, false]), [true, false, false]);
    });

    test('按消息计：激活在第 1 条，保持到第 1 + sticky 条之前', () {
      // sticky 2：第 3 条时 3 < 1+2 不成立 → 已到期（ST 同样如此）。
      expect(run(_base.copyWith(sticky: 2), [true, false, false]), [true, false, false]);
      // sticky 3：第 3 条仍在持续里，第 5 条到期。
      expect(run(_base.copyWith(sticky: 3), [true, false, false]), [true, true, false]);
      // sticky 5：第 3、5 条持续，第 7 条到期。
      expect(
        run(_base.copyWith(sticky: 5), [true, false, false, false]),
        [true, true, true, false],
      );
    });

    test('持续期间再次命中不会延长', () {
      expect(
        run(_base.copyWith(sticky: 3), [true, true, false, false]),
        [true, true, false, false],
      );
    });
  });

  group('冷却（cooldown）', () {
    test('0 = 下一次就能再触发', () {
      expect(run(_base, [true, true, true]), [true, true, true]);
    });

    test('没有持续时从激活起算：第 1 + cooldown 条之前不能激活', () {
      // cooldown 2：第 3 条已不在冷却里。
      expect(run(_base.copyWith(cooldown: 2), [true, true, true]), [true, true, true]);
      // cooldown 3：第 3 条冷却，第 5 条重新激活，第 7 条又冷却。
      expect(
        run(_base.copyWith(cooldown: 3), [true, true, true, true, true]),
        [true, false, true, false, true],
      );
      expect(
        run(_base.copyWith(cooldown: 5), [true, true, true, true]),
        [true, false, false, true],
      );
    });

    test('有持续时，从持续到期的那一条重新起算冷却', () {
      // sticky 3：第 1 条激活、第 3 条持续；第 5 条到期 → 冷却从 5 起算，
      // cooldown 3 时第 5、7 条都在冷却里，第 9 条才能再激活。
      expect(
        run(
          _base.copyWith(sticky: 3, cooldown: 3),
          [true, true, true, true, true],
        ),
        [true, true, false, false, true],
      );
    });

    test('冷却起点写进状态，跨轮保持', () {
      final entry = _base.copyWith(sticky: 3, cooldown: 3);
      final books = [WorldBook(id: 'b', entries: [entry])];
      var state = selectTimedWorldBookEntries(
        books: books,
        scanTexts: const ['dragon'],
        turn: 1,
      ).state;
      state = selectTimedWorldBookEntries(
        books: books,
        scanTexts: const ['x'],
        turn: 5,
        previous: state,
      ).state;
      final effect = state.effects.values.single;
      expect(effect.activatedAt, 1);
      expect(effect.cooldownFrom, 5);
    });
  });

  group('延迟（delay）', () {
    List<bool> always(int delay, int generations) =>
        run(_base.copyWith(delay: delay), List.filled(generations, true));

    test('0、1 都不限制（第 1 条时 1 < 1 不成立）', () {
      expect(always(0, 2), [true, true]);
      expect(always(1, 2), [true, true]);
    });

    test('N：消息数小于 N 时不能激活', () {
      expect(always(3, 3), [false, true, true]);
      expect(always(4, 3), [false, false, true]);
    });

    test('常驻条目同样受延迟限制', () {
      final constant = _base.copyWith(
        delay: 4,
        keywords: const [],
        constant: true,
      );
      expect(run(constant, [false, false, false]), [false, false, true]);
    });
  });

  test('同一条消息、同样的上一轮状态重复评估结果相同', () {
    final entry = _base.copyWith(sticky: 3, cooldown: 2);
    final books = [WorldBook(id: 'b', entries: [entry])];
    final first = selectTimedWorldBookEntries(
      books: books,
      scanTexts: const ['dragon'],
      turn: 7,
    );
    final again = selectTimedWorldBookEntries(
      books: books,
      scanTexts: const ['dragon'],
      turn: 7,
    );
    expect(again.state.toJson(), first.state.toJson());
    expect(again.entries, first.entries);
  });

  test('编辑过的条目计时重新开始', () {
    final entry = _base.copyWith(sticky: 5);
    final first = selectTimedWorldBookEntries(
      books: [WorldBook(id: 'b', entries: [entry])],
      scanTexts: const ['dragon'],
      turn: 1,
    );
    final edited = selectTimedWorldBookEntries(
      books: [
        WorldBook(id: 'b', entries: [entry.copyWith(content: 'NEW')]),
      ],
      scanTexts: const ['nothing'],
      turn: 3,
      previous: first.state,
    );
    expect(edited.entries, isEmpty);
  });

  group('WorldBookActivationState JSON', () {
    test('往返当前格式（含冷却起点）', () {
      const state = WorldBookActivationState(
        turn: 5,
        effects: {
          'k': WorldBookEffect(activatedAt: 3, signature: 's'),
          'c': WorldBookEffect(activatedAt: 1, signature: 't', cooldownFrom: 4),
        },
      );
      final back = WorldBookActivationState.fromJson(state.toJson());
      expect(back.turn, 5);
      expect(back.effects, state.effects);
      expect(state.toJson()['version'], 3);
      expect((state.toJson()['effects'] as Map)['k'], isNot(contains('cooldownFrom')));
    });

    test('读旧的 messageCount 格式', () {
      final legacy = <String, dynamic>{
        'messageCount': 4,
        'historyHash': 'abc',
        'effects': {
          '["b","e"]': {'signature': 'sig', 'activatedAt': 2},
        },
      };
      final state = WorldBookActivationState.fromJson(legacy);
      expect(state.turn, 4);
      expect(
        state.effects['["b","e"]'],
        const WorldBookEffect(activatedAt: 2, signature: 'sig'),
      );
    });

    test('格式不对时从不抛异常', () {
      for (final raw in <Object?>[
        null,
        'x',
        42,
        <Object?>[],
        {'turn': 'x', 'effects': 'y'},
        {
          'turn': 2,
          'effects': {
            'bad': 1,
            'future': {'activatedAt': 9},
            'ok': {'activatedAt': 1, 'cooldownFrom': 'x'},
          },
        },
      ]) {
        final state = WorldBookActivationState.fromJson(raw);
        expect(state.effects.keys, everyElement('ok'));
        for (final e in state.effects.values) {
          expect(e.cooldownFrom, isNull);
        }
      }
    });
  });
}
