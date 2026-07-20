// 电子宠物像素图：鸭子：黄色圆身 + 橙色扁嘴 + 呆毛。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt duckArt = BuddyPixelArt(
  rows: [
    '.......b........',
    '......bb........',
    '....bbbbbbbb....',
    '...bbbbbbbbbb...',
    '..bbbbbbbbbbbb..',
    '..bbEEbbbbEEbb..',
    '..bbEEbbbbEEbb..',
    '..bpbbboobbbpb..',
    '..bppbooooBppb..',
    '..bbbbboobbbbb..',
    '..bbbbbbbbbbbb..',
    '..lbbbbbbbbbbl..',
    '...bbbbbbbbbb...',
    '....bbbbbbbb....',
    '....oo....oo....',
    '................',
  ],
  palette: {
    'b': 0xFFF7D154,
    'l': 0xFFFBE38A,
    'o': 0xFFF08C2E,
    'B': 0xFFD9741C,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
  },
);
