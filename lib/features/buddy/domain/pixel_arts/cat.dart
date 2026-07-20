// 电子宠物像素图：猫：灰色三角耳 + 胡须。16×16，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt catArt = BuddyPixelArt(
  rows: [
    '................',
    '..bb......bb....',
    '..bdb....bdb....',
    '..bddb..bddb....',
    '..bbbbbbbbbb....',
    '.bbbbbbbbbbbb...',
    '.bbEEbbbbEEbb...',
    'wbbEEbbbbEEbbw..',
    '.bpbbbmmbbbpb...',
    '.bppbbmmbbppb...',
    '.bbbbbbbbbbbb...',
    '..bbbbbbbbbb....',
    '..bbbbbbbbbbd...',
    '..bbbbbbbbbbbd..',
    '...bb..bb...d...',
    '................',
  ],
  palette: {
    'b': 0xFF9E9AA7,
    'd': 0xFF6F6A7A,
    'm': 0xFFE08AA0,
    'w': 0xFFDDDAE2,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
  },
);
