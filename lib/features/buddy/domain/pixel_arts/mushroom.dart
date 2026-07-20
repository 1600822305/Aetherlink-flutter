// 电子宠物像素图：蘑菇：红伞白点 + 奶油脸。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt mushroomArt = BuddyPixelArt(
  rows: [
    '................',
    '.....rrrrrr.....',
    '...rrrwwrrrr....',
    '..rrrrwwrrrrrr..',
    '.rrwwrrrrrrwwr..',
    '.rrwwrrrrrrwwr..',
    '.rrrrrrrwwrrrr..',
    '.rrrrrrrwwrrrr..',
    '..bbbbbbbbbbb...',
    '..bbEEbbbEEbb...',
    '..bbEEbbbEEbb...',
    '..bpbbbbbbbpb...',
    '..bppbbbbbppb...',
    '...bbbbbbbbb....',
    '....bb...bb.....',
    '................',
  ],
  palette: {
    'r': 0xFFE0605A,
    'w': 0xFFF6EFE3,
    'b': 0xFFF0DFC0,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
  },
);
