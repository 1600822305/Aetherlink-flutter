import 'dart:io';

import 'package:flutter/services.dart';

import 'package:aetherlink_flutter/core/platform/termux_api.dart';

/// [TermuxApi] backed by an Android platform channel (`aetherlink/termux`,
/// handled in MainActivity) that queries `PackageManager`. The only place that
/// channel is touched. On non-Android platforms it short-circuits to
/// [TermuxVariant.absent] (Termux is Android-only).
class PluginTermuxApi implements TermuxApi {
  const PluginTermuxApi();

  static const MethodChannel _channel = MethodChannel('aetherlink/termux');

  @override
  Future<TermuxInstallStatus> detect() async {
    if (!Platform.isAndroid) {
      return const TermuxInstallStatus(
        installed: false,
        variant: TermuxVariant.absent,
      );
    }
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('detect');
      final installed = result?['installed'] == true;
      final installer = (result?['installer'] as Object?)?.toString();
      return TermuxInstallStatus(
        installed: installed,
        installer: installer,
        variant: _variantOf(installed, installer),
      );
    } on PlatformException {
      // Treat a channel failure as "absent" — the UI then shows install
      // guidance, which is the safe degradation.
      return const TermuxInstallStatus(
        installed: false,
        variant: TermuxVariant.absent,
      );
    }
  }

  @override
  Future<void> runCommand(String script) async {
    if (!Platform.isAndroid) {
      throw const TermuxRunCommandException('仅 Android 支持 Termux 直连');
    }
    try {
      await _channel.invokeMethod<void>('runCommand', {'script': script});
    } on PlatformException catch (e) {
      throw TermuxRunCommandException(
        e.message ?? '发送 RUN_COMMAND 失败',
        externalAppsDisabled: e.code == 'external-apps-disabled',
        permissionDenied: e.code == 'permission-denied',
      );
    }
  }

  @override
  Future<void> openApp() async {
    if (!Platform.isAndroid) {
      throw const TermuxRunCommandException('仅 Android 支持 Termux 直连');
    }
    try {
      await _channel.invokeMethod<void>('openTermux');
    } on PlatformException catch (e) {
      throw TermuxRunCommandException(e.message ?? '打不开 Termux');
    }
  }

  static TermuxVariant _variantOf(bool installed, String? installer) {
    if (!installed) return TermuxVariant.absent;
    switch (installer) {
      case 'org.fdroid.fdroid':
        return TermuxVariant.fdroid;
      case 'com.android.vending':
        return TermuxVariant.play;
      default:
        return TermuxVariant.unknown; // GitHub / sideload — supported.
    }
  }
}
