import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/buddy/domain/buddy_engine.dart';
import 'package:aetherlink_flutter/features/buddy/domain/buddy_types.dart';
import 'package:aetherlink_flutter/features/buddy/domain/pixel_arts/pixel_arts.dart';

void main() {
  test('同一种子永远生成同一只宠物', () {
    final a = rollBuddy('seed-123');
    final b = rollBuddy('seed-123');
    expect(a.species, b.species);
    expect(a.rarity, b.rarity);
    expect(a.eye, b.eye);
    expect(a.hat, b.hat);
    expect(a.shiny, b.shiny);
    expect(a.stats, b.stats);
  });

  test('不同种子生成不同宠物（v2 大样本下物种覆盖全部）', () {
    final seen = <BuddySpecies>{};
    for (var i = 0; i < 2000; i++) {
      seen.add(rollBuddy('v2-seed-$i').species);
    }
    expect(seen, containsAll(BuddySpecies.values));
  });

  test('旧种子（无 v2 前缀）只从初代 18 种里抽，抽不到奶龙', () {
    final seen = <BuddySpecies>{};
    for (var i = 0; i < 2000; i++) {
      seen.add(rollBuddy('seed-$i').species);
    }
    expect(seen, isNot(contains(BuddySpecies.nailong)));
    expect(seen.length, 18);
  });

  test('稀有度分布大致符合 60/25/10/4/1 权重', () {
    final counts = <BuddyRarity, int>{};
    const n = 20000;
    for (var i = 0; i < n; i++) {
      final r = rollBuddy('rarity-$i').rarity;
      counts[r] = (counts[r] ?? 0) + 1;
    }
    expect(counts[BuddyRarity.common]! / n, closeTo(0.60, 0.03));
    expect(counts[BuddyRarity.uncommon]! / n, closeTo(0.25, 0.03));
    expect(counts[BuddyRarity.rare]! / n, closeTo(0.10, 0.02));
    expect(counts[BuddyRarity.epic]! / n, closeTo(0.04, 0.01));
    expect(counts[BuddyRarity.legendary]! / n, closeTo(0.01, 0.005));
  });

  test('common 稀有度没有帽子，属性都在 1-100', () {
    for (var i = 0; i < 500; i++) {
      final bones = rollBuddy('hat-$i');
      if (bones.rarity == BuddyRarity.common) {
        expect(bones.hat, BuddyHat.none);
      }
      for (final v in bones.stats.values) {
        expect(v, inInclusiveRange(1, 100));
      }
    }
  });

  test('每个物种都有 16×16 像素图，字符全部在调色板里且带眼睛', () {
    for (final species in BuddySpecies.values) {
      final art = kBuddyPixelArts[species];
      expect(art, isNotNull, reason: '$species 缺少像素图');
      expect(art!.rows, hasLength(16), reason: '$species 行数不是 16');
      var hasEye = false;
      for (final row in art.rows) {
        expect(row.length, 16, reason: '$species 行 "$row" 长度不是 16');
        for (final ch in row.split('')) {
          if (ch == '.') continue;
          if (ch == 'E') hasEye = true;
          expect(art.palette.containsKey(ch), isTrue,
              reason: '$species 字符 "$ch" 不在调色板里');
        }
      }
      expect(hasEye, isTrue, reason: '$species 没有眼睛像素');
    }
  });

  test('每种帽子（除 none）都有像素图，行宽一致且字符在调色板里', () {
    for (final hat in BuddyHat.values) {
      if (hat == BuddyHat.none) continue;
      final art = kBuddyHatArts[hat];
      expect(art, isNotNull, reason: '$hat 缺少像素图');
      final width = art!.rows.first.length;
      for (final row in art.rows) {
        expect(row.length, width, reason: '$hat 行宽不一致');
        for (final ch in row.split('')) {
          if (ch == '.') continue;
          expect(art.palette.containsKey(ch), isTrue,
              reason: '$hat 字符 "$ch" 不在调色板里');
        }
      }
    }
  });
}
