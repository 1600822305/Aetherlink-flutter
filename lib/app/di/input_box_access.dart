import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/settings/application/input_box_settings_controller.dart';
import 'package:aetherlink_flutter/shared/domain/input_box_settings.dart';

part 'input_box_access.g.dart';

/// App-level composition seam for cross-feature reads of the input-box config.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`;
/// only its `domain` is allowed. The `settings` feature owns
/// [InputBoxSettingsController], but `chat`'s composer must follow the same
/// config, so the read provider is re-exposed here in `app/` (the composition
/// root, which may depend on any feature). The chat layer watches this plus the
/// pure-Dart [InputBoxSettings] domain type — never `settings/application`
/// directly.
@Riverpod(keepAlive: true)
InputBoxSettings appInputBoxSettings(Ref ref) =>
    ref.watch(inputBoxSettingsControllerProvider);
