import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/message_selection_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_nav_providers.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_search/chat_search_dialog.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/context_condense_dialog.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/branch_manager_sheet.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/mini_map_sheet.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector/model_selector_dialog.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar_host.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';
import 'package:aetherlink_flutter/shared/domain/top_toolbar_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

Future<void> openMiniMap(BuildContext context, WidgetRef ref) async {
  final messages =
      ref.read(chatControllerProvider).value?.messages ??
      const <ChatMessageView>[];
  if (messages.isEmpty) {
    AppToast.warning(context, '当前话题暂无消息');
    return;
  }
  final isSelecting = ref.read(messageSelectionProvider).isSelecting;
  // Grab the notifier up front: when opened from a 聚合按钮 sheet the caller's
  // ref belongs to the already-popped sheet and is unusable after the await.
  final scrollNotifier = ref.read(scrollToMessageIdProvider.notifier);
  final messageId = await showMiniMapSheet(
    context,
    messages,
    selecting: isSelecting,
  );
  if (messageId != null && !isSelecting) {
    scrollNotifier.scrollTo(messageId);
  }
}

Future<void> openCondenseDialog(BuildContext context) async {
  final result = await showContextCondenseDialog(context);
  if (result != null && result.success && context.mounted) {
    AppToast.success(
      context,
      '已压缩 ${result.originalMessageCount} 条消息，'
      '节省约 ${result.tokensSaved} tokens',
      duration: const Duration(seconds: 3),
    );
  }
}

/// The action a group-sheet row dispatches for [component], run against the
/// toolbar's [context] after the sheet closes, or `null` when the component
/// has no tap behavior right now (`topicName`, a disabled 压缩上下文 while
/// streaming, 新建话题 with no assistant). `clearButton` is also `null` here: its
/// two-step confirm is stateful and lives in its hosts.
VoidCallback? componentAction(
  TopToolbarComponent component, {
  required BuildContext context,
  required WidgetRef ref,
}) {
  switch (component) {
    case TopToolbarComponent.menuButton:
      return () => SidebarScope.of(context).openSidebar();
    case TopToolbarComponent.topicName:
      return null;
    case TopToolbarComponent.newTopicButton:
      final assistantId = ref.read(currentAssistantProvider)?.id;
      if (assistantId == null) return null;
      return () => ref.read(topicsProvider.notifier).create(assistantId);
    case TopToolbarComponent.clearButton:
      return null;
    case TopToolbarComponent.searchButton:
      return () => showChatSearchDialog(context);
    case TopToolbarComponent.modelSelector:
      final providers = ref.read(appModelProvidersProvider).value ?? const [];
      final hasModels = providers.any((p) => p.models.isNotEmpty);
      return () => hasModels
          ? showModelSelectorDialog(context, filter: (m) => !isNonChatModel(m))
          : context.push(AppRouter.defaultModelPath);
    case TopToolbarComponent.settingsButton:
      return () => context.push(AppRouter.settingsPath);
    case TopToolbarComponent.condenseButton:
      final isStreaming =
          ref.read(chatControllerProvider).value?.isStreaming ?? false;
      if (isStreaming) return null;
      return () => openCondenseDialog(context);
    case TopToolbarComponent.miniMapButton:
      return () => openMiniMap(context, ref);
    case TopToolbarComponent.branchManagerButton:
      return () => showBranchManagerSheet(context);
  }
}
