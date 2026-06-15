import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/platform/device_info_api.dart';
import 'package:aetherlink_flutter/core/platform/impl/device_info_impl.dart';

/// Headless smoke test for the platform-detection funnel — the single source of
/// truth that replaces scattered `Platform.is*` (ADR-0007). Runs on the desktop
/// test host; device-channel `describe()` is exercised on-device, not here.
void main() {
  final deviceInfo = PluginDeviceInfoApi();

  test('classifies the host as exactly one desktop platform', () {
    expect(
      deviceInfo.platform,
      anyOf(HostPlatform.linux, HostPlatform.macos, HostPlatform.windows),
    );
    expect(deviceInfo.isDesktop, isTrue);
    expect(deviceInfo.isMobile, isFalse);
    expect(deviceInfo.isAndroid, isFalse);
    expect(deviceInfo.isIOS, isFalse);
  });

  test('boolean getters stay consistent with platform', () {
    final platform = deviceInfo.platform;
    expect(deviceInfo.isAndroid, platform == HostPlatform.android);
    expect(deviceInfo.isIOS, platform == HostPlatform.ios);
    expect(
      deviceInfo.isMobile,
      platform == HostPlatform.android || platform == HostPlatform.ios,
    );
    expect(deviceInfo.isMobile, isNot(deviceInfo.isDesktop));
  });
}
