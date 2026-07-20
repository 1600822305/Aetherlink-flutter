// 电子宠物像素图：猫头鹰：棕色 + 大眼圈 + 耳羽。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt owlArt = BuddyPixelArt(
  rows: [
    '..b........b....',
    '..bb......bb....',
    '..bbbbbbbbbb....',
    '.bbbbbbbbbbbb...',
    '.bwwwwbbwwwwb...',
    '.bwEEwbbwEEwb...',
    '.bwEEwbbwEEwb...',
    '.bwwwwoowwwwb...',
    '.bbbbboobbbbb...',
    '.bpbbbbbbbbpb...',
    '.bplblblblbpb...',
    '.bblblblblbbb...',
    '..bbbbbbbbbb....',
    '..bbbbbbbbbb....',
    '....oo...oo.....',
    '................',
  ],
  palette: {
    'b': 0xFFA9825F,
    'l': 0xFFC7A37E,
    'w': 0xFFF3EAD9,
    'o': 0xFFE8A13C,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
  },
);
