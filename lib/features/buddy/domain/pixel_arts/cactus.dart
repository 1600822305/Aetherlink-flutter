// 电子宠物像素图：仙人掌：绿色 + 花盆 + 小花。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt cactusArt = BuddyPixelArt(
  rows: [
    '......ff........',
    '.....ffff.......',
    '....bbbbbb......',
    '....bbbbbb......',
    '.bb.bEEbEE......',
    '.bb.bEEbEE.bb...',
    '.bbbbbbbbb.bb...',
    '..bbbpbbpbbbb...',
    '....bppbppb.....',
    '....bbbbbb......',
    '....bbbbbb......',
    '...tttttttt.....',
    '....tttttt......',
    '....tttttt......',
    '....tttttt......',
    '................',
  ],
  palette: {
    'b': 0xFF74C27A,
    'f': 0xFFF2A0C0,
    't': 0xFFC9764A,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
  },
);
