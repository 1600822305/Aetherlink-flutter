/// App-level composition seam re-exposing the settings-owned 模型组合
/// ([ModelComboController] + combo 虚拟 provider 视图) to the chat feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`;
/// only its `domain` is allowed. The chat controller / multi-model send /
/// model selector need the active combo, its resolution and the combo-aware
/// provider list, so they reach them through this `app/` re-export — the
/// composition root, which may depend on any feature — instead of importing
/// `settings/application` directly.
library;

export 'package:aetherlink_flutter/features/settings/application/model_combo_controller.dart';
export 'package:aetherlink_flutter/features/settings/application/model_combo_providers.dart';
