// 电子宠物本地台词库与孵化用名字/性格池：核心系统纯本地零联网，
// 气泡台词从这里随机抽取（后续可加「调用当前模型」模式）。

import 'dart:math';

import 'buddy_types.dart';

/// 孵化时的候选名字池。
const List<String> kBuddyNames = [
  '团子', '布丁', '毛球', '咕咕', '嘟嘟', '泡泡', '芝麻', '年糕', //
  '汤圆', '豆包', '麻薯', '雪球', '啵啵', '果冻', '乌冬', '曲奇', //
  '肉桂', '抹茶', '奶盖', 'möchi', 'Bug', 'Pixel', 'Null', 'Kilo', //
];

/// 孵化时的候选性格池。
const List<String> kBuddyPersonalities = [
  '好奇心旺盛，见到新代码就想戳一戳',
  '慢性子，但审查代码时出奇地严格',
  '有点毒舌，看到 TODO 会小声叹气',
  '乐观派，坚信没有修不好的 Bug',
  '夜行性，凌晨的提交它最有精神',
  '完美主义，看到未对齐的缩进会难受',
  '悠闲自在，主打一个陪伴',
  '话痨，逮住机会就要发表看法',
  '腼腆，被夸的时候会假装看别处',
  '混乱中立，偶尔会怂恿你直接 force push',
];

/// 空闲时的碎碎念。
const List<String> kBuddyIdleChatter = [
  '今天写了几个 Bug 呀？',
  '记得喝水哦。',
  '这段代码……我看看……嗯，看不懂。',
  'zzZ……啊，我没睡！',
  '要不要先跑一下测试？',
  '我觉得这个变量名可以再想想。',
  '陪你 debug 到天亮！',
  '刚才有一只虫子飞过去了，是 Bug 吗？',
  '提交之前记得 diff 一眼～',
  '你敲键盘的声音很好听。',
  '循环里可别再套循环啦。',
  '休息一下吧，代码又跑不掉。',
];

/// 被抚摸时的反应。
const List<String> kBuddyPetReactions = [
  '呼噜呼噜……',
  '再摸一下嘛！',
  '好舒服～',
  '嘿嘿。',
  '这就是幸福吗！',
  '摸完记得回去写代码哦。',
];

/// 孵化瞬间的第一句话。
const List<String> kBuddyHatchGreetings = [
  '你好呀！以后请多关照！',
  '破壳而出！我是你的搭档啦。',
  '哇，外面的世界！还有……好多代码？',
];

String pickBuddyPhrase(Random random, List<String> pool) =>
    pool[random.nextInt(pool.length)];

/// 稀有度对应的孵化结语，给卡片一点仪式感。
String rarityFlavor(BuddyRarity rarity) {
  switch (rarity) {
    case BuddyRarity.common:
      return '平平无奇，但独一无二。';
    case BuddyRarity.uncommon:
      return '有点特别的小家伙。';
    case BuddyRarity.rare:
      return '运气不错，是只稀有的伙伴！';
    case BuddyRarity.epic:
      return '史诗级伙伴降临！';
    case BuddyRarity.legendary:
      return '传说中的存在……它选择了你。';
  }
}
