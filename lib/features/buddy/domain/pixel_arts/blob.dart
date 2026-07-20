// 电子宠物像素图：果冻：半透明感绿色布丁。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt blobArt = BuddyPixelArt(
  rows: [
    '................',
    '................',
    '................',
    '.....bbbbbb.....',
    '...bbbbbbbbbb...',
    '..bblbbbbbbbb...',
    '..blbEEbbEEbb...',
    '..bbbEEbbEEbbb..',
    '..bbbbbbbbbbbb..',
    '..bpbbbmmbbbpb..',
    '..bppbbbbbbppb..',
    '..bbbbbbbbbbbb..',
    '.bbbbbbbbbbbbbb.',
    '.bbbbbbbbbbbbbb.',
    '..dbbdbbdbbdbb..',
    '................',
  ],
  palette: {
    'b': 0xFF6FD98B,
    'l': 0xFFA8EFBB,
    'd': 0xFF4CB86B,
    'm': 0xFF3C8F52,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
  },
);
