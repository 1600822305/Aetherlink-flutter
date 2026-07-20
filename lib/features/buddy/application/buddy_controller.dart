// 电子宠物状态控制器：只持久化「灵魂」（名字/性格/孵化时间/种子）单键
// JSON；「骨架」（物种/稀有度/闪光/属性）每次由种子确定性重算，编辑存储
// 也伪造不了稀有度。持久化走 appSettingsStore（同 hooks/压缩设置的模式）。

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/buddy/domain/buddy_engine.dart';
import 'package:aetherlink_flutter/features/buddy/domain/buddy_phrases.dart';
import 'package:aetherlink_flutter/features/buddy/domain/buddy_types.dart';

/// Settings-store key（单键 JSON 存灵魂）。
const String kBuddySoulKey = 'buddy_companion_soul';

/// 宠物状态：`soul == null` 表示还没孵化；[loaded] 为 false 表示存量
/// 还在异步读取中（页面先显示加载态，避免闪一下孵化页）。
class BuddyState {
  const BuddyState({this.soul, this.loaded = false});

  final BuddySoul? soul;
  final bool loaded;

  /// 骨架：由种子确定性重算（有缓存意义不大，rollBuddy 很便宜）。
  BuddyBones? get bones {
    final s = soul;
    return s == null ? null : rollBuddy(s.seed);
  }
}

final buddyControllerProvider =
    NotifierProvider<BuddyController, BuddyState>(BuddyController.new);

class BuddyController extends Notifier<BuddyState> {
  @override
  BuddyState build() {
    ref.read(appSettingsStoreProvider).getSetting(kBuddySoulKey).then((raw) {
      state = BuddyState(soul: decodeBuddySoul(raw), loaded: true);
    });
    return const BuddyState();
  }

  /// 孵化：生成一次性的随机种子（之后骨架永远由它决定），名字/性格从
  /// 本地池随机抽取并持久化。已孵化时无操作。
  BuddySoul hatch() {
    final existing = state.soul;
    if (existing != null) return existing;
    final random = Random();
    final now = DateTime.now().millisecondsSinceEpoch;
    final seed = '$now-${random.nextInt(1 << 32)}';
    final soul = BuddySoul(
      name: pickBuddyPhrase(random, kBuddyNames),
      personality: pickBuddyPhrase(random, kBuddyPersonalities),
      hatchedAt: now,
      seed: seed,
    );
    state = BuddyState(soul: soul, loaded: true);
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kBuddySoulKey, encodeBuddySoul(soul));
    return soul;
  }

  /// 放生：清掉灵魂（含种子），回到未孵化状态；之后可重新孵化一只新宠物。
  void release() {
    if (state.soul == null) return;
    state = const BuddyState(loaded: true);
    ref.read(appSettingsStoreProvider).saveSetting(kBuddySoulKey, '');
  }
}
