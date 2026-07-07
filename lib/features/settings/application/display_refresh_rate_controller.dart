import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';

/// Storage key for the 刷新率 preference (外观设置 → 开发者工具).
const String kDisplayRefreshRateSettingKey = 'displayRefreshRate';

/// The user's display refresh-rate preference.
///
/// Android lets an app express a preferred display mode; some OEM power
/// policies otherwise throttle Flutter apps to 60Hz on high-refresh panels,
/// and conversely locking to 60Hz saves battery on 120Hz devices.
enum DisplayRefreshRate {
  /// Follow the system's choice (default).
  system('system', '跟随系统'),

  /// Request the panel's highest refresh rate (锁最高, e.g. 120Hz).
  high('high', '锁最高'),

  /// Request the lowest refresh rate (锁低, usually 60Hz — 省电).
  low('low', '锁60Hz');

  const DisplayRefreshRate(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static DisplayRefreshRate fromStorage(String? value) =>
      DisplayRefreshRate.values.firstWhere(
        (e) => e.storageValue == value,
        orElse: () => DisplayRefreshRate.system,
      );
}

/// Holds the 刷新率 preference: hydrated from the key/value store, written
/// through on change, and applied to the Android display immediately.
/// No-op on non-Android platforms (iOS follows Info.plist / system policy).
class DisplayRefreshRateController extends Notifier<DisplayRefreshRate> {
  @override
  DisplayRefreshRate build() {
    _hydrate();
    return DisplayRefreshRate.system;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kDisplayRefreshRateSettingKey);
    final value = DisplayRefreshRate.fromStorage(stored);
    if (value != state) {
      state = value;
    }
    // Re-assert on every launch: the preference does not survive process death
    // on the platform side.
    await _apply(value);
  }

  Future<void> set(DisplayRefreshRate value) async {
    state = value;
    await ref
        .read(appSettingsStoreProvider)
        .saveSetting(kDisplayRefreshRateSettingKey, value.storageValue);
    await _apply(value);
  }

  Future<void> _apply(DisplayRefreshRate value) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      switch (value) {
        case DisplayRefreshRate.system:
          await FlutterDisplayMode.setPreferredMode(DisplayMode.auto);
        case DisplayRefreshRate.high:
          await FlutterDisplayMode.setHighRefreshRate();
        case DisplayRefreshRate.low:
          await FlutterDisplayMode.setLowRefreshRate();
      }
    } catch (_) {
      // Unsupported device/ROM — silently keep the system default.
    }
  }
}

final displayRefreshRateControllerProvider =
    NotifierProvider<DisplayRefreshRateController, DisplayRefreshRate>(
      DisplayRefreshRateController.new,
    );
