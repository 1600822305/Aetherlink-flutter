// 电子宠物像素图：乌龟：绿色 + 格纹壳。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt turtleArt = BuddyPixelArt(
  rows: [
    '................',
    '................',
    '....ssssssss....',
    '...ssdssdssds...',
    '..ssdssdssdsss..',
    '..sdssdssdssds..',
    '..ssssssssssss..',
    '.bbbbbbbbbbbbbb.',
    'bbEEbbbbbbbbEEbb',
    'bbEEbbbbbbbbEEbb',
    'bpbbbbbbbbbbbbpb',
    'bppbbbbbbbbbbppb',
    '.bbbbbbbbbbbbbb.',
    '..bb..bbbb..bb..',
    '..bb...bb...bb..',
    '................',
  ],
  palette: {
    's': 0xFF7FB069,
    'd': 0xFF5E8A4C,
    'b': 0xFFB6D89A,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
  },
);
