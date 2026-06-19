/// App-level composition seam re-exposing the settings-owned 技能 (skills)
/// provider to the chat feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`;
/// only its `domain` is allowed. The 技能管理 page (settings) owns [Skills] (the
/// CRUD + persistence of the skill library), but the chat feature must read it
/// too — 编辑助手 lists the enabled skills to bind, and the message pipeline
/// injects bound skills' summaries into the system prompt. Chat reaches it
/// through this `app/` re-export — the composition root, which may depend on
/// any feature — instead of importing `settings/application` directly. Mirrors
/// `mcp_servers_access` (settings → chat).
library;

export 'package:aetherlink_flutter/features/settings/application/skills_controller.dart'
    show Skills, skillsProvider;
