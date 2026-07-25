/// App-level composition seam re-exposing the chat-owned 网络搜索设置
/// ([WebSearchSettingsController]) to the settings feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`;
/// only its `domain` is allowed. The 网络搜索 settings pages read/write this
/// chat-owned store, so they reach it through this `app/` re-export — the
/// composition root, which may depend on any feature — instead of importing
/// `chat/application` directly.
library;

export 'package:aetherlink_flutter/features/chat/application/web_search_settings_controller.dart';
