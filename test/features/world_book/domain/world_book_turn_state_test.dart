import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation_state.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_timed_selection.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_turn_state.dart';

WorldBookPathNode user([WorldBookActivationState? state]) => (
  isUserTurn: true,
  isSummary: false,
  metadata: state?.writeTo(null),
);

const WorldBookPathNode assistant = (
  isUserTurn: false,
  isSummary: false,
  metadata: null,
);

WorldBookPathNode summary([WorldBookActivationState? state]) => (
  isUserTurn: false,
  isSummary: true,
  metadata: state?.writeTo({'isSummary': true}) ?? {'isSummary': true},
);

const _sticky = WorldBookEntry(
  id: 'e',
  content: 'LORE',
  keywords: ['dragon'],
  scanDepth: 1,
  sticky: 2,
);
final _books = [WorldBook(id: 'b', entries: [_sticky])];

/// Evaluates one user turn on top of [ancestors]; returns (active, newNode).
(bool, WorldBookPathNode) step(List<WorldBookPathNode> ancestors, String text) {
  final clock = resolveWorldBookClock(ancestors);
  final result = selectTimedWorldBookEntries(
    books: _books,
    scanTexts: [text],
    turn: clock.turn,
    previous: clock.previous,
  );
  return (result.entries.isNotEmpty, user(result.state));
}

void main() {
  test('turn numbers count user turns only, from the nearest state', () {
    expect(resolveWorldBookClock(const []).turn, 1);
    expect(resolveWorldBookClock([user(), assistant, user(), assistant]).turn, 3);
    final clock = resolveWorldBookClock([
      user(const WorldBookActivationState(turn: 7)),
      assistant,
      user(),
      assistant,
    ]);
    expect(clock.previous.turn, 7);
    expect(clock.turn, 9);
  });

  test('a fork does not leak timer state between branches', () {
    final (hit, u1) = step(const [], 'a dragon');
    expect(hit, isTrue);
    final trunk = [u1, assistant];

    // Branch A keeps going: sticky carries for two more turns.
    final (a2, ua2) = step(trunk, 'nothing');
    final (a3, ua3) = step([...trunk, ua2, assistant], 'nothing');
    final (a4, _) = step([...trunk, ua2, assistant, ua3, assistant], 'nothing');
    expect([a2, a3, a4], [true, true, false]);

    // Branch B forks from the trunk again: it sees the trunk's state only,
    // never branch A's later turns, so its clock restarts at turn 2.
    final clockB = resolveWorldBookClock(trunk);
    expect(clockB.turn, 2);
    expect(clockB.previous.turn, 1);
    final (b2, _) = step(trunk, 'nothing');
    expect(b2, isTrue);
  });

  test('regenerating a turn re-reads the same ancestors (idempotent)', () {
    final (_, u1) = step(const [], 'a dragon');
    final first = step([u1, assistant], 'nothing');
    final again = step([u1, assistant], 'nothing');
    expect(first.$1, again.$1);
    expect(first.$2.metadata, again.$2.metadata);
  });

  test('compression keeps the clock via the summary node', () {
    final (_, u1) = step(const [], 'a dragon');
    final (_, u2) = step([u1, assistant], 'nothing');
    // u1 / u2 get compressed: the summary inherits the newest state.
    final carried = latestWorldBookState([u1.metadata, null, u2.metadata, null]);
    expect(carried!.turn, 2);
    final afterCompression = [summary(carried), user(), assistant];
    // Without the carried state the sticky effect would be lost (turn 1 again).
    final clock = resolveWorldBookClock(afterCompression);
    expect(clock.turn, 4);
    expect(clock.previous.effects, isNotEmpty);
    final (active, _) = step([summary(carried)], 'nothing');
    expect(active, isTrue, reason: 'turn 3 is inside the sticky window');
    expect(resolveWorldBookClock([summary(), user()]).previous.isEmpty, isTrue);
  });

  test('latestWorldBookState returns null when nothing carries state', () {
    expect(latestWorldBookState([null, {'x': 1}]), isNull);
  });
}
