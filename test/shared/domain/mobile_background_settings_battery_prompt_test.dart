import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/domain/mobile_background_settings.dart';

void main() {
  test('batteryPromptDismissed：默认 false，JSON 往返与 copyWith 保留', () {
    const defaults = MobileBackgroundSettings();
    expect(defaults.batteryPromptDismissed, isFalse);
    // 旧存档没有该字段 → false。
    expect(
      MobileBackgroundSettings.fromJson(const {}).batteryPromptDismissed,
      isFalse,
    );
    final dismissed = defaults.copyWith(batteryPromptDismissed: true);
    final roundTrip = MobileBackgroundSettings.fromJson(dismissed.toJson());
    expect(roundTrip.batteryPromptDismissed, isTrue);
    // 改其他字段不丢失。
    expect(
      roundTrip.copyWith(privacyMode: true).batteryPromptDismissed,
      isTrue,
    );
  });
  test('terminalKeepAlive：默认关，旧存档为关，JSON 往返保留', () {
    expect(const MobileBackgroundSettings().terminalKeepAlive, isFalse);
    expect(
      MobileBackgroundSettings.fromJson(const {}).terminalKeepAlive,
      isFalse,
    );
    final on = const MobileBackgroundSettings().copyWith(
      terminalKeepAlive: true,
    );
    expect(
      MobileBackgroundSettings.fromJson(on.toJson()).terminalKeepAlive,
      isTrue,
    );
  });
}
