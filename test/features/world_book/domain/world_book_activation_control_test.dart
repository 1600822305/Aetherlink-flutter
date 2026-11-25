// 激活控制（world_book_timed_selection.dart），逐项对照 SillyTavern
// `checkWorldInfo` / `filterByInclusionGroups`：概率、包含组（权重 / 组内优先 /
// 评分 / 持续中胜出 / 已激活的组移除）、预算（含不计入预算）、递归（阻止 /
// 不可被递归激活 / 延迟到递归层级 / 最大扫描次数）、最少激活数。

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation_state.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_settings.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_timed_selection.dart';

/// 按顺序循环返回给定值的随机源。
class _Seq implements Random {
  _Seq(this.values);

  final List<double> values;
  var _i = 0;

  @override
  double nextDouble() => values[_i++ % values.length];

  @override
  int nextInt(int max) => (nextDouble() * max).floor().clamp(0, max - 1);

  @override
  bool nextBool() => nextDouble() < 0.5;
}

WorldBookEntry e(
  String id, {
  List<String> keys = const ['dragon'],
  String content = 'LORE',
  int order = 100,
  bool constant = false,
  int probability = 100,
  bool useProbability = true,
  String group = '',
  bool groupOverride = false,
  int groupWeight = 100,
  bool? useGroupScoring,
  bool excludeRecursion = false,
  bool preventRecursion = false,
  int delayUntilRecursion = 0,
  bool ignoreBudget = false,
  int? scanDepth,
  int? sticky,
}) => WorldBookEntry(
  id: id,
  keywords: keys,
  content: content,
  order: order,
  constant: constant,
  probability: probability,
  useProbability: useProbability,
  group: group,
  groupOverride: groupOverride,
  groupWeight: groupWeight,
  useGroupScoring: useGroupScoring,
  excludeRecursion: excludeRecursion,
  preventRecursion: preventRecursion,
  delayUntilRecursion: delayUntilRecursion,
  ignoreBudget: ignoreBudget,
  scanDepth: scanDepth,
  sticky: sticky,
);

WorldBookTimedResult run(
  List<WorldBookEntry> entries, {
  List<String> texts = const ['a dragon appears'],
  WorldBookSettings settings = WorldBookSettings.defaults,
  Random? random,
  int turn = 1,
  WorldBookActivationState previous = WorldBookActivationState.empty,
  int? contextTokens,
  int Function(String)? countTokens,
}) => selectTimedWorldBookEntries(
  books: [WorldBook(id: 'b', entries: entries)],
  scanTexts: texts,
  turn: turn,
  previous: previous,
  settings: settings,
  random: random ?? _Seq([0.0]),
  contextTokens: contextTokens,
  countTokens: countTokens,
);

List<String> ids(WorldBookTimedResult r) => [for (final x in r.entries) x.id];

/// 让 [entry] 在第 2 轮处于持续中的上一轮状态。
WorldBookActivationState stickyState(WorldBookEntry entry) =>
    WorldBookActivationState(
      turn: 1,
      effects: {
        jsonEncode(['b', entry.id]): WorldBookEffect(
          activatedAt: 1,
          signature: worldBookTimerSignature(entry),
        ),
      },
    );

void main() {
  group('概率', () {
    test('掷出的值 ≤ 概率时激活', () {
      final p60 = e('0', probability: 60);
      expect(ids(run([p60], random: _Seq([0.5]))), ['0']);
      expect(ids(run([p60], random: _Seq([0.7]))), isEmpty);
      expect(ids(run([e('0', probability: 0)], random: _Seq([0.01]))), isEmpty);
      expect(ids(run([e('0')], random: _Seq([0.999]))), ['0']);
    });

    test('关闭概率时总是激活', () {
      final off = e('0', probability: 0, useProbability: false);
      expect(ids(run([off], random: _Seq([0.99]))), ['0']);
    });

    test('持续中的条目不重新判定概率', () {
      final s = e('0', probability: 0, sticky: 2);
      final r = run(
        [s],
        texts: ['nothing'],
        turn: 2,
        previous: stickyState(s),
        random: _Seq([0.99]),
      );
      expect(ids(r), ['0']);
    });

    test('常驻条目同样要过概率', () {
      final c = e('0', constant: true, probability: 50);
      expect(ids(run([c], random: _Seq([0.9]))), isEmpty);
    });
  });

  group('包含组', () {
    test('按权重随机选一个（在 order 降序排列上累加权重）', () {
      final a = e('a', order: 200, group: 'g', groupWeight: 30);
      final b = e('b', order: 100, group: 'g', groupWeight: 70);
      expect(ids(run([a, b], random: _Seq([0.2]))), ['a']);
      expect(ids(run([a, b], random: _Seq([0.5]))), ['b']);
    });

    test('组内优先：取 order 最大的，不随机', () {
      final c = e('c', order: 100, group: 'g', groupOverride: true);
      final d = e('d', order: 300, group: 'g', groupOverride: true);
      final x = e('x', order: 500, group: 'g');
      expect(ids(run([c, d, x], random: _Seq([0.0]))), ['d']);
    });

    test('只有一条的组不受影响；不同组互不影响', () {
      final a = e('a', group: 'g1');
      final b = e('b', group: 'g2');
      expect(ids(run([a, b])).toSet(), {'a', 'b'});
    });

    test('一个条目可以属于多个组', () {
      final ab = e('ab', order: 300, group: 'a, b', groupOverride: true);
      final a = e('a', order: 200, group: 'a');
      final b = e('b', order: 100, group: 'b');
      expect(ids(run([ab, a, b])), ['ab']);
    });

    test('评分：只保留关键词命中数最高的', () {
      final two = e('two', keys: ['dragon', 'fire'], group: 'g');
      final one = e('one', keys: ['dragon'], group: 'g');
      const scoring = WorldBookSettings(useGroupScoring: true);
      final r = run(
        [two, one],
        texts: ['dragon breathes fire'],
        settings: scoring,
        random: _Seq([0.99]),
      );
      expect(ids(r), ['two']);
      // 条目级开启也生效。
      final r2 = run(
        [two.copyWith(useGroupScoring: true), one.copyWith(useGroupScoring: true)],
        texts: ['dragon breathes fire'],
        random: _Seq([0.99]),
      );
      expect(ids(r2), ['two']);
    });

    test('组里有持续中的条目时它胜出', () {
      final s = e('s', order: 100, group: 'g', sticky: 2);
      final o = e('o', order: 900, group: 'g', groupOverride: true);
      final r = run(
        [s, o],
        turn: 2,
        previous: stickyState(s),
      );
      expect(ids(r), ['s']);
    });

    test('之前的扫描已激活过这个组：递归里同组的条目整组移除', () {
      final a = e('a', constant: true, content: 'castle', group: 'g');
      final r = e('r', keys: ['castle'], group: 'g');
      const recursive = WorldBookSettings(recursive: true);
      expect(ids(run([a, r], texts: ['x'], settings: recursive)), ['a']);
      final free = r.copyWith(group: '');
      expect(
        ids(run([a, free], texts: ['x'], settings: recursive)).toSet(),
        {'a', 'r'},
      );
    });
  });

  group('预算', () {
    int len(String s) => s.length;

    test('累计 token 达到预算时停止，不计入预算的照常加入', () {
      final a = e('a', order: 300, content: 'aaaa');
      final b = e('b', order: 200, content: 'bbbb');
      final c = e('c', order: 100, content: 'cc', ignoreBudget: true);
      final r = run(
        [a, b, c],
        settings: const WorldBookSettings(budgetCap: 10),
        countTokens: len,
      );
      expect(ids(r), ['c', 'a']);
      expect(r.budgetOverflowed, isTrue);
    });

    test('按上下文百分比计算，并受上限约束', () {
      final a = e('a', order: 300, content: 'aaaa');
      final b = e('b', order: 200, content: 'bbbb');
      // 40 × 25% = 10。
      final r = run([a, b], contextTokens: 40, countTokens: len);
      expect(ids(r), ['a']);
      // 上限更小时取上限：100 × 25% = 25，上限 6。
      final capped = run(
        [a, b],
        contextTokens: 100,
        settings: const WorldBookSettings(budgetCap: 6),
        countTokens: len,
      );
      expect(ids(capped), ['a']);
      final roomy = run([a, b], contextTokens: 100, countTokens: len);
      expect(ids(roomy), ['b', 'a']);
      expect(roomy.budgetOverflowed, isFalse);
    });

    test('不知道上下文长度且没有上限时不限', () {
      final many = [for (var i = 0; i < 20; i++) e('$i', content: 'x' * 50)];
      expect(run(many, countTokens: len).entries, hasLength(20));
    });
  });

  group('递归', () {
    final a = e('a', constant: true, content: 'mentions dragon', order: 300);
    final b = e('b', keys: ['dragon'], content: 'mentions castle', order: 200);
    final c = e('c', keys: ['castle'], content: 'END', order: 100);
    const on = WorldBookSettings(recursive: true);
    List<String> chain(List<WorldBookEntry> es, [WorldBookSettings s = on]) =>
        ids(run(es, texts: ['nothing here'], settings: s)).toList()..sort();

    test('关闭递归时只看聊天记录；开启后逐层激活', () {
      expect(chain([a, b, c], WorldBookSettings.defaults), ['a']);
      expect(chain([a, b, c]), ['a', 'b', 'c']);
    });

    test('阻止后续递归：它的内容不再用来触发其他条目', () {
      expect(chain([a.copyWith(preventRecursion: true), b, c]), ['a']);
      expect(chain([a, b.copyWith(preventRecursion: true), c]), ['a', 'b']);
    });

    test('不可被递归激活：只能被聊天记录触发', () {
      expect(chain([a, b.copyWith(excludeRecursion: true), c]), ['a']);
      expect(
        ids(run([b.copyWith(excludeRecursion: true)], settings: on)),
        ['b'],
      );
    });

    test('最大扫描次数（含首次扫描）', () {
      expect(chain([a, b, c], const WorldBookSettings(recursive: true, maxRecursionSteps: 2)), ['a', 'b']);
      expect(chain([a, b, c], const WorldBookSettings(recursive: true, maxRecursionSteps: 1)), ['a']);
    });

    test('延迟到递归层级：只在递归扫描、且层级到了时激活', () {
      final d1 = e('d1', keys: ['dragon'], delayUntilRecursion: 1);
      final d2 = e('d2', keys: ['dragon'], delayUntilRecursion: 2);
      // 聊天记录里就有 dragon，但首次扫描不参与。
      expect(ids(run([d1], settings: on)), isEmpty);
      expect(chain([a, d1, d2]), ['a', 'd1', 'd2']);
      // 关闭递归时永远不激活。
      expect(chain([a, d1], WorldBookSettings.defaults), ['a']);
    });

    test('常驻条目的内容同样进入递归扫描', () {
      final m = e('m', constant: true, content: 'X{{newline}}dragon');
      expect(chain([m, b]), ['b', 'm']);
    });
  });

  group('最少激活数', () {
    final d = e('d');

    test('不够数时全局扫描深度逐次 +1', () {
      const s = WorldBookSettings(scanDepth: 1, minActivations: 1);
      expect(ids(run([d], texts: ['dragon', 'x', 'y'], settings: s)), ['d']);
      expect(
        ids(run([d], texts: ['dragon', 'x', 'y'], settings: WorldBookSettings(scanDepth: 1))),
        isEmpty,
      );
    });

    test('超过深度上限或聊天长度就停', () {
      const capped = WorldBookSettings(
        scanDepth: 1,
        minActivations: 1,
        minActivationsDepthMax: 1,
      );
      expect(ids(run([d], texts: ['dragon', 'x', 'y'], settings: capped)), isEmpty);
      const s = WorldBookSettings(scanDepth: 1, minActivations: 5);
      expect(ids(run([d], texts: ['dragon', 'x', 'y'], settings: s)), ['d']);
    });

    test('条目自己设了扫描深度的不随之扩大', () {
      const s = WorldBookSettings(scanDepth: 1, minActivations: 1);
      expect(
        ids(run([d.copyWith(scanDepth: 1)], texts: ['dragon', 'x'], settings: s)),
        isEmpty,
      );
    });
  });

  group('装饰器', () {
    test('解析：开头连续的 @@ 行，遇到普通文本为止', () {
      final p = parseWorldBookDecorators('@@activate\n@@foo\n正文\n@@activate 不算');
      expect(p.decorators, ['@@activate']);
      expect(p.content, '正文\n@@activate 不算');
      expect(parseWorldBookDecorators('正文').decorators, isEmpty);
      expect(parseWorldBookDecorators(' @@activate').decorators, isEmpty);
    });

    test('@@@ 后备写法只在上一行是未知装饰器时生效', () {
      expect(
        parseWorldBookDecorators('@@unknown\n@@@activate\n正文').decorators,
        ['@@activate'],
      );
      expect(
        parseWorldBookDecorators('@@@activate\n正文').decorators,
        isEmpty,
      );
    });

    test('全是装饰器行时内容保持原样（同 ST）', () {
      final p = parseWorldBookDecorators('@@activate');
      expect(p.decorators, ['@@activate']);
      expect(p.content, '@@activate');
    });

    test('@@activate 不看关键词直接激活，注入的内容去掉装饰器行', () {
      final r = run([e('0', keys: ['nope'], content: '@@activate\nLORE')]);
      expect(ids(r), ['0']);
      expect(r.entries.single.content, 'LORE');
    });

    test('@@dont_activate 连常驻和持续中的也不激活', () {
      expect(ids(run([e('0', constant: true, content: '@@dont_activate\nX')])), isEmpty);
      expect(ids(run([e('0', content: '@@dont_activate\nX')])), isEmpty);
      final s = e('s', content: '@@dont_activate\nX', sticky: 2);
      expect(ids(run([s], turn: 2, previous: stickyState(s))), isEmpty);
    });

    test('@@activate 优先于 @@dont_activate', () {
      expect(
        ids(run([e('0', keys: ['nope'], content: '@@dont_activate\n@@activate\nX')])),
        ['0'],
      );
    });

    test('递归文本用去掉装饰器后的内容', () {
      final a = e('a', constant: true, content: '@@activate\ncastle');
      final c = e('c', keys: ['activate'], content: 'C');
      final r = run(
        [a, c],
        texts: ['nothing'],
        settings: const WorldBookSettings(recursive: true),
      );
      expect(ids(r), ['a']);
    });
  });
}
