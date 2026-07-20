// 电子宠物像素图：兔子：白色长耳 + 粉耳芯。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt rabbitArt = BuddyPixelArt(
  rows: [
    '...ww....ww.....',
    '..wmmw..wmmw....',
    '..wmmw..wmmw....',
    '..wmmw..wmmw....',
    '..wwwwwwwwww....',
    '.wwwwwwwwwwww...',
    '.wwEEwwwwEEww...',
    '.wwEEwwwwEEww...',
    '.wpwwwmmwwwpw...',
    '.wppwwwwwwppw...',
    '.wwwwwwwwwwww...',
    '..wwwwwwwwww....',
    '..wwwwwwwwww....',
    '..wwwwwwwwww....',
    '...ww....ww.....',
    '................',
  ],
  palette: {
    'w': 0xFFF6F3EE,
    'm': 0xFFF0A8B8,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
  },
);
