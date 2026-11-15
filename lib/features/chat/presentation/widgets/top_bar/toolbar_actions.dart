import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aetherlink_flutter/app/di/media_model_access.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/di/model_combo_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/input_modes_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/message_selection_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_nav_providers.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_search/chat_search_dialog.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/dialogs/context_condense_dialog.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sheets/branch_manager_sheet.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sheets/mini_map_sheet.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector/model_selector_dialog.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar_host.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
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

/// 聊天模型选择器的统一入口（顶部栏与 DIY 工具栏共用）：生图/生视频模型
/// 不写 `isDefault`，而是写入对应媒体槽位并进入直达模式；选中聊天模型
/// （含 combo）恢复默认语义，并顺带退出媒体直达模式。
void selectChatSelectorModel(
  BuildContext context,
  WidgetRef ref,
  ModelProvider provider,
  Model model,
) {
  final inputMode = ref.read(inputModeControllerProvider.notifier);
  if (isGenerateImageModel(model)) {
    ref
        .read(mediaModelControllerProvider.notifier)
        .setImageModel(provider.id, model.id);
    inputMode.set(InputMode.image);
    AppToast.info(context, '已进入图像生成模式 · ${model.name}');
    return;
  }
  if (isGenerateVideoModel(model)) {
    ref
        .read(mediaModelControllerProvider.notifier)
        .setVideoModel(provider.id, model.id);
    inputMode.set(InputMode.video);
    AppToast.info(context, '已进入视频生成模式 · ${model.name}');
    return;
  }
  // 只退出媒体直达模式；webSearch 也是 InputMode，选聊天模型不应清掉它。
  final armedMode = ref.read(inputModeControllerProvider);
  if (armedMode == InputMode.image || armedMode == InputMode.video) {
    inputMode.clear();
  }
  if (provider.id == kModelComboProviderId) {
    ref.read(modelComboControllerProvider.notifier).selectCombo(model.id);
    return;
  }
  ref.read(modelComboControllerProvider.notifier).clearComboSelection();
  ref
      .read(modelStoreProvider.notifier)
      .selectCurrentModel(providerId: provider.id, modelId: model.id);
}

/// 聊天模型选择器的过滤：聊天模型 + 生图/生视频模型（媒体模型选中后走
/// [selectChatSelectorModel] 的槽位分支）。其余上下文（翻译、重试、
/// 多模型发送）仍用 `!isNonChatModel`。
bool chatSelectorModelFilter(Model model) =>
    !isNonChatModel(model) ||
    isGenerateImageModel(model) ||
    isGenerateVideoModel(model);

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
          ? showModelSelectorDialog(
              context,
              filter: chatSelectorModelFilter,
              onSelect: (provider, model) =>
                  selectChatSelectorModel(context, ref, provider, model),
            )
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
