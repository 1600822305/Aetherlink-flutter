// 电子宠物像素图：幽灵：白色 + 波浪下摆。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt ghostArt = BuddyPixelArt(
  rows: [
    '................',
    '....wwwwwwww....',
    '...wwwwwwwwww...',
    '..wwwwwwwwwwww..',
    '..wwEEwwwwEEww..',
    '..wwEEwwwwEEww..',
    '..wwwwwwwwwwww..',
    '..wpwwwoowwwpw..',
    '..wppwwwwwwppw..',
    '..wwwwwwwwwwww..',
    '..wwwwwwwwwwww..',
    '..wwwwwwwwwwww..',
    '..wwwwwwwwwwww..',
    '..ww.www.www.w..',
    '..w...ww..ww....',
    '................',
  ],
  palette: {
    'w': 0xFFEFF1F6,
    'o': 0xFF9AA3B5,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
  },
);
