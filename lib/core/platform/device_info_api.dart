/// The host operating system the app is running on.
enum HostPlatform { android, ios, macos, windows, linux, fuchsia, unknown }

/// Basic, human-readable device description.
class DeviceDescription {
  const DeviceDescription({
    required this.platform,
    required this.model,
    required this.osVersion,
  });

  final HostPlatform platform;
  final String model;
  final String osVersion;
}

/// Single source of truth for platform detection and basic device info.
///
/// Upper layers MUST route platform branching through this instead of
/// scattering `Platform.isAndroid` (ADR-0007). Implemented with `dart:io` +
/// `device_info_plus` under `impl/`; the interface stays pure Dart.
abstract interface class DeviceInfoApi {
  HostPlatform get platform;

  bool get isAndroid;

  bool get isIOS;

  bool get isMobile;

  bool get isDesktop;

  /// Fetches the device model and OS version from the platform.
  Future<DeviceDescription> describe();
}
