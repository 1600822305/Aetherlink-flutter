import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/app.dart';
import 'package:aetherlink_flutter/features/backup/data/backup_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status / navigation bars so the themed overlay (set per
  // brightness in [AetherlinkApp]) replaces Android's opaque/contrast-scrimmed
  // system bars — no white mask behind the bottom navigation bar.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await BackupNotificationService().initialize();
  runApp(const ProviderScope(child: AetherlinkApp()));
}
