// 像素图注册表：物种 → 像素图。每个物种一个文件，方便单独调整
// 造型/配色/加帧而不影响其他宠物。

import '../buddy_types.dart';
import 'axolotl.dart';
import 'blob.dart';
import 'cactus.dart';
import 'capybara.dart';
import 'cat.dart';
import 'chonk.dart';
import 'dragon.dart';
import 'duck.dart';
import 'ghost.dart';
import 'goose.dart';
import 'mushroom.dart';
import 'octopus.dart';
import 'owl.dart';
import 'penguin.dart';
import 'pixel_art.dart';
import 'rabbit.dart';
import 'robot.dart';
import 'snail.dart';
import 'turtle.dart';

export 'egg.dart';
export 'hats.dart';
export 'pixel_art.dart';

const Map<BuddySpecies, BuddyPixelArt> kBuddyPixelArts = {
  BuddySpecies.duck: duckArt,
  BuddySpecies.goose: gooseArt,
  BuddySpecies.blob: blobArt,
  BuddySpecies.cat: catArt,
  BuddySpecies.dragon: dragonArt,
  BuddySpecies.octopus: octopusArt,
  BuddySpecies.owl: owlArt,
  BuddySpecies.penguin: penguinArt,
  BuddySpecies.turtle: turtleArt,
  BuddySpecies.snail: snailArt,
  BuddySpecies.ghost: ghostArt,
  BuddySpecies.axolotl: axolotlArt,
  BuddySpecies.capybara: capybaraArt,
  BuddySpecies.cactus: cactusArt,
  BuddySpecies.robot: robotArt,
  BuddySpecies.rabbit: rabbitArt,
  BuddySpecies.mushroom: mushroomArt,
  BuddySpecies.chonk: chonkArt,
};
