/// App-level composition seam re-exposing the chat-owned 助手 (assistants)
/// provider to the settings feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`;
/// only its `domain` is allowed. The chat feature owns [Assistants] (the
/// assistant list + CRUD, including [Assistants.toggleSkill] which stores a
/// skill id on `assistant.skillIds`). The 技能管理 page (settings) needs it for
/// the 绑定助手 dialog — listing assistants and toggling a skill's binding. It
/// reaches the provider through this `app/` re-export — the composition root,
/// which may depend on any feature — instead of importing `chat/application`
/// directly.
library;

export 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart'
    show Assistants, assistantsProvider;
