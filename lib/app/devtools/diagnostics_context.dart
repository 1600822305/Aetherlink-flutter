import 'dart:io';

import 'package:aetherlink_devtools/aetherlink_devtools.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Cached device_info_plus map, filled once at startup (the lookup is async, the
/// provider must be synchronous).
Map<String, dynamic> _device = const {};

/// Wires [DevToolsDiagnostics.contextProvider] so the Console's "复制为 AI 诊断"
/// can prepend a device + environment block. Call once at startup; the provider
/// is set synchronously, the device map fills in shortly after.
void initDiagnosticsContext() {
  DevToolsDiagnostics.contextProvider = _build;
  DeviceInfoPlugin().deviceInfo.then((i) => _device = i.data).catchError((_) => const <String, dynamic>{});
}

String _build() {
  final mode = kReleaseMode
      ? 'release'
      : kProfileMode
      ? 'profile'
      : 'debug';
  final b = StringBuffer('=== 设备 / 环境 ===')
    ..writeln()
    ..writeln('构建模式: $mode')
    ..writeln('系统: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
    ..writeln('Locale: ${Platform.localeName}')
    ..writeln('CPU 核数: ${Platform.numberOfProcessors}')
    ..writeln('Dart: ${Platform.version.split(' ').first}');
  try {
    b.writeln('内存 RSS: ${(ProcessInfo.currentRss / 1048576).toStringAsFixed(0)} MB');
  } catch (_) {}
  for (final e in _device.entries) {
    final v = e.value;
    if (v is String || v is num || v is bool) {
      b.writeln('${e.key}: $v');
    }
  }
  return b.toString();
}
