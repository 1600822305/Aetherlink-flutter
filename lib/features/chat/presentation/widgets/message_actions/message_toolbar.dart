import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/tts_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_action.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_action_button.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_actions_builder.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/token_display.dart';
import 'package:aetherlink_flutter/features/settings/application/message_bubble_settings_controller.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_playback_state.dart';
import 'package:aetherlink_flutter/shared/domain/message_bubble_settings.dart';

/// The message bubble bottom toolbar (`MessageActions` `renderMode === 'toolbar'`),
/// i.e. 信息气泡管理 → 操作显示模式 = 底部工具栏模式.
///
/// A thin presentation layer over [MessageActionsBuilder]: it renders every
/// action the builder produces inline as a row of [MessageActionButton]s, with
/// the [TokenDisplay] chip pushed to the far edge (right for AI, left for user),
/// reproducing the original toolbar exactly. All behaviour lives in the builder;
/// only the 删除 two-tap confirmation and the 语音播放 playing highlight (local
/// view state) are resolved here.
class MessageToolbar extends ConsumerStatefulWidget {
  const MessageToolbar({
    required this.view,
    required this.showTtsButton,
    this.customTextColor,
    super.key,
  });

  final ChatMessageView view;

  /// Mirrors 信息气泡管理 → 显示播放按钮 (`showTTSButton`); when off the 语音播放
  /// button is hidden, like the original `enableTTS && showTTSButton` gate.
  final bool showTtsButton;

  /// The bubble's custom text color when 自定义气泡颜色 is set, else null. Tints
  /// the toolbar icons to match, mirroring the original `customTextColor` prop.
  final Color? customTextColor;

  @override
  ConsumerState<MessageToolbar> createState() => _MessageToolbarState();
}

class _MessageToolbarState extends ConsumerState<MessageToolbar> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = widget.customTextColor ?? theme.colorScheme.onSurface;
    final errorColor = theme.colorScheme.error;
    final isUser = widget.view.role == MessageRole.user;

    final actions = MessageActionsBuilder(
      ref: ref,
      context: context,
      view: widget.view,
      showTtsButton: widget.showTtsButton,
      isMounted: () => mounted,
    ).build();

    // 收纳：信息气泡管理 → 工具栏按钮收纳里勾选的操作不内联渲染，而是收进
    // 末尾的「更多」上拉菜单；未自定义时用预设。
    final collapsedIds = ref.watch(
      messageBubbleSettingsControllerProvider.select(
        (s) => s.collapsedActionIds ?? kDefaultCollapsedActionIds,
      ),
    );
    final inline = [
      for (final a in actions)
        if (!collapsedIds.contains(a.id.name)) a,
    ];
    final collapsed = [
      for (final a in actions)
        if (collapsedIds.contains(a.id.name)) a,
    ];

    final buttonGroup = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in inline)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _buildButton(action, baseColor, errorColor),
          ),
        if (collapsed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: MessageActionButton(
              icon: LucideIcons.ellipsis,
              tooltip: '更多',
              color: baseColor,
              onTap: () => _showMoreSheet(collapsed),
            ),
          ),
      ],
    );

    // Token usage chip: pushed flush against the far edge of the toolbar — the
    // right for AI replies, the left for user messages — with the button group
    // hugging the opposite edge (matching `MessageActions`' toolbar layout). The
    // row fills the bubble width ([BubbleFooterLayout] stretches the footer), so
    // a [Spacer] separates the two groups. Hidden when 显示Token用量 is off.
    final showTokenUsage = ref.watch(
      sidebarSettingsControllerProvider.select((s) => s.showMessageTokenUsage),
    );
    final Widget tokenDisplay = showTokenUsage
        ? TokenDisplay(view: widget.view, baseColor: baseColor)
        : const SizedBox.shrink();

    return Row(
      children: isUser
          ? [tokenDisplay, const Spacer(), buttonGroup]
          : [buttonGroup, const Spacer(), tokenDisplay],
    );
  }

  /// The 「更多」上拉菜单 listing the collapsed actions. 删除 keeps its two-tap
  /// confirmation inside the sheet (first tap arms, second confirms).
  Future<void> _showMoreSheet(List<MessageAction> collapsed) async {
    final theme = Theme.of(context);
    MessageActionId? armedDelete;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              for (final action in collapsed)
                ListTile(
                  dense: true,
                  leading: Icon(
                    action.icon,
                    size: 20,
                    color: action.isDestructive
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface,
                  ),
                  title: Text(
                    action.isDestructive && armedDelete == action.id
                        ? '再次点击确认删除'
                        : action.tooltip,
                    style: TextStyle(
                      color: action.isDestructive
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  onTap: () {
                    if (action.isDestructive && armedDelete != action.id) {
                      setSheetState(() => armedDelete = action.id);
                      return;
                    }
                    Navigator.of(sheetContext).pop();
                    action.onInvoke();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    MessageAction action,
    Color baseColor,
    Color errorColor,
  ) {
    // 语音播放 swaps its icon/tooltip/color with live playback state.
    if (action.id == MessageActionId.tts) {
      return Consumer(
        builder: (context, ref, _) {
          TtsPlaybackState? ttsState;
          try {
            ttsState = ref.watch(ttsPlaybackProvider);
          } catch (_) {
            // Provider not ready — show default icon.
          }
          final isPlayingThis = ttsState != null &&
              ttsState.messageId == widget.view.id &&
              (ttsState.status == TtsStatus.playing ||
                  ttsState.status == TtsStatus.loading);
          return MessageActionButton(
            icon: isPlayingThis ? LucideIcons.volumeOff : LucideIcons.volume2,
            tooltip: isPlayingThis ? '停止播放' : '语音播放',
            color: isPlayingThis
                ? Theme.of(context).colorScheme.primary
                : baseColor,
            onTap: () => action.onInvoke(),
          );
        },
      );
    }

    return MessageActionButton(
      icon: action.icon,
      tooltip: action.tooltip,
      color: baseColor,
      onTap: () => action.onInvoke(),
      confirmTwice: action.isDestructive,
      confirmColor: action.isDestructive ? errorColor : null,
      confirmTooltip: action.isDestructive ? '再次点击确认删除' : null,
    );
  }
}
