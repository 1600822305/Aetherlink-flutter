// 电子宠物像素图：龙：绿色 + 角 + 小翅膀。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt dragonArt = BuddyPixelArt(
  rows: [
    '...y......y.....',
    '..yy......yy....',
    '..bbbbbbbbbb....',
    '.bbbbbbbbbbbb...',
    '.bbEEbbbbEEbb...',
    '.bbEEbbbbEEbb...',
    '.bbbbbbbbbbbb...',
    '.bpbbnnnnbbpb...',
    '.bppbbbbbbppb...',
    'dbbbbbbbbbbbbd..',
    'ddbbbbbbbbbbdd..',
    '.dbbbbbbbbbbd...',
    '..bbbbbbbbbb....',
    '..bbbbbbbbbbyy..',
    '...bb...bb..y...',
    '................',
  ],
  palette: {
    'b': 0xFF6DBF6D,
    'd': 0xFF4A9B57,
    'y': 0xFFF2C14E,
    'n': 0xFF9FE0A0,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
  },
);
