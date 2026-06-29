import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/message_bubble_access.dart';
import 'package:aetherlink_flutter/app/theme/app_theme_extension.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/message_block_renderer.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/bubble_footer_layout.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_bubble_actions.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_toolbar.dart';
import 'package:aetherlink_flutter/features/chat/application/user_avatar_controller.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/user_avatar_widget.dart';
import 'package:aetherlink_flutter/shared/domain/message_bubble_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/color_picker.dart';

/// A single chat message rendered as a bubble.
///
/// Renders the message view ([ChatMessageView]) owned by the [ChatController]:
/// an optional 头像 + 名称 + 时间 header above the ordered blocks, which are
/// dispatched to per-type widgets by [MessageBlockRenderer] (Markdown answer,
/// thinking trace, code, image, error, …) and updated live as a reply streams
/// in.
///
/// The bubble's geometry and chrome follow 外观设置 → 信息气泡管理
/// ([MessageBubbleSettings], read through [messageBubbleSettingsProvider]),
/// mirroring the original `BubbleStyleMessage`: per-role max/min widths, the
/// avatar/name/time header toggles, the 隐藏气泡 (transparent, no radius) modes
/// and the 自定义气泡颜色 overrides. When no custom color is set the fill comes
/// from [AppThemeExtension] (`bubbleUser` / `bubbleAi`) and the text from
/// `colorScheme.onSurface`.
class ChatMessageBubble extends ConsumerWidget {
  const ChatMessageBubble({required this.messageId, super.key});

  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Subscribe to *this* message only: a freezed value type + `select` means an
    // in-place content update (streaming) rebuilds just the affected bubble, and
    // an unrelated message changing leaves this one untouched.
    final view = ref.watch(
      chatControllerProvider.select((a) => a.messageById(messageId)),
    );
    if (view == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    final settings = ref.watch(messageBubbleSettingsProvider);
    final colors = settings.customBubbleColors;
    final isUser = view.role == MessageRole.user;

    final hideBubble = isUser ? settings.hideUserBubble : settings.hideAIBubble;
    final bubbleColor = isUser
        ? (colorFromHex(colors.userBubbleColor) ??
              ext?.bubbleUser ??
              theme.colorScheme.surface)
        : (colorFromHex(colors.aiBubbleColor) ??
              ext?.bubbleAi ??
              theme.colorScheme.surface);
    final customTextColor = isUser
        ? colorFromHex(colors.userTextColor)
        : colorFromHex(colors.aiTextColor);
    final textColor = customTextColor ?? theme.colorScheme.onSurface;
    final radius = ext?.borderRadius ?? 8.0;

    final maxWidthFactor =
        (isUser
            ? settings.userMessageMaxWidth
            : settings.messageBubbleMaxWidth) /
        100;
    final minWidthFactor = settings.messageBubbleMinWidth / 100;

    final hasError = view.status == MessageStatus.error;
    final isStreaming =
        view.status == MessageStatus.streaming ||
        view.status == MessageStatus.processing;

    // A message with no blocks, that is neither streaming nor errored, renders
    // nothing rather than a fabricated empty bubble. While streaming the
    // renderer shows the 「正在生成回复...」 placeholder.
    if (view.blocks.isEmpty && !isStreaming && !hasError) {
      return const SizedBox.shrink();
    }

    final showAvatar = isUser
        ? settings.showUserAvatar
        : settings.showModelAvatar;
    final showName = isUser ? settings.showUserName : settings.showModelName;
    // Only user bubbles render the avatar from this provider, so AI bubbles must
    // not subscribe to it (an avatar change would otherwise rebuild every AI
    // bubble too).
    final userAvatar = isUser ? ref.watch(userAvatarControllerProvider) : null;
    final header = (showAvatar || showName)
        ? _MessageHeader(
            isUser: isUser,
            showAvatar: showAvatar,
            showName: showName,
            name: isUser ? '用户' : _modelLabel(view),
            time: _formatTime(view.createdAt),
            userAvatarWidget: (isUser && userAvatar != null)
                ? UserAvatarWidget(avatar: userAvatar, size: 24)
                : null,
          )
        : null;

    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final isSummaryMessage = view.blocks.any((b) => b is ContextSummaryBlock);
    final showActions =
        !isStreaming && view.blocks.isNotEmpty && !isSummaryMessage;
    final showToolbar =
        showActions && settings.messageActionMode == MessageActionMode.toolbar;
    // 功能气泡模式: small 功能气泡 above the bubble + a 三点菜单 alongside them.
    final showBubbleActions =
        showActions && settings.messageActionMode == MessageActionMode.bubbles;

    // Check whether this message was truncated and should show a "继续生成"
    // button. Only the last assistant message is eligible.
    final controller = ref.watch(chatControllerProvider.notifier);
    final isTruncated =
        !isUser && !isStreaming && controller.truncatedMessageId == view.id;

    final blockContent =
        (view.blocks.isEmpty && hasError && view.errorText != null)
        ? Text(
            view.errorText!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        : MessageBlockRenderer(
            blocks: view.blocks,
            messageStatus: view.status,
            role: view.role,
            textColor: textColor,
          );

    final content = isTruncated
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              blockContent,
              const SizedBox(height: 8),
              _ContinueGeneratingButton(messageId: view.id),
            ],
          )
        : blockContent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (header != null) ...[header, const SizedBox(height: 4)],
          // 功能气泡模式: 小功能气泡 float above the bubble (inner-side aligned)
          // and the 三点菜单 sits inside the bubble's top-right corner — mirroring
          // the original web `BubbleStyleMessage`'s absolutely-positioned chrome.
          // Reserve headroom so the floating micro-bubbles don't overlap the
          // previous message / header.
          if (showBubbleActions && settings.showMicroBubbles)
            const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth * maxWidthFactor;
              final minWidth = (constraints.maxWidth * minWidthFactor).clamp(
                0.0,
                maxWidth,
              );
              return Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 宽度约束加在气泡本体上（而不是外层 Stack）：否则 最小宽度 会把
                    // Stack 整体撑宽，而 Stack 默认 topStart 对齐会把气泡推到内侧边缘，
                    // 导致用户气泡贴不到右边。约束气泡本身后，Stack 收缩到气泡尺寸，
                    // 再由外层 Align 把它钉到 右/左 侧，和原版 web 的
                    // `minWidth:50% + alignSelf:flex-end` 行为一致。
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth,
                        minWidth: minWidth,
                      ),
                      child: Container(
                        // Extra right padding in 气泡模式 leaves room for the
                        // 三点菜单 anchored in the top-right corner.
                        padding: EdgeInsets.only(
                          left: 12,
                          right: showBubbleActions ? 30 : 12,
                          top: 10,
                          bottom: 10,
                        ),
                        decoration: BoxDecoration(
                          color: hideBubble ? Colors.transparent : bubbleColor,
                          borderRadius: BorderRadius.circular(
                            hideBubble ? 0 : radius,
                          ),
                        ),
                        child: showToolbar
                            ? BubbleFooterLayout(
                                content: content,
                                // The bubble-internal bottom toolbar, separated
                                // from the content by a 1px divider and stretched
                                // to the full bubble width so the token chip sits
                                // flush against the far edge, mirroring
                                // `BubbleStyleMessage`'s toolbar mode.
                                footer: Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.only(top: 8),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color:
                                            (theme.brightness == Brightness.dark
                                                    ? Colors.white
                                                    : Colors.black)
                                                .withValues(alpha: 0.1),
                                      ),
                                    ),
                                  ),
                                  child: MessageToolbar(
                                    view: view,
                                    showTtsButton: settings.showTTSButton,
                                    customTextColor: customTextColor,
                                  ),
                                ),
                              )
                            : content,
                      ),
                    ),
                    // 小功能气泡: floating above the bubble, aligned to its inner
                    // side (用户消息→左上, AI消息→右上), like the original web.
                    if (showBubbleActions && settings.showMicroBubbles)
                      Positioned(
                        top: -26,
                        left: isUser ? 0 : null,
                        right: isUser ? null : 0,
                        child: MessageMicroBubbles(
                          view: view,
                          showTtsButton: settings.showTTSButton,
                          versionSwitchStyle: settings.versionSwitchStyle,
                          baseColor: customTextColor,
                          bubbleColor: bubbleColor,
                        ),
                      ),
                    // 三点菜单: inside the bubble's top-right corner.
                    if (showBubbleActions)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: MessageActionMenu(
                          view: view,
                          showTtsButton: settings.showTTSButton,
                          baseColor: customTextColor,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// The assistant name line: `模型名 | 供应商`, mirroring the original
  /// `${model.name} | ${getProviderName(model.provider)}`. Falls back to a
  /// generic label when no model metadata is attached.
  String _modelLabel(ChatMessageView view) {
    final name = view.modelName;
    final provider = view.providerName;
    if (name == null || name.isEmpty) return 'AI助手';
    if (provider == null || provider.isEmpty) return name;
    return '$name | $provider';
  }

  static String _formatTime(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// The avatar + 名称/时间 header above a bubble. Aligned to the right for the
/// user (row-reverse) and the left for the assistant, mirroring the original
/// `BubbleStyleMessage` header.
class _MessageHeader extends StatelessWidget {
  const _MessageHeader({
    required this.isUser,
    required this.showAvatar,
    required this.showName,
    required this.name,
    required this.time,
    this.userAvatarWidget,
  });

  final bool isUser;
  final bool showAvatar;
  final bool showName;
  final String name;
  final String time;
  final Widget? userAvatarWidget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final avatar = (isUser && userAvatarWidget != null)
        ? userAvatarWidget!
        : Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isUser
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isUser ? 'U' : 'AI',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: isUser ? TextDirection.rtl : TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAvatar) ...[avatar, const SizedBox(width: 8)],
        Column(
          crossAxisAlignment: align,
          children: [
            if (showName)
              Text(
                name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (time.isNotEmpty)
              Text(
                time,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A tappable chip shown below a truncated AI reply.
///
/// Mirrors ChatGPT / LibreChat's "Continue generating" UX: when the model's
/// response was cut short by the token limit (`finishReason == 'length'`) and
/// automatic continuation was exhausted, this button lets the user manually
/// trigger another continuation round.
class _ContinueGeneratingButton extends ConsumerWidget {
  const _ContinueGeneratingButton({required this.messageId});

  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            ref
                .read(chatControllerProvider.notifier)
                .continueGenerating(messageId);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.chevronDown,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '继续生成',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
