import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/tts_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_action.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_action_button.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_actions_builder.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/token_display.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_playback_state.dart';

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

    final buttonGroup = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _buildButton(action, baseColor, errorColor),
          ),
      ],
    );

    // Token usage chip: pushed flush against the far edge of the toolbar — the
    // right for AI replies, the left for user messages — with the button group
    // hugging the opposite edge (matching `MessageActions`' toolbar layout). The
    // row fills the bubble width ([BubbleFooterLayout] stretches the footer), so
    // a [Spacer] separates the two groups.
    final tokenDisplay = TokenDisplay(view: widget.view, baseColor: baseColor);

    return Row(
      children: isUser
          ? [tokenDisplay, const Spacer(), buttonGroup]
          : [buttonGroup, const Spacer(), tokenDisplay],
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
