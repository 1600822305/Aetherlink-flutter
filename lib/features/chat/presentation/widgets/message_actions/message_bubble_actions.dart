import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_action.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_actions_builder.dart';
import 'package:aetherlink_flutter/shared/domain/message_bubble_settings.dart';

import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/micro_bubbles.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/version_switchers.dart';

/// The 功能气泡模式 presentation layer (`MessageActions` `renderMode === 'full'` +
/// `'menuOnly'`), i.e. 信息气泡管理 → 操作显示模式 = 功能气泡模式.
///
/// Two thin surfaces over the shared [MessageActionsBuilder]:
///
/// * [MessageMicroBubbles] — the small 功能气泡 shown above the bubble: the
///   版本切换 control (弹窗 / 箭头, per [VersionSwitchStyle]) and the 语音播放
///   bubble. Gated by 显示功能气泡 (`showMicroBubbles`) upstream.
/// * [MessageActionMenu] — the 右上角三点菜单 listing every other (secondary)
///   action.
///
/// Both consume the same action list as the toolbar, so the two display modes
/// can never drift apart.

/// The small 功能气泡 row rendered above a bubble in 气泡模式: 版本切换 + 语音播放.
class MessageMicroBubbles extends ConsumerStatefulWidget {
  const MessageMicroBubbles({
    required this.view,
    required this.showTtsButton,
    required this.versionSwitchStyle,
    this.baseColor,
    this.bubbleColor,
    super.key,
  });

  final ChatMessageView view;
  final bool showTtsButton;
  final VersionSwitchStyle versionSwitchStyle;
  final Color? baseColor;
  final Color? bubbleColor;

  @override
  ConsumerState<MessageMicroBubbles> createState() =>
      _MessageMicroBubblesState();
}

class _MessageMicroBubblesState extends ConsumerState<MessageMicroBubbles> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = widget.baseColor ?? theme.colorScheme.onSurface;
    final pillColor =
        widget.bubbleColor ?? theme.colorScheme.surfaceContainerHighest;

    final actions = MessageActionsBuilder(
      ref: ref,
      context: context,
      view: widget.view,
      showTtsButton: widget.showTtsButton,
      isMounted: () => mounted,
    ).build();
    final primary = actions.where((a) => a.isPrimary).toList();

    final hasVersions = widget.view.versions.isNotEmpty;
    final hasBranches = widget.view.branchSiblingIds.length > 1;
    if (primary.isEmpty && !hasVersions && !hasBranches) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (hasBranches)
          BranchSwitcher(
            view: widget.view,
            baseColor: baseColor,
            pillColor: pillColor,
          ),
        if (hasVersions)
          VersionSwitcher(
            view: widget.view,
            style: widget.versionSwitchStyle,
            baseColor: baseColor,
            pillColor: pillColor,
          ),
        for (final action in primary)
          if (action.id == MessageActionId.tts)
            TtsMicroBubble(
              messageId: widget.view.id,
              baseColor: baseColor,
              pillColor: pillColor,
              onTap: () => action.onInvoke(),
            )
          else
            MicroBubble(
              icon: action.icon,
              tooltip: action.tooltip,
              color: baseColor,
              onTap: () => action.onInvoke(),
            ),
      ],
    );
  }
}

/// The 右上角三点菜单: lists every non-primary action. 删除 confirms via dialog.
class MessageActionMenu extends ConsumerStatefulWidget {
  const MessageActionMenu({
    required this.view,
    required this.showTtsButton,
    this.baseColor,
    super.key,
  });

  final ChatMessageView view;
  final bool showTtsButton;
  final Color? baseColor;

  @override
  ConsumerState<MessageActionMenu> createState() => _MessageActionMenuState();
}

class _MessageActionMenuState extends ConsumerState<MessageActionMenu> {
  /// The original web 三点菜单 ordering (`MessageActions.tsx` 菜单), which differs
  /// from the toolbar order: 复制 · 导出 · 编辑 · (重新发送 | 重新生成 · 翻译 ·
  /// 版本历史) · 分支 · 删除. Actions absent for a given message are skipped.
  static const List<MessageActionId> _menuOrder = [
    MessageActionId.copy,
    MessageActionId.export,
    MessageActionId.edit,
    MessageActionId.resend,
    MessageActionId.regenerate,
    MessageActionId.regenerateWithModel,
    MessageActionId.translate,
    MessageActionId.versionHistory,
    MessageActionId.fork,
    MessageActionId.branch,
    MessageActionId.saveToKnowledge,
    MessageActionId.delete,
  ];

  /// Leading icons on 导出 (FileText), 从此处分叉 (GitBranch) and 另存为新话题
  /// (Save); every other menu item is text-only.
  static const Set<MessageActionId> _menuIconIds = {
    MessageActionId.export,
    MessageActionId.fork,
    MessageActionId.branch,
    MessageActionId.saveToKnowledge,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = widget.baseColor ?? theme.colorScheme.onSurface;
    final errorColor = theme.colorScheme.error;

    final actions = MessageActionsBuilder(
      ref: ref,
      context: context,
      view: widget.view,
      showTtsButton: widget.showTtsButton,
      isMounted: () => mounted,
    ).build();
    final byId = {for (final a in actions.where((a) => !a.isPrimary)) a.id: a};
    final secondary = [
      for (final id in _menuOrder)
        if (byId[id] != null) byId[id]!,
    ];

    // A compact 20×20 circular trigger (matching the original web 三点菜单 button)
    // wired to `showMenu` directly, so the visible chip can hug the bubble's
    // top-right corner rather than being centered in a 48px IconButton hit-box.
    return Tooltip(
      message: '更多操作',
      child: Material(
        color: isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        child: InkWell(
          onTap: () => _openMenu(context, secondary, errorColor),
          child: SizedBox(
            width: 20,
            height: 20,
            child: Icon(
              LucideIcons.ellipsisVertical,
              size: 14,
              color: baseColor,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMenu(
    BuildContext context,
    List<MessageAction> secondary,
    Color errorColor,
  ) async {
    final button = context.findRenderObject() as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(
          button.size.bottomLeft(Offset.zero),
          ancestor: overlay,
        ),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<MessageAction>(
      popUpAnimationStyle: AnimationStyle.noAnimation,
      context: context,
      position: position,
      items: [
        for (final action in secondary)
          PopupMenuItem<MessageAction>(
            value: action,
            child: Row(
              children: [
                if (_menuIconIds.contains(action.id)) ...[
                  Icon(action.icon, size: 16),
                  const SizedBox(width: 8),
                ],
                Text(
                  action.tooltip,
                  style: action.isDestructive
                      ? TextStyle(color: errorColor)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
    if (selected != null) await _onSelected(selected);
  }

  Future<void> _onSelected(MessageAction action) async {
    if (action.isDestructive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除消息'),
          content: const Text('确定要删除这条消息吗？此操作无法撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await action.onInvoke();
  }
}

// -- Internal widgets --------------------------------------------------------

/// A small pill-shaped 功能气泡 wrapping a single icon action.
