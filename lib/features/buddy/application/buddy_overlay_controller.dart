// 悬浮宠物设置：开关 + 拖动后的吸附位置，单键 JSON 持久化
// （同 hooks/压缩设置的模式），重启后宠物还在原地。

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';

/// Settings-store key（单键 JSON）。
const String kBuddyOverlaySettingsKey = 'buddy_overlay_settings';

class BuddyOverlaySettings {
  const BuddyOverlaySettings({
    this.enabled = false,
    this.dx = 0,
    this.dy = 260,
    this.snapLeft = true,
  });

  /// 悬浮宠物总开关（默认关，宠物页里打开）。
  final bool enabled;

  /// 上次松手吸附后的位置（dx 仅在展开卡片时参考，胶囊贴边）。
  final double dx;
  final double dy;

  /// 吸附在左边缘还是右边缘。
  final bool snapLeft;

  BuddyOverlaySettings copyWith({
    bool? enabled,
    double? dx,
    double? dy,
    bool? snapLeft,
  }) =>
      BuddyOverlaySettings(
        enabled: enabled ?? this.enabled,
        dx: dx ?? this.dx,
        dy: dy ?? this.dy,
        snapLeft: snapLeft ?? this.snapLeft,
      );
}

String encodeBuddyOverlaySettings(BuddyOverlaySettings s) => jsonEncode({
      'enabled': s.enabled,
      'dx': s.dx,
      'dy': s.dy,
      'snapLeft': s.snapLeft,
    });

BuddyOverlaySettings decodeBuddyOverlaySettings(String? raw) {
  const fallback = BuddyOverlaySettings();
  if (raw == null || raw.isEmpty) return fallback;
  try {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return fallback;
    return BuddyOverlaySettings(
      enabled: json['enabled'] is bool ? json['enabled'] as bool : false,
      dx: json['dx'] is num ? (json['dx'] as num).toDouble() : fallback.dx,
      dy: json['dy'] is num ? (json['dy'] as num).toDouble() : fallback.dy,
      snapLeft: json['snapLeft'] is bool ? json['snapLeft'] as bool : true,
    );
  } catch (_) {
    return fallback;
  }
}

final buddyOverlayControllerProvider = NotifierProvider<BuddyOverlayController,
    BuddyOverlaySettings>(BuddyOverlayController.new);

class BuddyOverlayController extends Notifier<BuddyOverlaySettings> {
  /// 异步加载完成前不写库，避免加载期间的写入覆盖存量（同 hooks 设置）。
  bool _loaded = false;
  BuddyOverlaySettings? _pendingWrite;

  @override
  BuddyOverlaySettings build() {
    ref
        .read(appSettingsStoreProvider)
        .getSetting(kBuddyOverlaySettingsKey)
        .then((raw) {
      final pending = _pendingWrite;
      _loaded = true;
      if (pending != null) {
        state = pending;
        _persist();
      } else {
        state = decodeBuddyOverlaySettings(raw);
      }
    });
    return const BuddyOverlaySettings();
  }

  void setEnabled(bool value) => _set(state.copyWith(enabled: value));

  void setPosition({
    required double dy,
    required bool snapLeft,
  }) =>
      _set(state.copyWith(dy: dy, snapLeft: snapLeft));

  void _set(BuddyOverlaySettings value) {
    if (!_loaded) {
      _pendingWrite = value;
      state = value;
      return;
    }
    state = value;
    _persist();
  }

  void _persist() {
    ref.read(appSettingsStoreProvider).saveSetting(
        kBuddyOverlaySettingsKey, encodeBuddyOverlaySettings(state));
  }
}
