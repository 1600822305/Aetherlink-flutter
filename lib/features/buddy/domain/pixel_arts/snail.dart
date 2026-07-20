// 电子宠物像素图：蜗牛：奶油身体 + 螺旋壳。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt snailArt = BuddyPixelArt(
  rows: [
    '..k.....k.......',
    '..k.....k.......',
    '..bb...bb.......',
    '..bbbbbbb.......',
    '..bEEbbEE.ssss..',
    '..bEEbbEEssssss.',
    '..bbbbbbsdddss..',
    '..bpbbbbsdsdsss.',
    '..bppbbbsddddss.',
    '..bbbbbbssssss..',
    '..bbbbbbbsssss..',
    '..bbbbbbbbbbbb..',
    '.bbbbbbbbbbbbbb.',
    '.bbbbbbbbbbbbbb.',
    '................',
    '................',
  ],
  palette: {
    'b': 0xFFEFD9A7,
    's': 0xFFC98A5B,
    'd': 0xFFA96A3E,
    'k': 0xFF8A6A4A,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
  },
);
