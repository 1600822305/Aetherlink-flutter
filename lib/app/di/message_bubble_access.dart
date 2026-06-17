import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/settings/application/message_bubble_settings_controller.dart';
import 'package:aetherlink_flutter/shared/domain/message_bubble_settings.dart';

part 'message_bubble_access.g.dart';

/// App-level composition seam exposing the 信息气泡管理 ([MessageBubbleSettings])
/// to the `chat` feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`,
/// so the chat view cannot read [MessageBubbleSettingsController] (which lives
/// in `settings/application`) directly. It instead watches this provider in
/// `app/` (the composition root, which may depend on any feature) plus the
/// pure-Dart `shared/domain` [MessageBubbleSettings] type.
///
/// Reactively re-exposes the controller's state, so changing bubble widths,
/// hide-bubble or custom colors in 外观设置 → 信息气泡管理 re-renders the chat
/// bubbles live.
@Riverpod(keepAlive: true)
MessageBubbleSettings messageBubbleSettings(Ref ref) =>
    ref.watch(messageBubbleSettingsControllerProvider);
