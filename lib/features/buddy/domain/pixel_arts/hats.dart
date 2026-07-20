// 帽子像素图（小图，渲染器锚定在头顶第一行非透明像素上方叠加）。

import '../buddy_types.dart';
import 'pixel_art.dart';

const Map<BuddyHat, BuddyPixelArt> kBuddyHatArts = {
  BuddyHat.crown: BuddyPixelArt(
    rows: [
    'yy....yy....yy',
    'yyy..yyyy..yyy',
    'yyyyyyyyyyyyyy',
    'yyyyyyyyyyyyyy',
    'yyyyyyyyyyyyyy',
    '.yyyyyyyyyyyy.',
  ],
    palette: {'y': 0xFFF2C14E},
  ),
  BuddyHat.tophat: BuddyPixelArt(
    rows: [
    '...kkkkkkkk...',
    '..kkkkkkkkkk..',
    '..kkkkkkkkkk..',
    '.kkkkkkkkkkkk.',
    'kkkkkkkkkkkkkk',
    'kkkkkkkkkkkkkk',
  ],
    palette: {'k': 0xFF3A3F4A},
  ),
  BuddyHat.propeller: BuddyPixelArt(
    rows: [
    'rr....yy....bb',
    'rrr..yyyy..bbb',
    '.rrryyyyyybbb.',
    '..rryyyyyybb..',
    '....yyyyyy....',
    '.....yyyy.....',
  ],
    palette: {'r': 0xFFE0605A, 'y': 0xFFF2C14E, 'b': 0xFF5B8DEF},
  ),
  BuddyHat.halo: BuddyPixelArt(
    rows: [
    '..yyyyyyyyyy..',
    '.yyyyyyyyyyyy.',
    'yy..........yy',
    'yy..........yy',
    '.yyyyyyyyyyyy.',
    '..yyyyyyyyyy..',
  ],
    palette: {'y': 0xFFF7DE8B},
  ),
  BuddyHat.wizard: BuddyPixelArt(
    rows: [
    '......vv......',
    '.....vvvv.....',
    '.....vvvv.....',
    '...vvvvvvvv...',
    '...vvvyyvvv...',
    '.vvvvvyyvvvvv.',
    'vvvvvvvvvvvvvv',
    'vvvvvvvvvvvvvv',
  ],
    palette: {'v': 0xFF7B5CC7, 'y': 0xFFF2C14E},
  ),
  BuddyHat.beanie: BuddyPixelArt(
    rows: [
    '.....rr.......',
    '...rrrrrr.....',
    '...rrrrrr.....',
    '.rrrrrrrrr....',
    'rrwwrrwwrrwwrr',
    'rrwwrrwwrrwwrr',
  ],
    palette: {'r': 0xFFD96A6A, 'w': 0xFFF3EAD9},
  ),
  BuddyHat.tinyduck: BuddyPixelArt(
    rows: [
    '...yy...',
    '..yyyyy.',
    'ooyyyyyy',
    'ooyyyyyy',
    '..yyyyy.',
    '...yy...',
  ],
    palette: {'y': 0xFFF7D154, 'o': 0xFFF08C2E},
  ),
};
