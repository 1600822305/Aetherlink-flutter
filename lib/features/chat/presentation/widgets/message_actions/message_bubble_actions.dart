import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/tts_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_action.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_actions_builder.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_action_sheets.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_playback_state.dart';
import 'package:aetherlink_flutter/shared/domain/message_bubble_settings.dart';

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
    super.key,
  });

  final ChatMessageView view;
  final bool showTtsButton;
  final VersionSwitchStyle versionSwitchStyle;
  final Color? baseColor;

  @override
  ConsumerState<MessageMicroBubbles> createState() =>
      _MessageMicroBubblesState();
}

class _MessageMicroBubblesState extends ConsumerState<MessageMicroBubbles> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = widget.baseColor ?? theme.colorScheme.onSurface;

    final actions = MessageActionsBuilder(
      ref: ref,
      context: context,
      view: widget.view,
      showTtsButton: widget.showTtsButton,
      isMounted: () => mounted,
    ).build();
    final primary = actions.where((a) => a.isPrimary).toList();

    final hasVersions = widget.view.versions.isNotEmpty;
    if (primary.isEmpty && !hasVersions) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (hasVersions)
          _VersionSwitcher(
            view: widget.view,
            style: widget.versionSwitchStyle,
            baseColor: baseColor,
          ),
        for (final action in primary)
          if (action.id == MessageActionId.tts)
            _TtsMicroBubble(
              messageId: widget.view.id,
              baseColor: baseColor,
              onTap: () => action.onInvoke(),
            )
          else
            _MicroBubble(
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
    MessageActionId.translate,
    MessageActionId.versionHistory,
    MessageActionId.branch,
    MessageActionId.delete,
  ];

  /// Original web shows leading icons only on 导出 (FileText) and 分支
  /// (GitBranch); every other menu item is text-only.
  static const Set<MessageActionId> _menuIconIds = {
    MessageActionId.export,
    MessageActionId.branch,
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
        button.localToGlobal(button.size.bottomLeft(Offset.zero),
            ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<MessageAction>(
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
class _MicroBubble extends StatelessWidget {
  const _MicroBubble({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.6,
        ),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      ),
    );
  }
}

/// The 语音播放 micro-bubble: swaps icon/color with live playback state.
class _TtsMicroBubble extends ConsumerWidget {
  const _TtsMicroBubble({
    required this.messageId,
    required this.baseColor,
    required this.onTap,
  });

  final String messageId;
  final Color baseColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TtsPlaybackState? ttsState;
    try {
      ttsState = ref.watch(ttsPlaybackProvider);
    } catch (_) {
      // Provider not ready — show default icon.
    }
    final isPlayingThis = ttsState != null &&
        ttsState.messageId == messageId &&
        (ttsState.status == TtsStatus.playing ||
            ttsState.status == TtsStatus.loading);
    // Original web 播放 chip: idle shows the muted icon + 「播放」, while playing
    // shows the speaker icon + 「播放中」, tinted with the primary color.
    return _LabeledBubble(
      icon: isPlayingThis ? LucideIcons.volume2 : LucideIcons.volumeX,
      label: isPlayingThis ? '播放中' : '播放',
      tooltip: isPlayingThis ? '停止播放' : '语音播放',
      color: isPlayingThis ? Theme.of(context).colorScheme.primary : baseColor,
      onTap: onTap,
    );
  }
}

/// A small pill-shaped 功能气泡 carrying an icon **and** a text label, mirroring
/// the original web Chip (e.g. the 播放/播放中 chip).
class _LabeledBubble extends StatelessWidget {
  const _LabeledBubble({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.6,
        ),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 版本切换 control. In [VersionSwitchStyle.popup] it shows a pill with the
/// current index that opens the 版本历史 sheet; in [VersionSwitchStyle.arrows] it
/// shows `‹ n/total ›` arrows that step between versions (the final slot is the
/// 最新版本, like the history sheet).
class _VersionSwitcher extends ConsumerWidget {
  const _VersionSwitcher({
    required this.view,
    required this.style,
    required this.baseColor,
  });

  final ChatMessageView view;
  final VersionSwitchStyle style;
  final Color baseColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final versions = view.versions;
    // Selectable slots: each saved version, then the 最新版本 pseudo-slot.
    final total = versions.length + 1;
    final currentIndex = view.currentVersionId == null
        ? total - 1
        : versions.indexWhere((v) => v.id == view.currentVersionId).clamp(
            0,
            total - 1,
          );

    final label = '${currentIndex + 1}/$total';
    final popupLabel = '版本 $label';
    final pillColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.6,
    );

    if (style == VersionSwitchStyle.arrows) {
      return Material(
        color: pillColor,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ArrowButton(
              icon: LucideIcons.chevronLeft,
              color: baseColor,
              enabled: currentIndex > 0,
              onTap: () => _switchTo(ref, currentIndex - 1),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: baseColor),
            ),
            _ArrowButton(
              icon: LucideIcons.chevronRight,
              color: baseColor,
              enabled: currentIndex < total - 1,
              onTap: () => _switchTo(ref, currentIndex + 1),
            ),
          ],
        ),
      );
    }

    // popup style: a pill that opens the full 版本历史 sheet.
    return Tooltip(
      message: '版本历史',
      child: Material(
        color: pillColor,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openHistory(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.history, size: 14, color: baseColor),
                const SizedBox(width: 4),
                Text(
                  popupLabel,
                  style: theme.textTheme.labelSmall?.copyWith(color: baseColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _switchTo(WidgetRef ref, int index) {
    final versions = view.versions;
    final notifier = ref.read(chatControllerProvider.notifier);
    if (index >= versions.length) {
      notifier.switchToLatest(view.id);
    } else {
      notifier.switchToVersion(view.id, versions[index].id);
    }
  }

  Future<void> _openHistory(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MessageVersionHistorySheet(messageId: view.id),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: enabled ? onTap : null,
      radius: 16,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Icon(
          icon,
          size: 14,
          color: enabled ? color : color.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
