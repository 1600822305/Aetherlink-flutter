// 电子宠物像素图：章鱼：紫色圆头 + 波浪触手。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt octopusArt = BuddyPixelArt(
  rows: [
    '................',
    '................',
    '....bbbbbbbb....',
    '...bbbbbbbbbb...',
    '..bbbbbbbbbbbb..',
    '..bbEEbbbbEEbb..',
    '..bbEEbbbbEEbb..',
    '..bbbbbbbbbbbb..',
    '..bpbbbmmbbbpb..',
    '..bppbbbbbbppb..',
    '..bbbbbbbbbbbb..',
    '..bbbbbbbbbbbb..',
    '..b.bb.bb.bb.b..',
    '..b.bb.bb.bb.b..',
    '.db.db.db.db.d..',
    '................',
  ],
  palette: {
    'b': 0xFFB08AD9,
    'd': 0xFF8A63B8,
    'm': 0xFF6E4C99,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
  },
);
