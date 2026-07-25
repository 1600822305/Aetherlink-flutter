/// App-level composition seam re-exposing the settings-owned 选择菜单设置
/// ([SelectionMenuSettingsController]) to the chat feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`;
/// only its `domain` is allowed. The chat 划词选择菜单 reads the enabled
/// actions from this store, so it reaches it through this `app/` re-export —
/// the composition root, which may depend on any feature — instead of
/// importing `settings/application` directly.
library;

export 'package:aetherlink_flutter/features/settings/application/selection_menu_settings_controller.dart';
