// 电子宠物像素图：企鹅：黑背白肚 + 橙脚。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt penguinArt = BuddyPixelArt(
  rows: [
    '................',
    '....kkkkkkkk....',
    '...kkkkkkkkkk...',
    '..kkkkkkkkkkkk..',
    '..kkEEkkkkEEkk..',
    '..kkEEkkkkEEkk..',
    '..kkkkkoookkkk..',
    '..kpkwwwwwwkpk..',
    '..kppwwwwwwppk..',
    '..kkwwwwwwwwkk..',
    '..kkwwwwwwwwkk..',
    '..kkwwwwwwwwkk..',
    '..kkkwwwwwwkkk..',
    '...kkkkkkkkkk...',
    '....oo....oo....',
    '................',
  ],
  palette: {
    'k': 0xFF3A4454,
    'w': 0xFFF2F4F5,
    'o': 0xFFF08C2E,
    'E': 0xFFF2F4F5,
    'p': kBuddyBlushColor,
  },
);
