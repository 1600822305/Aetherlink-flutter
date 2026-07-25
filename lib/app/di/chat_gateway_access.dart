/// App-level composition seam re-exposing chat-owned DI ports (the
/// [ChatRepository] key/value store and the [LlmGatewayFactory]) to other
/// features.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`;
/// only its `domain` is allowed. Settings' 默认模型 controller persists via the
/// chat key/value store and the 技能商店 detail sheet streams a translation
/// through the LLM gateway, so they reach these providers through this `app/`
/// re-export — the composition root, which may depend on any feature — instead
/// of importing `chat/application` directly.
library;

export 'package:aetherlink_flutter/features/chat/application/chat_providers.dart'
    show chatRepositoryProvider, llmGatewayFactoryProvider;
