// 电子宠物 ASCII 精灵图：18 种物种 × 3 帧动画，移植自 Claude Code
// `src/buddy/sprites.ts`。每帧 5 行 × 12 列（{E} 替换成 1 个眼睛字符后）。
// 第 0 行是帽子槽——帧 0-1 必须留空，帧 2 可用来画烟/气泡等特效。

import 'buddy_types.dart';

const Map<BuddySpecies, List<List<String>>> _bodies = {
  BuddySpecies.duck: [
    [
      '            ',
      '    __      ',
      '  <({E} )___  ',
      '   (  ._>   ',
      '    `--´    ',
    ],
    [
      '            ',
      '    __      ',
      '  <({E} )___  ',
      '   (  ._>   ',
      '    `--´~   ',
    ],
    [
      '            ',
      '    __      ',
      '  <({E} )___  ',
      '   (  .__>  ',
      '    `--´    ',
    ],
  ],
  BuddySpecies.goose: [
    [
      '            ',
      '     ({E}>    ',
      '     ||     ',
      '   _(__)_   ',
      '    ^^^^    ',
    ],
    [
      '            ',
      '    ({E}>     ',
      '     ||     ',
      '   _(__)_   ',
      '    ^^^^    ',
    ],
    [
      '            ',
      '     ({E}>>   ',
      '     ||     ',
      '   _(__)_   ',
      '    ^^^^    ',
    ],
  ],
  BuddySpecies.blob: [
    [
      '            ',
      '   .----.   ',
      '  ( {E}  {E} )  ',
      '  (      )  ',
      '   `----´   ',
    ],
    [
      '            ',
      '  .------.  ',
      ' (  {E}  {E}  ) ',
      ' (        ) ',
      '  `------´  ',
    ],
    [
      '            ',
      '    .--.    ',
      '   ({E}  {E})   ',
      '   (    )   ',
      '    `--´    ',
    ],
  ],
  BuddySpecies.cat: [
    [
      '            ',
      r'   /\_/\    ',
      '  ( {E}   {E})  ',
      '  (  ω  )   ',
      '  (")_(")   ',
    ],
    [
      '            ',
      r'   /\_/\    ',
      '  ( {E}   {E})  ',
      '  (  ω  )   ',
      '  (")_(")~  ',
    ],
    [
      '            ',
      r'   /\-/\    ',
      '  ( {E}   {E})  ',
      '  (  ω  )   ',
      '  (")_(")   ',
    ],
  ],
  BuddySpecies.dragon: [
    [
      '            ',
      r'  /^\  /^\  ',
      ' <  {E}  {E}  > ',
      ' (   ~~   ) ',
      '  `-vvvv-´  ',
    ],
    [
      '            ',
      r'  /^\  /^\  ',
      ' <  {E}  {E}  > ',
      ' (        ) ',
      '  `-vvvv-´  ',
    ],
    [
      '   ~    ~   ',
      r'  /^\  /^\  ',
      ' <  {E}  {E}  > ',
      ' (   ~~   ) ',
      '  `-vvvv-´  ',
    ],
  ],
  BuddySpecies.octopus: [
    [
      '            ',
      '   .----.   ',
      '  ( {E}  {E} )  ',
      '  (______)  ',
      r'  /\/\/\/\  ',
    ],
    [
      '            ',
      '   .----.   ',
      '  ( {E}  {E} )  ',
      '  (______)  ',
      r'  \/\/\/\/  ',
    ],
    [
      '     o      ',
      '   .----.   ',
      '  ( {E}  {E} )  ',
      '  (______)  ',
      r'  /\/\/\/\  ',
    ],
  ],
  BuddySpecies.owl: [
    [
      '            ',
      r'   /\  /\   ',
      '  (({E})({E}))  ',
      '  (  ><  )  ',
      '   `----´   ',
    ],
    [
      '            ',
      r'   /\  /\   ',
      '  (({E})({E}))  ',
      '  (  ><  )  ',
      '   .----.   ',
    ],
    [
      '            ',
      r'   /\  /\   ',
      '  (({E})(-))  ',
      '  (  ><  )  ',
      '   `----´   ',
    ],
  ],
  BuddySpecies.penguin: [
    [
      '            ',
      '  .---.     ',
      '  ({E}>{E})     ',
      r' /(   )\    ',
      '  `---´     ',
    ],
    [
      '            ',
      '  .---.     ',
      '  ({E}>{E})     ',
      ' |(   )|    ',
      '  `---´     ',
    ],
    [
      '  .---.     ',
      '  ({E}>{E})     ',
      r' /(   )\    ',
      '  `---´     ',
      '   ~ ~      ',
    ],
  ],
  BuddySpecies.turtle: [
    [
      '            ',
      '   _,--._   ',
      '  ( {E}  {E} )  ',
      r' /[______]\ ',
      '  ``    ``  ',
    ],
    [
      '            ',
      '   _,--._   ',
      '  ( {E}  {E} )  ',
      r' /[______]\ ',
      '   ``  ``   ',
    ],
    [
      '            ',
      '   _,--._   ',
      '  ( {E}  {E} )  ',
      r' /[======]\ ',
      '  ``    ``  ',
    ],
  ],
  BuddySpecies.snail: [
    [
      '            ',
      ' {E}    .--.  ',
      r'  \  ( @ )  ',
      r'   \_`--´   ',
      '  ~~~~~~~   ',
    ],
    [
      '            ',
      '  {E}   .--.  ',
      '  |  ( @ )  ',
      r'   \_`--´   ',
      '  ~~~~~~~   ',
    ],
    [
      '            ',
      ' {E}    .--.  ',
      r'  \  ( @  ) ',
      r'   \_`--´   ',
      '   ~~~~~~   ',
    ],
  ],
  BuddySpecies.ghost: [
    [
      '            ',
      '   .----.   ',
      r'  / {E}  {E} \  ',
      '  |      |  ',
      '  ~`~``~`~  ',
    ],
    [
      '            ',
      '   .----.   ',
      r'  / {E}  {E} \  ',
      '  |      |  ',
      '  `~`~~`~`  ',
    ],
    [
      '    ~  ~    ',
      '   .----.   ',
      r'  / {E}  {E} \  ',
      '  |      |  ',
      '  ~~`~~`~~  ',
    ],
  ],
  BuddySpecies.axolotl: [
    [
      '            ',
      '}~(______)~{',
      '}~({E} .. {E})~{',
      '  ( .--. )  ',
      r'  (_/  \_)  ',
    ],
    [
      '            ',
      '~}(______){~',
      '~}({E} .. {E}){~',
      '  ( .--. )  ',
      r'  (_/  \_)  ',
    ],
    [
      '            ',
      '}~(______)~{',
      '}~({E} .. {E})~{',
      '  (  --  )  ',
      r'  ~_/  \_~  ',
    ],
  ],
  BuddySpecies.capybara: [
    [
      '            ',
      '  n______n  ',
      ' ( {E}    {E} ) ',
      ' (   oo   ) ',
      '  `------´  ',
    ],
    [
      '            ',
      '  n______n  ',
      ' ( {E}    {E} ) ',
      ' (   Oo   ) ',
      '  `------´  ',
    ],
    [
      '    ~  ~    ',
      '  u______n  ',
      ' ( {E}    {E} ) ',
      ' (   oo   ) ',
      '  `------´  ',
    ],
  ],
  BuddySpecies.cactus: [
    [
      '            ',
      ' n  ____  n ',
      ' | |{E}  {E}| | ',
      ' |_|    |_| ',
      '   |    |   ',
    ],
    [
      '            ',
      '    ____    ',
      ' n |{E}  {E}| n ',
      ' |_|    |_| ',
      '   |    |   ',
    ],
    [
      ' n        n ',
      ' |  ____  | ',
      ' | |{E}  {E}| | ',
      ' |_|    |_| ',
      '   |    |   ',
    ],
  ],
  BuddySpecies.robot: [
    [
      '            ',
      '   .[||].   ',
      '  [ {E}  {E} ]  ',
      '  [ ==== ]  ',
      '  `------´  ',
    ],
    [
      '            ',
      '   .[||].   ',
      '  [ {E}  {E} ]  ',
      '  [ -==- ]  ',
      '  `------´  ',
    ],
    [
      '     *      ',
      '   .[||].   ',
      '  [ {E}  {E} ]  ',
      '  [ ==== ]  ',
      '  `------´  ',
    ],
  ],
  BuddySpecies.rabbit: [
    [
      '            ',
      r'   (\__/)   ',
      '  ( {E}  {E} )  ',
      ' =(  ..  )= ',
      '  (")__(")  ',
    ],
    [
      '            ',
      '   (|__/)   ',
      '  ( {E}  {E} )  ',
      ' =(  ..  )= ',
      '  (")__(")  ',
    ],
    [
      '            ',
      r'   (\__/)   ',
      '  ( {E}  {E} )  ',
      ' =( .  . )= ',
      '  (")__(")  ',
    ],
  ],
  BuddySpecies.mushroom: [
    [
      '            ',
      ' .-o-OO-o-. ',
      '(__________)',
      '   |{E}  {E}|   ',
      '   |____|   ',
    ],
    [
      '            ',
      ' .-O-oo-O-. ',
      '(__________)',
      '   |{E}  {E}|   ',
      '   |____|   ',
    ],
    [
      '   . o  .   ',
      ' .-o-OO-o-. ',
      '(__________)',
      '   |{E}  {E}|   ',
      '   |____|   ',
    ],
  ],
  BuddySpecies.chonk: [
    [
      '            ',
      r'  /\    /\  ',
      ' ( {E}    {E} ) ',
      ' (   ..   ) ',
      '  `------´  ',
    ],
    [
      '            ',
      r'  /\    /|  ',
      ' ( {E}    {E} ) ',
      ' (   ..   ) ',
      '  `------´  ',
    ],
    [
      '            ',
      r'  /\    /\  ',
      ' ( {E}    {E} ) ',
      ' (   ..   ) ',
      '  `------´~ ',
    ],
  ],
};

const Map<BuddyHat, String> _hatLines = {
  BuddyHat.none: '',
  BuddyHat.crown: r'   \^^^/    ',
  BuddyHat.tophat: '   [___]    ',
  BuddyHat.propeller: '    -+-     ',
  BuddyHat.halo: '   (   )    ',
  BuddyHat.wizard: r'    /^\     ',
  BuddyHat.beanie: '   (___)    ',
  BuddyHat.tinyduck: '    ,>      ',
};

/// 空闲动画序列：大部分时间静止（帧 0），偶尔 fidget（帧 1-2），偶尔眨眼
/// （-1 = 用帧 0 但把眼睛换成 `-`）。与原版 `IDLE_SEQUENCE` 一致。
const List<int> kBuddyIdleSequence = [
  0, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 2, 0, 0, 0, //
];

/// 某物种的动画帧数。
int buddyFrameCount(BuddySpecies species) => _bodies[species]!.length;

/// 渲染一帧精灵图（替换眼睛、放帽子）。[blink] 为 true 时眼睛换成 `-`。
List<String> renderBuddySprite(
  BuddyBones bones, {
  int frame = 0,
  bool blink = false,
}) {
  final frames = _bodies[bones.species]!;
  final eye = blink ? '-' : bones.eye;
  final lines = [
    for (final line in frames[frame % frames.length])
      line.replaceAll('{E}', eye),
  ];
  // 帽子只在第 0 行为空时才画（部分 fidget 帧用第 0 行画烟/星星等特效）。
  if (bones.hat != BuddyHat.none && lines[0].trim().isEmpty) {
    lines[0] = _hatLines[bones.hat]!;
  }
  return lines;
}

/// 一行文字脸（窄空间/侧边栏用），与原版 `renderFace` 一致。
String renderBuddyFace(BuddyBones bones) {
  final eye = bones.eye;
  switch (bones.species) {
    case BuddySpecies.duck:
    case BuddySpecies.goose:
      return '($eye>';
    case BuddySpecies.blob:
      return '($eye$eye)';
    case BuddySpecies.cat:
      return '=$eyeω$eye=';
    case BuddySpecies.dragon:
      return '<$eye~$eye>';
    case BuddySpecies.octopus:
      return '~($eye$eye)~';
    case BuddySpecies.owl:
      return '($eye)($eye)';
    case BuddySpecies.penguin:
      return '($eye>)';
    case BuddySpecies.turtle:
      return '[${eye}_$eye]';
    case BuddySpecies.snail:
      return '$eye(@)';
    case BuddySpecies.ghost:
      return '/$eye$eye\\';
    case BuddySpecies.axolotl:
      return '}$eye.$eye{';
    case BuddySpecies.capybara:
      return '(${eye}oo$eye)';
    case BuddySpecies.cactus:
    case BuddySpecies.mushroom:
      return '|$eye  $eye|';
    case BuddySpecies.robot:
      return '[$eye$eye]';
    case BuddySpecies.rabbit:
      return '($eye..$eye)';
    case BuddySpecies.chonk:
      return '($eye.$eye)';
  }
}
