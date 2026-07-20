// 帽子像素图（小图，渲染器锚定在头顶第一行非透明像素上方叠加）。

import '../buddy_types.dart';
import 'pixel_art.dart';

const Map<BuddyHat, BuddyPixelArt> kBuddyHatArts = {
  BuddyHat.crown: BuddyPixelArt(
    rows: [
      'y..y..y',
      'yyyyyyy',
      'yyyyyyy',
    ],
    palette: {'y': 0xFFF2C14E},
  ),
  BuddyHat.tophat: BuddyPixelArt(
    rows: [
      '.kkkkk.',
      '.kkkkk.',
      'kkkkkkk',
    ],
    palette: {'k': 0xFF3A3F4A},
  ),
  BuddyHat.propeller: BuddyPixelArt(
    rows: [
      'r..y..b',
      '.ryyyb.',
      '..yyy..',
    ],
    palette: {'r': 0xFFE0605A, 'y': 0xFFF2C14E, 'b': 0xFF5B8DEF},
  ),
  BuddyHat.halo: BuddyPixelArt(
    rows: [
      '.yyyyy.',
      'y.....y',
      '.yyyyy.',
    ],
    palette: {'y': 0xFFF7DE8B},
  ),
  BuddyHat.wizard: BuddyPixelArt(
    rows: [
      '...v...',
      '..vvv..',
      '.vvyvv.',
      'vvvvvvv',
    ],
    palette: {'v': 0xFF7B5CC7, 'y': 0xFFF2C14E},
  ),
  BuddyHat.beanie: BuddyPixelArt(
    rows: [
      '..rr...',
      '.rrrr..',
      'rwrwrwr',
    ],
    palette: {'r': 0xFFD96A6A, 'w': 0xFFF3EAD9},
  ),
  BuddyHat.tinyduck: BuddyPixelArt(
    rows: [
      '.yy.',
      'oyyy',
      '.yy.',
    ],
    palette: {'y': 0xFFF7D154, 'o': 0xFFF08C2E},
  ),
};
