// 电子宠物像素图：鹅：白色长脖子 + 橙嘴。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt gooseArt = BuddyPixelArt(
  rows: [
    '................',
    '....wwwwww......',
    '...wwwwwwww.....',
    '...wwEEwwEE.....',
    '...wwEEwwEE.....',
    '...wwwoooo......',
    '...wwwwoo.......',
    '...wwww.........',
    '...wwww.........',
    '..wwwwwwwwww....',
    '.wwwwwwwwwwww...',
    '.wwwwwwwwwwwww..',
    '.wwwwwwwwwwwww..',
    '..wwwwwwwwwww...',
    '....oo...oo.....',
    '................',
  ],
  palette: {
    'w': 0xFFF3F1EA,
    'o': 0xFFF08C2E,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
  },
);
