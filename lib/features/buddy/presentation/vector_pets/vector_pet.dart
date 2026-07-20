// 矢量宠物公共接口 + 注册表：有矢量版的物种优先用矢量渲染（任意缩放
// 不糊），没有的物种继续用像素图。每个物种一个文件，模块化同 pixel_arts。

import 'dart:ui';

import 'package:aetherlink_flutter/features/buddy/domain/buddy_types.dart';

import 'nailong_vector.dart';

/// 一个物种的矢量画法。呼吸/挤压等整体动画由外层画布变换完成，
/// 实现里只需按 [blink] 画出当前表情，并用 [tint] 处理闪光金色调。
abstract class BuddyVectorArt {
  void paint(
    Canvas canvas,
    Size size, {
    required bool blink,
    required Color Function(Color) tint,
  });
}

const Map<BuddySpecies, BuddyVectorArt> kBuddyVectorArts = {
  BuddySpecies.nailong: NailongVectorArt(),
};
