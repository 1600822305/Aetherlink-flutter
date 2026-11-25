// 宏替换（world_book_macros.dart），对照 SillyTavern `substituteParams` 的常用宏。

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book_macros.dart';

final _now = DateTime(2026, 11, 26, 3, 7);

WorldBookMacroContext ctx({String pickSeed = 'topic-1', int seed = 42}) =>
    WorldBookMacroContext(
      user: '小明',
      char: '莉娜',
      model: 'gpt-x',
      now: _now,
      random: Random(seed),
      pickSeed: pickSeed,
    );

String sub(String text, [WorldBookMacroContext? c]) =>
    substituteWorldBookMacros(text, c ?? ctx());

void main() {
  test('名字宏大小写不敏感；charIfNotGroup / group 取 char', () {
    expect(sub('{{user}} 对 {{CHAR}} 说'), '小明 对 莉娜 说');
    expect(sub('{{charIfNotGroup}}/{{group}}'), '莉娜/莉娜');
    expect(sub('<USER> 和 <bot> 和 <Char>'), '小明 和 莉娜 和 莉娜');
  });

  test('{{model}} 未知时原样保留', () {
    expect(sub('{{model}}'), 'gpt-x');
    expect(
      substituteWorldBookMacros('{{model}}', const WorldBookMacroContext()),
      '{{model}}',
    );
  });

  test('时间宏', () {
    expect(sub('{{time}}|{{isotime}}'), '03:07|03:07');
    expect(sub('{{date}}'), '2026年11月26日');
    expect(sub('{{isodate}}'), '2026-11-26');
    expect(sub('{{weekday}}'), '星期四');
  });

  test('注释、空操作、换行与 trim', () {
    expect(sub('a{{// 作者备注}}b{{noop}}c'), 'abc');
    expect(sub('a{{newline}}b'), 'a\nb');
    expect(sub('上一段\n\n{{trim}}\n下一段'), '上一段下一段');
  });

  test('random 两种写法都只从选项里取', () {
    for (var seed = 0; seed < 20; seed++) {
      expect(['a', 'b', 'c'], contains(sub('{{random::a::b::c}}', ctx(seed: seed))));
      expect(['x', 'y'], contains(sub('{{random:x,y}}', ctx(seed: seed))));
    }
    expect(sub(r'{{random:a\,b}}'), 'a,b');
  });

  test('pick 在同一种子、同一位置结果稳定', () {
    final first = sub('{{pick::a::b::c::d::e}}');
    for (var seed = 0; seed < 10; seed++) {
      expect(sub('{{pick::a::b::c::d::e}}', ctx(seed: seed)), first);
    }
    final picks = {
      for (var i = 0; i < 30; i++)
        sub('{{pick::a::b::c::d::e}}', ctx(pickSeed: 'topic-$i')),
    };
    expect(picks.length, greaterThan(1));
  });

  test('roll 的几种写法与范围', () {
    for (var seed = 0; seed < 30; seed++) {
      final d6 = int.parse(sub('{{roll:1d6}}', ctx(seed: seed)));
      expect(d6, inInclusiveRange(1, 6));
      final d20 = int.parse(sub('{{roll:20}}', ctx(seed: seed)));
      expect(d20, inInclusiveRange(1, 20));
      final mod = int.parse(sub('{{roll 2d6+3}}', ctx(seed: seed)));
      expect(mod, inInclusiveRange(5, 15));
    }
    expect(sub('{{roll:abc}}'), '{{roll:abc}}');
  });

  test('reverse', () {
    expect(sub('{{reverse:abc龙}}'), '龙cba');
  });

  test('未知宏与普通文本保持不变', () {
    expect(sub('{{unknown}} {single} <tag> 普通'), '{{unknown}} {single} <tag> 普通');
    expect(sub(''), '');
  });

  test('worldBookScanLine', () {
    expect(worldBookScanLine('hi', name: '小明'), '小明: hi');
    expect(worldBookScanLine('hi', name: '小明', includeNames: false), 'hi');
    expect(worldBookScanLine('hi', name: ' '), 'hi');
    expect(worldBookScanLine('hi'), 'hi');
  });
}
