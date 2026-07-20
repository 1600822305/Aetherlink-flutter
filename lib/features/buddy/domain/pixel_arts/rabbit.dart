// 电子宠物像素图：兔子：白色长耳 + 粉耳芯。32×32，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt rabbitArt = BuddyPixelArt(
  rows: [
    '.......HH..........HH...........',
    '.....HHwwHS......HHwwHS.........',
    '.....wwmmww......wwmmww.........',
    '....HwmmmmwS....HwmmmmwS........',
    '....wwmmmmwS....wwmmmmwS........',
    '....wwmmmmwS....wwmmmmwS........',
    '....wwmmmmww....wwmmmmwS........',
    '....wwwmmwwwH..HwwwmmwwS........',
    '....wwwwwwwwwHHwwwwwwwww........',
    '...HwwwwwwwwwwwwwwwwwwwwS.......',
    '...wwwwwwwwwwwwwwwwwwwwww.......',
    '..HwwwwwwwwwwwwwwwwwwwwwwS......',
    '..wwwwwEEwwwwwwwwwwEEwwwwS......',
    '..wwwwEEEEwwwwwwwwEEEEwwwS......',
    '..wwwwEEEEwwwwwwwwEEEEwwwS......',
    '..wwwwwEEwwwwwwwwwwEEwwwwS......',
    '..wwppwwwwwwmmmmwwwwwwppwS......',
    '..wwpppwwwwwmmmmwwwwwpppwS......',
    '..wwppppwwwwwwwwwwwwppppwS......',
    '..wwwpppwwwwwwwwwwwwpppwwS......',
    '..SwwwwwwwwwwwwwwwwwwwwwwS......',
    '...wwwwwwwwwwwwwwwwwwwwwS.......',
    '...SwwwwwwwwwwwwwwwwwwwwS.......',
    '....wwwwwwwwwwwwwwwwwwwS........',
    '....wwwwwwwwwwwwwwwwwwwS........',
    '....wwwwwwwwwwwwwwwwwwwS........',
    '....SwwwwwwwwwwwwwwwwwwS........',
    '.....wwwwwwSSSSSSwwwwwS.........',
    '.....SSwwSS......SSwwSS.........',
    '.......SS..........SS...........',
    '................................',
    '................................',
  ],
  palette: {
    'w': 0xFFF6F3EE,
    'm': 0xFFF0A8B8,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
    'S': 0xFFCAC7C3,
    'H': 0xFFF8F6F2,
  },
);
