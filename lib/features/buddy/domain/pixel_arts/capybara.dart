// 电子宠物像素图：水豚：棕色方脸 + 淡定小眼。32×32，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt capybaraArt = BuddyPixelArt(
  rows: [
    '................................',
    '................................',
    '................................',
    '................................',
    '.....HH..................HH.....',
    '....HbbHH..............HHbbS....',
    '....bbbbbHHHHHHHHHHHHHHbbbbb....',
    '...HbbbbbbbbbbbbbbbbbbbbbbbbS...',
    '...bbbbbbbbbbbbbbbbbbbbbbbbbb...',
    '..HbbbbbbbbbbbbbbbbbbbbbbbbbbS..',
    '..bbbbEEEEbbbbbbbbbbbbEEEEbbbS..',
    '..bbbbEEEEbbbbbbbbbbbbEEEEbbbS..',
    '..bbbbbbbbbbbbbbbbbbbbbbbbbbbS..',
    '..bbbbbbbbbbbbbbbbbbbbbbbbbbbS..',
    '..bbppbbbbbbbbbddbbbbbbbbbppbS..',
    '..bbpppbbbbbbbddddbbbbbbbpppbS..',
    '..bbppppbbbbbbddddbbbbbbppppbS..',
    '..bbbpppbbbbbbbddbbbbbbbpppbbS..',
    '..bbbbbbbbbbbbbbbbbbbbbbbbbbbS..',
    '..bbbbbbbbbbbbbbbbbbbbbbbbbbbS..',
    '..bbbbbbbbbbbbbbbbbbbbbbbbbbbS..',
    '..bbbbbbbbbbbbbbbbbbbbbbbbbbbS..',
    '..SbbbbbbbbbbbbbbbbbbbbbbbbbbS..',
    '...bbbbbbbbbbbbbbbbbbbbbbbbbS...',
    '...SbbbbbbbbbbbbbbbbbbbbbbbbS...',
    '....bbbbbbbbbbbbbbbbbbbbbbbS....',
    '....SbbbbbbbbbbbbbbbbbbbbbbS....',
    '.....bbbbbbSSbbbbbbSSbbbbbS.....',
    '.....SSbbSS..SSbbSS..SSbbSS.....',
    '.......SS......SS......SS.......',
    '................................',
    '................................',
  ],
  palette: {
    'b': 0xFFB98A5E,
    'd': 0xFF8F6640,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
    'S': 0xFF98714D,
    'H': 0xFFC8A481,
  },
);
