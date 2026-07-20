// 电子宠物像素图：水豚：棕色方脸 + 淡定小眼。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt capybaraArt = BuddyPixelArt(
  rows: [
    '................',
    '................',
    '..bb........bb..',
    '..bbbbbbbbbbbb..',
    '.bbbbbbbbbbbbbb.',
    '.bbEEbbbbbbEEbb.',
    '.bbbbbbbbbbbbbb.',
    '.bpbbbbddbbbbpb.',
    '.bppbbbddbbbppb.',
    '.bbbbbbbbbbbbbb.',
    '.bbbbbbbbbbbbbb.',
    '.bbbbbbbbbbbbbb.',
    '..bbbbbbbbbbbb..',
    '..bbbbbbbbbbbb..',
    '...bb..bb..bb...',
    '................',
  ],
  palette: {
    'b': 0xFFB98A5E,
    'd': 0xFF8F6640,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
  },
);
