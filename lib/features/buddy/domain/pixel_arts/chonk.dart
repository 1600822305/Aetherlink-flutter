// 电子宠物像素图：胖猫：滚圆灰橘猫 + 眯眯眼。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt chonkArt = BuddyPixelArt(
  rows: [
    '................',
    '..bb........bb..',
    '..bdb......bdb..',
    '..bbbbbbbbbbbb..',
    '.bbbbbbbbbbbbbb.',
    'bbbEEbbbbbbEEbbb',
    'bbbbbbbbbbbbbbbb',
    'bpbbbbbmmbbbbbpb',
    'bppbbbbmmbbbbppb',
    'bbbbbbbbbbbbbbbb',
    'bbbbbbbbbbbbbbbb',
    'bbbbbbbbbbbbbbbb',
    '.bbbbbbbbbbbbbb.',
    '..bbbbbbbbbbbb..',
    '...bb.bbbb.bb...',
    '................',
  ],
  palette: {
    'b': 0xFFE0B27A,
    'd': 0xFFB98A52,
    'm': 0xFFC97E5A,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
  },
);
