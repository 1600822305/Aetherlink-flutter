import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import 'package:aetherlink_flutter/core/platform/device_info_api.dart';

/// [DeviceInfoApi] backed by `dart:io` `Platform` (detection) and
/// `device_info_plus` (model/OS). The only place those are imported, so
/// platform branching is funneled here instead of scattered across the app.
class PluginDeviceInfoApi implements DeviceInfoApi {
  PluginDeviceInfoApi([DeviceInfoPlugin? plugin])
    : _plugin = plugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _plugin;

  @override
  HostPlatform get platform {
    if (Platform.isAndroid) return HostPlatform.android;
    if (Platform.isIOS) return HostPlatform.ios;
    if (Platform.isMacOS) return HostPlatform.macos;
    if (Platform.isWindows) return HostPlatform.windows;
    if (Platform.isLinux) return HostPlatform.linux;
    if (Platform.isFuchsia) return HostPlatform.fuchsia;
    return HostPlatform.unknown;
  }

  @override
  bool get isAndroid => platform == HostPlatform.android;

  @override
  bool get isIOS => platform == HostPlatform.ios;

  @override
  bool get isMobile =>
      platform == HostPlatform.android || platform == HostPlatform.ios;

  @override
  bool get isDesktop =>
      platform == HostPlatform.macos ||
      platform == HostPlatform.windows ||
      platform == HostPlatform.linux;

  @override
  Future<DeviceDescription> describe() async {
    switch (platform) {
      case HostPlatform.android:
        final info = await _plugin.androidInfo;
        return DeviceDescription(
          platform: HostPlatform.android,
          model: info.model,
          osVersion: 'Android ${info.version.release}',
        );
      case HostPlatform.ios:
        final info = await _plugin.iosInfo;
        return DeviceDescription(
          platform: HostPlatform.ios,
          model: info.model,
          osVersion: '${info.systemName} ${info.systemVersion}',
        );
      case HostPlatform.macos:
        final info = await _plugin.macOsInfo;
        return DeviceDescription(
          platform: HostPlatform.macos,
          model: info.model,
          osVersion: 'macOS ${info.osRelease}',
        );
      case HostPlatform.windows:
        final info = await _plugin.windowsInfo;
        return DeviceDescription(
          platform: HostPlatform.windows,
          model: info.productName,
          osVersion: 'Windows build ${info.buildNumber}',
        );
      case HostPlatform.linux:
        final info = await _plugin.linuxInfo;
        return DeviceDescription(
          platform: HostPlatform.linux,
          model: info.name,
          osVersion: info.version ?? '',
        );
      case HostPlatform.fuchsia:
      case HostPlatform.unknown:
        return DeviceDescription(
          platform: platform,
          model: 'unknown',
          osVersion: 'unknown',
        );
    }
  }
}
