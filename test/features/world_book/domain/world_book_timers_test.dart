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

/// Drives [entry] across [hits] (true = keyword present this user turn),
/// threading the state turn by turn; returns which turns injected.
List<bool> run(WorldBookEntry entry, List<bool> hits) {
  var state = WorldBookActivationState.empty;
  final out = <bool>[];
  for (var i = 0; i < hits.length; i++) {
    final result = selectTimedWorldBookEntries(
      books: [WorldBook(id: 'b', entries: [entry])],
      scanTexts: [hits[i] ? 'a dragon' : 'nothing'],
      turn: i + 1,
      previous: state,
    );
    out.add(result.entries.isNotEmpty);
    state = WorldBookActivationState.fromJson(result.state.toJson());
  }
  return out;
}

void main() {
  group('sticky', () {
    test('0 = no persistence', () {
      expect(run(_base, [true, false, false]), [true, false, false]);
    });
    test('1 keeps exactly one extra turn', () {
      expect(run(_base.copyWith(sticky: 1), [true, false, false]), [
        true,
        true,
        false,
      ]);
    });
    test('N=3 boundaries: N-1, N, N+1 turns after activation', () {
      // turn1 hit; elapsed 1..3 stay active (N-1=2 ✓, N=3 ✓), N+1=4 off.
      expect(
        run(_base.copyWith(sticky: 3), [true, false, false, false, false]),
        [true, true, true, true, false],
      );
    });
    test('repeated hits inside the window do not extend it', () {
      expect(
        run(_base.copyWith(sticky: 2), [true, true, true, true, false]),
        [true, true, true, true, false],
      );
    });
  });

  group('cooldown', () {
    test('0 = may re-trigger on the very next turn', () {
      expect(run(_base, [true, true, true]), [true, true, true]);
    });
    test('1 blocks one turn after activation', () {
      expect(run(_base.copyWith(cooldown: 1), [true, true, true]), [
        true,
        false,
        true,
      ]);
    });
    test('N=3 boundaries: blocked for N turns, free at N+1', () {
      expect(
        run(_base.copyWith(cooldown: 3), [true, true, true, true, true]),
        [true, false, false, false, true],
      );
    });
    test('cooldown starts after the sticky window', () {
      expect(
        run(
          _base.copyWith(sticky: 1, cooldown: 2),
          [true, false, true, true, true, true],
        ),
        [true, true, false, false, true, true],
      );
    });
  });

  group('delay', () {
    List<bool> always(int delay, int turns) =>
        run(_base.copyWith(delay: delay), List.filled(turns, true));
    test('0 = from the first turn', () {
      expect(always(0, 2), [true, true]);
    });
    test('1 skips turn 1', () {
      expect(always(1, 3), [false, true, true]);
    });
    test('N=3: turns N-1 and N blocked, N+1 allowed', () {
      expect(always(3, 5), [false, false, false, true, true]);
    });
    test('constant entries also respect delay', () {
      final constant = _base.copyWith(
        delay: 2,
        keywords: const [],
        constantActive: true,
      );
      expect(run(constant, [false, false, false]), [false, false, true]);
    });
  });

  test('re-evaluating the same turn with the same previous is idempotent', () {
    final entry = _base.copyWith(sticky: 2, cooldown: 1);
    final books = [WorldBook(id: 'b', entries: [entry])];
    final first = selectTimedWorldBookEntries(
      books: books,
      scanTexts: const ['dragon'],
      turn: 4,
    );
    final again = selectTimedWorldBookEntries(
      books: books,
      scanTexts: const ['dragon'],
      turn: 4,
    );
    expect(again.state.toJson(), first.state.toJson());
    expect(again.entries, first.entries);
  });

  test('editing an entry resets its timed effect', () {
    final entry = _base.copyWith(sticky: 3);
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
      turn: 2,
      previous: first.state,
    );
    expect(edited.entries, isEmpty);
  });

  group('WorldBookActivationState JSON', () {
    test('round-trips the current shape', () {
      const state = WorldBookActivationState(
        turn: 5,
        effects: {'k': WorldBookEffect(activatedAt: 3, signature: 's')},
      );
      final back = WorldBookActivationState.fromJson(state.toJson());
      expect(back.turn, 5);
      expect(back.effects, state.effects);
    });

    test('reads the legacy kelivo / P0 shape (messageCount + historyHash)', () {
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

    test('malformed input never throws', () {
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
            'ok': {'activatedAt': 1},
          },
        },
      ]) {
        final state = WorldBookActivationState.fromJson(raw);
        expect(state.effects.keys, everyElement('ok'));
      }
    });
  });
}
