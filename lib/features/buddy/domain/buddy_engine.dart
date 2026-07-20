// 电子宠物确定性生成引擎：FNV-1a 哈希 + Mulberry32 PRNG。
// 移植自 Claude Code `src/buddy/companion.ts`：同一种子永远得到同一只
// 宠物（物种/稀有度/闪光/属性），骨架每次从种子重算、不持久化。

import 'buddy_types.dart';

/// 固定盐值，与原版一致。
const String kBuddySalt = 'friend-2026-401';

const int _mask32 = 0xffffffff;

/// FNV-1a 32 位字符串哈希。
int fnv1aHash(String s) {
  var h = 2166136261;
  for (var i = 0; i < s.length; i++) {
    h ^= s.codeUnitAt(i);
    h = (h * 16777619) & _mask32;
  }
  return h;
}

/// Mulberry32 —— 小巧的确定性 PRNG，返回 [0,1) 的 double 序列。
class Mulberry32 {
  Mulberry32(int seed) : _a = seed & _mask32;

  int _a;

  double next() {
    _a = (_a + 0x6d2b79f5) & _mask32;
    var t = _a;
    t = (_imul(t ^ (t >> 15), t | 1)) & _mask32;
    t = (t + _imul(t ^ (t >> 7), t | 61)) & _mask32 ^ t;
    return ((t ^ (t >> 14)) & _mask32) / 4294967296;
  }

  /// 32 位有符号乘法（JS `Math.imul` 语义，截断到 32 位）。
  static int _imul(int a, int b) {
    final al = a & 0xffff;
    final ah = (a >> 16) & 0xffff;
    return ((al * b) + (((ah * b) & 0xffff) << 16)) & _mask32;
  }

  T pick<T>(List<T> list) => list[(next() * list.length).floor()];
}

BuddyRarity _rollRarity(Mulberry32 rng) {
  final total =
      BuddyRarity.values.fold<int>(0, (sum, r) => sum + r.weight);
  var roll = rng.next() * total;
  for (final rarity in BuddyRarity.values) {
    roll -= rarity.weight;
    if (roll < 0) return rarity;
  }
  return BuddyRarity.common;
}

/// 一个峰值属性 + 一个最低属性，其余散布；稀有度抬高下限。
Map<BuddyStat, int> _rollStats(Mulberry32 rng, BuddyRarity rarity) {
  final floor = rarity.statFloor;
  final peak = rng.pick(BuddyStat.values);
  var dump = rng.pick(BuddyStat.values);
  while (dump == peak) {
    dump = rng.pick(BuddyStat.values);
  }
  final stats = <BuddyStat, int>{};
  for (final stat in BuddyStat.values) {
    if (stat == peak) {
      stats[stat] = (floor + 50 + (rng.next() * 30).floor()).clamp(1, 100);
    } else if (stat == dump) {
      stats[stat] = (floor - 10 + (rng.next() * 15).floor()).clamp(1, 100);
    } else {
      stats[stat] = floor + (rng.next() * 40).floor();
    }
  }
  return stats;
}

/// 从种子确定性生成骨架。抽取顺序固定：稀有度 → 物种 → 眼睛 → 帽子 →
/// 闪光(1%) → 属性，改变顺序会改变所有人的宠物。
BuddyBones rollBuddy(String seed) {
  final rng = Mulberry32(fnv1aHash(seed + kBuddySalt));
  final rarity = _rollRarity(rng);
  final species = rng.pick(BuddySpecies.values);
  final eye = rng.pick(kBuddyEyes);
  final hat = rarity == BuddyRarity.common
      ? BuddyHat.none
      : rng.pick(BuddyHat.values);
  final shiny = rng.next() < 0.01;
  final stats = _rollStats(rng, rarity);
  return BuddyBones(
    rarity: rarity,
    species: species,
    eye: eye,
    hat: hat,
    shiny: shiny,
    stats: stats,
  );
}
