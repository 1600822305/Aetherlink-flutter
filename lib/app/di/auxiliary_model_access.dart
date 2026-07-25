/// App-level composition seam re-exposing the settings-owned 默认模型/提示词
/// ([AuxiliaryModelController]) store to the chat feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`;
/// only its `domain` is allowed. Chat's turn finisher (标题/建议), OCR history
/// builder, context condenser and translate controller all resolve their
/// auxiliary models and prompts from this store, so they reach it through this
/// `app/` re-export — the composition root, which may depend on any feature —
/// instead of importing `settings/application` directly.
library;

export 'package:aetherlink_flutter/features/settings/application/auxiliary_model_controller.dart';
