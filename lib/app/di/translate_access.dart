/// App-level composition seam re-exposing the chat-owned 翻译模型 provider to
/// the settings feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`;
/// only its `domain` is allowed. The 技能商店 detail sheet resolves the
/// configured translate model through this `app/` re-export — the composition
/// root, which may depend on any feature — instead of importing
/// `chat/application` directly.
library;

export 'package:aetherlink_flutter/features/chat/application/translate/translate_controller.dart'
    show translateModelProvider;
