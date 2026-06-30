import 'dart:async';

import 'package:aetherlink_devtools/aetherlink_devtools.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/app.dart';
import 'package:aetherlink_flutter/app/devtools/device_panel.dart';
import 'package:aetherlink_flutter/app/devtools/diagnostics_context.dart';
import 'package:aetherlink_flutter/app/devtools/performance_panel.dart';
import 'package:aetherlink_flutter/app/devtools/storage_panel.dart';
import 'package:aetherlink_flutter/features/backup/data/backup_notification_service.dart';

void main() async {
  // Run inside a guarded zone so uncaught async errors are captured by the
  // in-app developer tools (Console panel). [DevToolsCapture.install] chains the
  // framework / platform error handlers and `debugPrint` — see
  // docs/design/devtools-design.md (P0).
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      DevToolsCapture.install();
      // Register the app-side bridge panels here (not inside aetherlink_devtools)
      // so that package needn't depend on aetherlink_perf / Drift / device_info:
      // Performance (P3) reads the shared PerfMonitor; Storage/Device (P4) read
      // the live DB + SharedPreferences + device info. See devtools-design.
      DevToolsRegistry.register(const PerformancePanel());
      DevToolsRegistry.register(const StoragePanel());
      DevToolsRegistry.register(const DevicePanel());
      // Feed device/env context into the Console's "复制为 AI 诊断" export.
      initDiagnosticsContext();
      // Draw behind the status / navigation bars so the themed overlay (set per
      // brightness in [AetherlinkApp]) replaces Android's opaque/contrast-scrimmed
      // system bars — no white mask behind the bottom navigation bar.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await BackupNotificationService().initialize();
      runApp(const ProviderScope(child: AetherlinkApp()));
    },
    DevToolsCapture.zoneErrorHandler,
  );
}
