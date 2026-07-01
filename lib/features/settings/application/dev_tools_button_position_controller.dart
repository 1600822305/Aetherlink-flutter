import 'package:flutter/widgets.dart' show Offset;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';

part 'dev_tools_button_position_controller.g.dart';

/// Storage key for the developer-tools floating button's dragged position,
/// mirroring the web's `localStorage['devToolsFloatingButtonPosition']`.
/// Persisted as a `'dx,dy'` string so the button keeps its spot across restarts.
const String kDevToolsButtonPositionKey = 'devToolsFloatingButtonPosition';

/// Holds the developer-tools floating button's on-screen position so it survives
/// a restart (the web persists this to `localStorage`; here it goes through the
/// Drift key/value store). `null` means "not set yet" — the button falls back to
/// its own default until a persisted value hydrates.
///
/// `keepAlive: true`: read by the app shell that mounts the floating button, so
/// it must outlive any single page — same lifecycle as [DevToolsButtonController].
@Riverpod(keepAlive: true)
class DevToolsButtonPosition extends _$DevToolsButtonPosition {
  @override
  Offset? build() {
    _hydrate();
    return null;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kDevToolsButtonPositionKey);
    final parsed = _parse(stored);
    if (parsed != null) state = parsed;
  }

  /// Persists the button's new position after a drag ends.
  void set(Offset value) {
    state = value;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kDevToolsButtonPositionKey, '${value.dx},${value.dy}');
  }

  static Offset? _parse(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final dx = double.tryParse(parts[0]);
    final dy = double.tryParse(parts[1]);
    if (dx == null || dy == null) return null;
    return Offset(dx, dy);
  }
}
