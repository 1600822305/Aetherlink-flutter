// 电子宠物像素图：六角恐龙：粉色 + 两侧外鳃。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt axolotlArt = BuddyPixelArt(
  rows: [
    '................',
    '.m..........m...',
    '.mm.bbbbbb.mm...',
    '..mbbbbbbbbm....',
    '.mmbbbbbbbbmm...',
    '..mbEEbbEEbm....',
    '.mmbEEbbEEbmm...',
    '..bbbbbbbbbb....',
    '..bpbbnnbbpb....',
    '..bppbbbbppb....',
    '..bbbbbbbbbb....',
    '..bbbbbbbbbbbb..',
    '..bbbbbbbbbbbb..',
    '...bbbbbbbbbb...',
    '...bb......bb...',
    '................',
  ],
  palette: {
    'b': 0xFFF6C6CF,
    'm': 0xFFE87F96,
    'n': 0xFFD96A84,
    'E': kBuddyEyeColor,
    'p': 0xFFED9DAD,
  },
);
