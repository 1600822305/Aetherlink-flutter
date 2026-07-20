// 电子宠物像素图：幽灵：白色 + 波浪下摆。32×32，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt ghostArt = BuddyPixelArt(
  rows: [
    '................................',
    '................................',
    '.........HHHHHHHHHHHHHH.........',
    '.......HHwwwwwwwwwwwwwwHS.......',
    '.......wwwwwwwwwwwwwwwwww.......',
    '.....HHwwwwwwwwwwwwwwwwwwHS.....',
    '.....wwwwwwwwwwwwwwwwwwwwww.....',
    '....HwwwwwwwwwwwwwwwwwwwwwwS....',
    '....wwwwwEEwwwwwwwwwwEEwwwwS....',
    '....wwwwEEEEwwwwwwwwEEEEwwwS....',
    '....wwwwEEEEwwwwwwwwEEEEwwwS....',
    '....wwwwwEEwwwwwwwwwwEEwwwwS....',
    '....wwwwwwwwwwwwwwwwwwwwwwwS....',
    '....wwwwwwwwwwwwwwwwwwwwwwwS....',
    '....wwppwwwwwwoooowwwwwwppwS....',
    '....wwpppwwwwwoooowwwwwpppwS....',
    '....wwppppwwwwwwwwwwwwppppwS....',
    '....wwwpppwwwwwwwwwwwwpppwwS....',
    '....wwwwwwwwwwwwwwwwwwwwwwwS....',
    '....wwwwwwwwwwwwwwwwwwwwwwwS....',
    '....wwwwwwwwwwwwwwwwwwwwwwwS....',
    '....wwwwwwwwwwwwwwwwwwwwwwwS....',
    '....wwwwwwwwwwwwwwwwwwwwwwwS....',
    '....wwwwwwwwwwwwwwwwwwwwwwwS....',
    '....wwwwwwwwwwwwwwwwwwwwwwwS....',
    '....wwwwSSwwwwwwSSwwwwwwSSwS....',
    '....wwwS..SwwwwS..SwwwwS..wS....',
    '....wwS....wwwwS...wwwwS..SS....',
    '....wwS....SSwwS...SSwwS........',
    '....SS.......SS......SS.........',
    '................................',
    '................................',
  ],
  palette: {
    'w': 0xFFEFF1F6,
    'o': 0xFF9AA3B5,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
    'S': 0xFFC4C6CA,
    'H': 0xFFF3F4F8,
  },
);
