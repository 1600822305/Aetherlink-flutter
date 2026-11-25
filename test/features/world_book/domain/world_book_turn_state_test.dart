// 计时时钟（world_book_turn_state.dart）：消息序号按当前路径上的用户与助手消息
// 计（ST `chat.length`），分支互不影响，重新生成幂等，压缩摘要带着状态走。

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation_state.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_timed_selection.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_turn_state.dart';

WorldBookPathNode user([WorldBookActivationState? state]) => (
  isUserTurn: true,
  isAssistantTurn: false,
  isSummary: false,
  metadata: state?.writeTo(null),
);

const WorldBookPathNode assistant = (
  isUserTurn: false,
  isAssistantTurn: true,
  isSummary: false,
  metadata: null,
);

/// 不计数的节点（如 system 提示消息）。
const WorldBookPathNode other = (
  isUserTurn: false,
  isAssistantTurn: false,
  isSummary: false,
  metadata: null,
);

WorldBookPathNode summary([WorldBookActivationState? state]) => (
  isUserTurn: false,
  isAssistantTurn: true,
  isSummary: true,
  metadata: state?.writeTo({'isSummary': true}) ?? {'isSummary': true},
);

/// sticky 5：第 1 条激活后，第 3、5 条持续，第 7 条到期。
const _sticky = WorldBookEntry(
  id: 'e',
  content: 'LORE',
  keywords: ['dragon'],
  scanDepth: 1,
  sticky: 5,
);
final _books = [WorldBook(id: 'b', entries: [_sticky])];

/// Evaluates one user message on top of [ancestors]; returns (active, newNode).
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
  test('消息序号 = 用户与助手消息数 + 1，从最近的状态继续', () {
    expect(resolveWorldBookClock(const []).turn, 1);
    expect(resolveWorldBookClock([user(), assistant, user(), assistant]).turn, 5);
    expect(resolveWorldBookClock([user(), other, assistant]).turn, 3);
    final clock = resolveWorldBookClock([
      user(const WorldBookActivationState(turn: 7)),
      assistant,
      user(),
      assistant,
    ]);
    expect(clock.previous.turn, 7);
    expect(clock.turn, 11);
  });

  test('分支之间不串计时状态', () {
    final (hit, u1) = step(const [], 'a dragon');
    expect(hit, isTrue);
    final trunk = [u1, assistant];

    final (a2, ua2) = step(trunk, 'nothing');
    final (a3, ua3) = step([...trunk, ua2, assistant], 'nothing');
    final (a4, _) = step([...trunk, ua2, assistant, ua3, assistant], 'nothing');
    expect([a2, a3, a4], [true, true, false]);

    // 分支 B 从主干分出：只看得到主干的状态。
    final clockB = resolveWorldBookClock(trunk);
    expect(clockB.turn, 3);
    expect(clockB.previous.turn, 1);
    final (b2, _) = step(trunk, 'nothing');
    expect(b2, isTrue);
  });

  test('重新生成读同样的祖先，结果相同', () {
    final (_, u1) = step(const [], 'a dragon');
    final first = step([u1, assistant], 'nothing');
    final again = step([u1, assistant], 'nothing');
    expect(first.$1, again.$1);
    expect(first.$2.metadata, again.$2.metadata);
  });

  test('压缩后计时状态由摘要节点带着走，摘要本身不计数', () {
    final (_, u1) = step(const [], 'a dragon');
    final (_, u2) = step([u1, assistant], 'nothing');
    final carried = latestWorldBookState([u1.metadata, null, u2.metadata, null]);
    expect(carried!.turn, 3);
    final clock = resolveWorldBookClock([summary(carried), user(), assistant]);
    expect(clock.turn, 6);
    expect(clock.previous.effects, isNotEmpty);
    final (active, _) = step([summary(carried)], 'nothing');
    expect(active, isTrue, reason: '第 4 条仍在持续里（4 < 1 + 5）');
    expect(resolveWorldBookClock([summary(), user()]).previous.isEmpty, isTrue);
  });

  test('没有任何状态时 latestWorldBookState 返回 null', () {
    expect(latestWorldBookState([null, {'x': 1}]), isNull);
  });
}
