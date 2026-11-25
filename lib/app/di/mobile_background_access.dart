import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/app_main_mode.dart';
import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar/sidebar_selection_providers.dart';

/// Resolves a background-task conversation id (`chat:<topicId>` /
/// `agent:<taskId>`, minted by the streaming registry and the agent runner)
/// into a selection plus the route to show it. Falls back to the chat home for
/// an unknown id or a topic that no longer exists.
final backgroundConversationOpenerProvider =
    Provider<Future<String> Function(String)>(
      (ref) => (conversationId) async {
        final separator = conversationId.indexOf(':');
        final kind = separator < 0
            ? ''
            : conversationId.substring(0, separator);
        final id = conversationId.substring(separator + 1);
        if (kind == 'agent' && id.isNotEmpty) {
          ref.read(selectedAgentTaskIdProvider.notifier).select(id);
          ref
              .read(appMainModeControllerProvider.notifier)
              .use(AppMainMode.agent);
          return AppRouter.agentPath;
        }
        if (kind == 'chat' && id.isNotEmpty) {
          final topic = await ref.read(appSettingsStoreProvider).getTopic(id);
          if (topic != null) {
            ref
                .read(currentAssistantIdProvider.notifier)
                .set(topic.assistantId);
            ref.read(currentTopicIdProvider.notifier).set(topic.id);
          }
        }
        ref.read(appMainModeControllerProvider.notifier).use(AppMainMode.chat);
        return AppRouter.chatPath;
      },
    );
