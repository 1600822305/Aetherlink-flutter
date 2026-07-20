import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/buddy/domain/buddy_engine.dart';
import 'package:aetherlink_flutter/features/buddy/domain/buddy_sprites.dart';
import 'package:aetherlink_flutter/features/buddy/domain/buddy_types.dart';

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

  test('不同种子生成不同宠物（大样本下物种覆盖全部 18 种）', () {
    final seen = <BuddySpecies>{};
    for (var i = 0; i < 2000; i++) {
      seen.add(rollBuddy('seed-$i').species);
    }
    expect(seen, containsAll(BuddySpecies.values));
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

  test('精灵图每帧 5 行，每行 12 个字符（眼睛替换后）', () {
    for (final species in BuddySpecies.values) {
      for (var frame = 0; frame < buddyFrameCount(species); frame++) {
        final bones = BuddyBones(
          rarity: BuddyRarity.common,
          species: species,
          eye: '·',
          hat: BuddyHat.none,
          shiny: false,
          stats: const {},
        );
        final lines = renderBuddySprite(bones, frame: frame);
        expect(lines, hasLength(5));
        for (final line in lines) {
          expect(line.length, 12,
              reason: '$species frame $frame line "$line"');
        }
      }
    }
  });
}
