import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/settings/application/chat_interface_settings_controller.dart';
import 'package:aetherlink_flutter/shared/domain/chat_interface_settings.dart';

part 'chat_interface_access.g.dart';

/// App-level composition seam exposing the 聊天界面设置 ([ChatInterfaceSettings])
/// to the `chat` feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`,
/// so the chat view cannot read [ChatInterfaceSettingsController] (which lives
/// in `settings/application`) directly. It instead watches this provider in
/// `app/` (the composition root, which may depend on any feature) plus the
/// pure-Dart `shared/domain` [ChatInterfaceSettings] type.
///
/// Reactively re-exposes the controller's state, so toggling 系统提示词气泡 in
/// 外观设置 → 聊天界面设置 shows/hides the bubble on the chat page live.
@Riverpod(keepAlive: true)
ChatInterfaceSettings chatInterfaceSettings(Ref ref) =>
    ref.watch(chatInterfaceSettingsControllerProvider);
