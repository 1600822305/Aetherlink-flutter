import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/settings/application/behavior_settings_controller.dart';
import 'package:aetherlink_flutter/shared/domain/behavior_settings.dart';

part 'behavior_settings_access.g.dart';

/// App-level composition seam exposing the 行为 settings ([BehaviorSettings]) to
/// the `chat` feature and the app root.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`,
/// so the chat composer cannot read [BehaviorSettingsController] (which lives in
/// `settings/application`) directly. It instead reads this provider in `app/`
/// (the composition root, which may depend on any feature) plus the pure-Dart
/// `shared/domain` [BehaviorSettings] type.
///
/// Reactively re-exposes the controller's state, so toggling Enter 发送 or a
/// 触觉反馈 option in 行为 settings takes effect immediately.
@Riverpod(keepAlive: true)
BehaviorSettings appBehaviorSettings(Ref ref) =>
    ref.watch(behaviorSettingsControllerProvider);
