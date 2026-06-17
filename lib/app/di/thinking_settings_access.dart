import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/settings/application/thinking_settings_controller.dart';
import 'package:aetherlink_flutter/shared/domain/thinking_settings.dart';

part 'thinking_settings_access.g.dart';

/// App-level composition seam exposing the 思考过程设置 ([ThinkingSettings]) to the
/// `chat` feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`,
/// so the chat thinking block cannot read [ThinkingSettingsController] (which
/// lives in `settings/application`) directly. It instead watches this provider
/// in `app/` (the composition root, which may depend on any feature) plus the
/// pure-Dart `shared/domain` [ThinkingSettings] type.
///
/// Reactively re-exposes the controller's state, so changing the display style
/// or auto-collapse in 外观设置 → 思考过程设置 re-renders the thinking block live.
@Riverpod(keepAlive: true)
ThinkingSettings thinkingSettings(Ref ref) =>
    ref.watch(thinkingSettingsControllerProvider);
