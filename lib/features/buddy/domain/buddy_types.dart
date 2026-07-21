// 电子宠物（Buddy）领域类型：物种 / 稀有度 / 眼睛 / 帽子 / 属性 常量与
// 数据类。移植自 Claude Code 源码 `src/buddy/types.ts` 的设定。
//
// 「骨架」(bones) 由种子确定性生成、永不持久化；「灵魂」(soul) 是孵化时
// 生成的名字/性格/种子，持久化为单键 JSON。改配置也伪造不了稀有度。

import 'dart:convert';

/// 稀有度：权重抽取 60/25/10/4/1，稀有度越高属性下限越高。
enum BuddyRarity {
  common('普通', '★', 60, 5),
  uncommon('非凡', '★★', 25, 15),
  rare('稀有', '★★★', 10, 25),
  epic('史诗', '★★★★', 4, 35),
  legendary('传说', '★★★★★', 1, 50);

  const BuddyRarity(this.label, this.stars, this.weight, this.statFloor);

  final String label;
  final String stars;
  final int weight;
  final int statFloor;
}

/// 物种：前 18 种与原版一致，之后为新增物种（只能追加在末尾，
/// 否则会改变老种子的抽取结果）。
enum BuddySpecies {
  duck('鸭子'),
  goose('鹅'),
  blob('果冻'),
  cat('猫'),
  dragon('龙'),
  octopus('章鱼'),
  owl('猫头鹰'),
  penguin('企鹅'),
  turtle('乌龟'),
  snail('蜗牛'),
  ghost('幽灵'),
  axolotl('六角恐龙'),
  capybara('水豚'),
  cactus('仙人掌'),
  robot('机器人'),
  rabbit('兔子'),
  mushroom('蘑菇'),
  chonk('胖猫'),
  nailong('奶龙'),
  blueGuga('蓝咕咕'),
  shyNailong('腼腆奶龙');

  const BuddySpecies(this.label);

  final String label;
}

/// 6 种眼睛字符。
const List<String> kBuddyEyes = ['·', '✦', '×', '◉', '@', '°'];

/// 8 种帽子（common 稀有度固定无帽）。
enum BuddyHat {
  none('无'),
  crown('皇冠'),
  tophat('礼帽'),
  propeller('螺旋桨帽'),
  halo('光环'),
  wizard('巫师帽'),
  beanie('毛线帽'),
  tinyduck('小鸭子');

  const BuddyHat(this.label);

  final String label;
}

/// 五维属性。
enum BuddyStat {
  debugging('调试'),
  patience('耐心'),
  chaos('混乱'),
  wisdom('智慧'),
  snark('毒舌');

  const BuddyStat(this.label);

  final String label;
}

/// 确定性「骨架」：由种子哈希重新计算，永不持久化。
class BuddyBones {
  const BuddyBones({
    required this.rarity,
    required this.species,
    required this.eye,
    required this.hat,
    required this.shiny,
    required this.stats,
  });

  final BuddyRarity rarity;
  final BuddySpecies species;
  final String eye;
  final BuddyHat hat;
  final bool shiny;
  final Map<BuddyStat, int> stats;
}

/// 持久化的「灵魂」：名字 / 性格 / 孵化时间 / 生成种子。
class BuddySoul {
  const BuddySoul({
    required this.name,
    required this.personality,
    required this.hatchedAt,
    required this.seed,
  });

  final String name;
  final String personality;

  /// 孵化时间（millisecondsSinceEpoch）。
  final int hatchedAt;

  /// 确定性生成骨架用的种子字符串（孵化时生成一次，之后不变）。
  final String seed;
}

/// 编码：灵魂 → JSON 字符串（单键存储）。
String encodeBuddySoul(BuddySoul soul) => jsonEncode({
      'name': soul.name,
      'personality': soul.personality,
      'hatchedAt': soul.hatchedAt,
      'seed': soul.seed,
    });

/// 解码：缺字段/坏数据返回 null（视为未孵化）。
BuddySoul? decodeBuddySoul(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return null;
    final name = json['name'];
    final personality = json['personality'];
    final hatchedAt = json['hatchedAt'];
    final seed = json['seed'];
    if (name is! String || name.isEmpty) return null;
    if (personality is! String) return null;
    if (hatchedAt is! int) return null;
    if (seed is! String || seed.isEmpty) return null;
    return BuddySoul(
      name: name,
      personality: personality,
      hatchedAt: hatchedAt,
      seed: seed,
    );
  } catch (_) {
    return null;
  }
}
