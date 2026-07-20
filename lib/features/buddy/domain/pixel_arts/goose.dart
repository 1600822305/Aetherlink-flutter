// 电子宠物像素图：鹅：白色长脖子 + 橙嘴。32×32，字符 → 调色板；`.` 透明，
// `E` 眼睛（渲染器负责眨眼/高光），`p` 腮红。

import 'pixel_art.dart';

const BuddyPixelArt gooseArt = BuddyPixelArt(
  rows: [
    '................................',
    '................................',
    '.........HHHHHHHHHH.............',
    '.......HHwwwwwwwwwwHS...........',
    '.......wwwwwwwwwwwwww...........',
    '......HwwwwwwwwwwwwwwS..........',
    '......wwwwwEEwwwwwwEEE..........',
    '......wwwwEEEEwwwwEEEE..........',
    '......wwwwEEEEwwwwEEEE..........',
    '......wwwwwEEEwwwwEEE...........',
    '......wwwwwwoooooooo............',
    '......wwwwwwwoooooo.............',
    '......wwwwwwwoooooo.............',
    '......wwwwwwwwooo...............',
    '......wwwwwwwS..................',
    '......wwwwwwwS..................',
    '......wwwwwwww..................',
    '.....HwwwwwwwwH.................',
    '.....wwwwwwwwwwHHHHHHHH.........',
    '...HHwwwwwwwwwwwwwwwwwwHS.......',
    '...wwwwwwwwwwwwwwwwwwwwww.......',
    '..HwwwwwwwwwwwwwwwwwwwwwwHS.....',
    '..wwwwwwwwwwwwwwwwwwwwwwwww.....',
    '..wwwwwwwwwwwwwwwwwwwwwwwwwS....',
    '..SwwwwwwwwwwwwwwwwwwwwwwwwS....',
    '...wwwwwwwwwwwwwwwwwwwwwwwS.....',
    '...SSwwwwwwwwwwwwwwwwwwwwSS.....',
    '.....SSSwwwwSSSSSSwwwwSSS.......',
    '........oooo......oooo..........',
    '.........oo........oo...........',
    '................................',
    '................................',
  ],
  palette: {
    'w': 0xFFF3F1EA,
    'o': 0xFFF08C2E,
    'E': kBuddyEyeColor,
    'p': kBuddyBlushColor,
    'S': 0xFFC7C6C0,
    'H': 0xFFF6F4EF,
  },
);
