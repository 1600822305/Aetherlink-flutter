/// Application layer backing the chat sidebar's 助手 / 话题 tabs (functional port
/// of the web `TopicManagement` `AssistantTab` / `TopicTab` + their Redux slices
/// `assistantsSlice` / `groupsSlice` / `newMessagesSlice`).
///
/// Split by aggregate root (like `agent_providers.dart`):
/// - `sidebar/sidebar_selection_providers.dart` — persisted selection / tab /
///   sort-order / refresh-tick notifiers.
/// - `sidebar/assistants_providers.dart` — the [Assistants] source of truth.
/// - `sidebar/topics_providers.dart` — the [Topics] source of truth.
/// - `sidebar/groups_providers.dart` — the [Groups] source of truth.
/// - `sidebar/sidebar_view_providers.dart` — derived read views.
/// - `sidebar/topic_defaults.dart` — shared topic seed / ordering helpers.
library;

export 'package:aetherlink_flutter/features/chat/application/sidebar/assistants_providers.dart';
export 'package:aetherlink_flutter/features/chat/application/sidebar/groups_providers.dart';
export 'package:aetherlink_flutter/features/chat/application/sidebar/sidebar_selection_providers.dart';
export 'package:aetherlink_flutter/features/chat/application/sidebar/sidebar_view_providers.dart';
export 'package:aetherlink_flutter/features/chat/application/sidebar/topic_defaults.dart';
export 'package:aetherlink_flutter/features/chat/application/sidebar/topics_providers.dart';
