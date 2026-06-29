import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/di/top_toolbar_access.dart';
import 'package:aetherlink_flutter/features/settings/application/model_combo_controller.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/message_selection_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/chat_page.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_search_dialog.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/context_condense_dialog.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/mini_map_sheet.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector_dialog.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar_host.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';
import 'package:aetherlink_flutter/shared/domain/top_toolbar_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';
import 'package:aetherlink_flutter/shared/widgets/top_toolbar_component_catalog.dart';

/// Static UI strings, ported verbatim from the original (i18n is a later
/// effort, per the M4.1 approach).
const String _menuTooltip = '打开侧边栏';
const String _settingsTooltip = '设置';
const String _newTopicTooltip = '新建话题';
const String _clearTooltip = '清空内容';
const String _searchTooltip = '搜索';
const String _condenseTooltip = '压缩上下文';
const String _miniMapTooltip = '迷你地图';
const String _modelPlaceholderLabel = '未配置模型';

/// The chat top bar, driven by the appearance 顶部工具栏 DIY 设置 page's
/// [TopToolbarSettings] (read through the [appTopToolbarSettings] composition
/// seam — never `settings/application` directly, per import-boundary Rule 3).
///
/// Mirrors the original `ChatPageUI` toolbar:
/// - When `positions` is non-empty (`isDIYLayout`) the placed components are
///   rendered at their free `x%/y%` inside the toolbar (`translate(-50%,-50%)`),
///   exactly like the settings preview consumes the same config.
/// - Otherwise the original default layout shows: left = menu (drawer trigger) +
///   topic name, right = model selector + settings.
///
/// The model selector honors `modelSelectorDisplayStyle` (icon ⇒ a `Bot`
/// `IconButton`; text ⇒ the outlined model-name/provider stack of the original
/// `UnifiedModelDisplay`). Glyphs are the 1:1 catalog glyphs (lucide + the
/// non-lucide SVGs), never Material substitutes.
///
/// Wired actions: menu opens the drawer, settings pushes `/settings`, the model
/// selector opens the picker (or jumps to model settings when none exist), 新建话题
/// creates a fresh topic for the current assistant ([Topics.create]) and 清空内容
/// clears the current topic's messages ([Topics.clearMessages]) behind a
/// two-click confirm (port of the original `handleClearTopicWithConfirm`), and
/// 搜索 opens the 聊天搜索 modal (port of `ChatSearchInterface`). 压缩上下文 is a
/// full-fidelity glyph whose behavior is a later slice, so it renders disabled
/// rather than as a fake button. The selector shows the current model's name
/// once configured,
/// otherwise the "未配置模型" placeholder — never a fabricated model name.
class ChatTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const ChatTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appTopToolbarSettingsProvider);
    final topic = ref.watch(currentTopicProvider).value;
    final current = ref.watch(appCurrentModelProvider).value;
    final providers = ref.watch(appModelProvidersProvider).value ?? const [];
    final hasModels = providers.any((p) => p.models.isNotEmpty);
    final comboState = ref.watch(modelComboControllerProvider);
    final activeComboId = comboState.selectedComboId;
    final comboName = activeComboId != null
        ? comboState.combos
              .where((c) => c.id == activeComboId)
              .firstOrNull
              ?.name
        : null;

    // The original header is light and flat: `bg-paper` fill, `elevation 0` and
    // a 1px bottom divider (`baseStyles.appBar`). All colors are theme tokens.
    final isDiy = settings.positions.isNotEmpty || settings.groups.isNotEmpty;

    if (isDiy) {
      return AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: SizedBox(
          height: kToolbarHeight,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final pos in settings.positions)
                    if (_buildComponent(
                          pos.component,
                          context: context,
                          ref: ref,
                          theme: theme,
                          settings: settings,
                          topicName: topic?.name,
                          current: current,
                          hasModels: hasModels,
                          comboName: comboName,
                        )
                        case final Widget child)
                      Positioned(
                        left: pos.x / 100 * w,
                        top: pos.y / 100 * h,
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, -0.5),
                          child: child,
                        ),
                      ),
                  for (final group in settings.groups)
                    Positioned(
                      left: group.x / 100 * w,
                      top: group.y / 100 * h,
                      child: FractionalTranslation(
                        translation: const Offset(-0.5, -0.5),
                        child: _GroupButton(
                          group: group,
                          buildChild: (component) => _buildComponent(
                            component,
                            context: context,
                            ref: ref,
                            theme: theme,
                            settings: settings,
                            topicName: topic?.name,
                            current: current,
                            hasModels: hasModels,
                            comboName: comboName,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
    }

    // Default (non-DIY) layout: menu + topic name on the left, model selector +
    // settings on the right (`DEFAULT_TOP_TOOLBAR_SETTINGS`).
    final modelSelector = _buildComponent(
      TopToolbarComponent.modelSelector,
      context: context,
      ref: ref,
      theme: theme,
      settings: settings,
      topicName: topic?.name,
      current: current,
      hasModels: hasModels,
      comboName: comboName,
    );
    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: theme.dividerColor)),
      titleSpacing: 0,
      leading: _buildComponent(
        TopToolbarComponent.menuButton,
        context: context,
        ref: ref,
        theme: theme,
        settings: settings,
        topicName: topic?.name,
        current: current,
        hasModels: hasModels,
      ),
      title: topic == null
          ? const SizedBox.shrink()
          : _TopicTitle(name: topic.name),
      actions: [
        _buildComponent(
          TopToolbarComponent.miniMapButton,
          context: context,
          ref: ref,
          theme: theme,
          settings: settings,
          topicName: topic?.name,
          current: current,
          hasModels: hasModels,
        )!,
        if (modelSelector != null) modelSelector,
        _buildComponent(
          TopToolbarComponent.settingsButton,
          context: context,
          ref: ref,
          theme: theme,
          settings: settings,
          topicName: topic?.name,
          current: current,
          hasModels: hasModels,
        )!,
        const SizedBox(width: 4),
      ],
    );
  }

  Future<void> _openMiniMap(BuildContext context, WidgetRef ref) async {
    final messages =
        ref.read(chatControllerProvider).value?.messages ??
        const <ChatMessageView>[];
    if (messages.isEmpty) {
      AppToast.warning(context, '当前话题暂无消息');
      return;
    }
    final isSelecting = ref.read(messageSelectionProvider).isSelecting;
    final messageId = await showMiniMapSheet(
      context,
      messages,
      selecting: isSelecting,
      ref: ref,
    );
    if (messageId != null && !isSelecting) {
      ref.read(scrollToMessageIdProvider.notifier).scrollTo(messageId);
    }
  }

  Future<void> _openCondenseDialog(BuildContext context) async {
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

  /// Builds a single toolbar component, or `null` when it should not render
  /// (the original's `renderToolbarComponent` returns `null` for `topicName` /
  /// `clearButton` with no current topic).
  Widget? _buildComponent(
    TopToolbarComponent component, {
    required BuildContext context,
    required WidgetRef ref,
    required ThemeData theme,
    required TopToolbarSettings settings,
    required String? topicName,
    required CurrentModel? current,
    required bool hasModels,
    String? comboName,
  }) {
    switch (component) {
      case TopToolbarComponent.menuButton:
        return Builder(
          builder: (context) => _ToolbarIconButton(
            icon: topToolbarComponentIcon(
              component,
              color: theme.colorScheme.onSurface,
            ),
            tooltip: _menuTooltip,
            onPressed: () => SidebarScope.of(context).openSidebar(),
          ),
        );
      case TopToolbarComponent.topicName:
        if (topicName == null) return null;
        return _TopicTitle(name: topicName);
      case TopToolbarComponent.newTopicButton:
        final assistantId = ref.watch(currentAssistantProvider)?.id;
        final hasMessages =
            (ref.watch(chatControllerProvider).value?.messages ?? const [])
                .isNotEmpty;
        final iconColor = assistantId == null
            ? theme.disabledColor
            : theme.colorScheme.onSurface;
        return _ToolbarIconButton(
          icon: Icon(
            hasMessages
                ? LucideIcons.messageSquarePlus
                : LucideIcons.messageSquare,
            size: 20,
            color: iconColor,
          ),
          tooltip: _newTopicTooltip,
          onPressed: assistantId == null
              ? null
              : () => ref.read(topicsProvider.notifier).create(assistantId),
        );
      case TopToolbarComponent.clearButton:
        if (topicName == null) return null;
        return const _ClearTopicButton();
      case TopToolbarComponent.searchButton:
        return _ToolbarIconButton(
          icon: topToolbarComponentIcon(
            component,
            color: theme.colorScheme.onSurface,
          ),
          tooltip: _searchTooltip,
          onPressed: () => showChatSearchDialog(context),
        );
      case TopToolbarComponent.modelSelector:
        return _ModelSelector(
          style: settings.modelSelectorDisplayStyle,
          current: current,
          comboName: comboName,
          onPressed: () => hasModels
              ? showModelSelectorDialog(
                  context,
                  filter: (m) => !isNonChatModel(m),
                )
              : context.push(AppRouter.defaultModelPath),
        );
      case TopToolbarComponent.settingsButton:
        return _ToolbarIconButton(
          icon: topToolbarComponentIcon(
            component,
            color: theme.colorScheme.onSurface,
          ),
          tooltip: _settingsTooltip,
          onPressed: () => context.push(AppRouter.settingsPath),
        );
      case TopToolbarComponent.condenseButton:
        final isStreaming =
            ref.watch(chatControllerProvider).value?.isStreaming ?? false;
        return _ToolbarIconButton(
          icon: topToolbarComponentIcon(
            component,
            color: isStreaming
                ? theme.disabledColor
                : theme.colorScheme.onSurface,
          ),
          tooltip: _condenseTooltip,
          onPressed: isStreaming ? null : () => _openCondenseDialog(context),
        );
      case TopToolbarComponent.miniMapButton:
        return _ToolbarIconButton(
          icon: topToolbarComponentIcon(
            component,
            color: theme.colorScheme.onSurface,
          ),
          tooltip: _miniMapTooltip,
          onPressed: () => _openMiniMap(context, ref),
        );
    }
  }
}

/// The topic name (`Typography variant="h6" noWrap`, 18px/500), ellipsized and
/// width-capped so it stays on one line in either layout.
class _TopicTitle extends StatelessWidget {
  const _TopicTitle({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// A toolbar icon button mirroring the original's `IconButton` (a `null`
/// handler renders the glyph but does not act — its behavior is a later slice).
class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(icon: icon, tooltip: tooltip, onPressed: onPressed);
  }
}

/// A 聚合按钮: a single toolbar icon that pops up a sheet of its
/// [TopToolbarGroup.children]. Each child is built through the same
/// [_buildComponent] the toolbar uses (passed in via [buildChild]), so its
/// behavior is identical whether it sits inline on the bar or inside a group —
/// the group only changes *where* it lives, never *what it does*.
class _GroupButton extends StatelessWidget {
  const _GroupButton({required this.group, required this.buildChild});

  final TopToolbarGroup group;
  final Widget? Function(TopToolbarComponent) buildChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ToolbarIconButton(
      icon: topToolbarGroupIcon(group.icon, color: theme.colorScheme.onSurface),
      tooltip: group.label,
      onPressed: group.children.isEmpty
          ? null
          : () => _openSheet(context),
    );
  }

  Future<void> _openSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    group.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                // One function per row (a list, not equal-width tiles), so
                // long labels stay readable and the order matches the editor.
                for (final component in group.children)
                  if (buildChild(component) case final Widget child)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          child,
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              topToolbarComponentName(component),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 清空内容 button — a port of the original `handleClearTopicWithConfirm`: the
/// first tap arms a confirm state (red 警告三角 glyph) that auto-resets after 3s;
/// the second tap clears the current topic's messages ([Topics.clearMessages]).
class _ClearTopicButton extends ConsumerStatefulWidget {
  const _ClearTopicButton();

  @override
  ConsumerState<_ClearTopicButton> createState() => _ClearTopicButtonState();
}

class _ClearTopicButtonState extends ConsumerState<_ClearTopicButton> {
  static const Color _confirmColor = Color(0xFFF44336);

  bool _confirm = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _onPressed() {
    final topicId = ref.read(currentTopicProvider).value?.id;
    if (topicId == null) return;
    if (_confirm) {
      _resetTimer?.cancel();
      ref.read(topicsProvider.notifier).clearMessages(topicId);
      setState(() => _confirm = false);
    } else {
      setState(() => _confirm = true);
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _confirm = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ToolbarIconButton(
      icon: _confirm
          ? const Icon(
              LucideIcons.alertTriangle,
              size: 20,
              color: _confirmColor,
            )
          : topToolbarComponentIcon(
              TopToolbarComponent.clearButton,
              color: theme.colorScheme.onSurface,
            ),
      tooltip: _clearTooltip,
      onPressed: _onPressed,
    );
  }
}

/// The model selector, a 1:1 port of `UnifiedModelDisplay`: `icon` ⇒ a small
/// `Bot` `IconButton`; `text` ⇒ an outlined button stacking the model name
/// (`body2`/500) over the provider name (`caption`). Shows the placeholder, not
/// a fabricated name, when no model is configured.
class _ModelSelector extends StatelessWidget {
  const _ModelSelector({
    required this.style,
    required this.current,
    required this.onPressed,
    this.comboName,
  });

  final ModelSelectorDisplayStyle style;
  final CurrentModel? current;
  final VoidCallback onPressed;
  final String? comboName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modelLabel =
        comboName ?? current?.model.name ?? _modelPlaceholderLabel;

    if (style == ModelSelectorDisplayStyle.icon) {
      return _ToolbarIconButton(
        icon: topToolbarComponentIcon(
          TopToolbarComponent.modelSelector,
          color: theme.colorScheme.onSurface,
        ),
        tooltip: modelLabel,
        onPressed: onPressed,
      );
    }

    final providerName = comboName != null
        ? '模型组合'
        : (current?.provider.name ?? '');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
          side: BorderSide(color: theme.dividerColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: Size.zero,
          visualDensity: VisualDensity.compact,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                modelLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (providerName.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  providerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.4,
                    height: 1.0,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
