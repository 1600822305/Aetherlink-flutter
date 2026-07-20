// 电子宠物像素图：机器人：灰蓝 + 天线 + 指示灯。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt robotArt = BuddyPixelArt(
  rows: [
    '.......y........',
    '.......k........',
    '...kkkkkkkkkk...',
    '..kbbbbbbbbbbk..',
    '..kbEEbbbbEEbk..',
    '..kbEEbbbbEEbk..',
    '..kbbbbbbbbbbk..',
    '..kbbggggggbbk..',
    '..kkkkkkkkkkkk..',
    '...kbbbbbbbbk...',
    '..ykbbyybbbbky..',
    '..ykbbbbbbbbky..',
    '...kbbbbbbbbk...',
    '...kkkkkkkkkk...',
    '....kk....kk....',
    '................',
  ],
  palette: {
    'b': 0xFFC3CDD9,
    'k': 0xFF5B6B7E,
    'y': 0xFFF2C14E,
    'g': 0xFF69D2C8,
    'E': 0xFF3ACCE1,
    'p': kBuddyBlushColor,
  },
);
