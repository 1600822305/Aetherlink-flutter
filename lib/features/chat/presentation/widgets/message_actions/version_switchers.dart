import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/message_action_sheets.dart';
import 'package:aetherlink_flutter/shared/domain/message_bubble_settings.dart';

import 'package:aetherlink_flutter/features/chat/presentation/widgets/message_actions/micro_bubbles.dart';

class VersionSwitcher extends ConsumerWidget {
  const VersionSwitcher({
    super.key,
    required this.view,
    required this.style,
    required this.baseColor,
    required this.pillColor,
  });

  final ChatMessageView view;
  final VersionSwitchStyle style;
  final Color baseColor;
  final Color pillColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final versions = view.versions;
    // Selectable slots: each saved version, then the 最新版本 pseudo-slot.
    final total = versions.length + 1;
    final currentIndex = view.currentVersionId == null
        ? total - 1
        : versions
              .indexWhere((v) => v.id == view.currentVersionId)
              .clamp(0, total - 1);

    final label = '${currentIndex + 1}/$total';
    final popupLabel = '版本 $label';

    if (style == VersionSwitchStyle.arrows) {
      return Material(
        color: pillColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: kPillShadowColor,
        elevation: 1,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArrowButton(
              icon: LucideIcons.chevronLeft,
              color: baseColor,
              enabled: currentIndex > 0,
              onTap: () => _switchTo(ref, currentIndex - 1),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: baseColor),
            ),
            ArrowButton(
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
        surfaceTintColor: Colors.transparent,
        shadowColor: kPillShadowColor,
        elevation: 1,
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

/// The 分支切换 control rendered at a 叉路 (a message whose parent has multiple
/// regular branch children). Shows `‹ k/n ›` arrows that flip the topic's active
/// branch ([ChatController.switchActiveBranch]); wraps around like Cherry's
/// `SiblingNavigator`. Only shown when [ChatMessageView.branchSiblingIds] has 2+.
class BranchSwitcher extends ConsumerWidget {
  const BranchSwitcher({
    super.key,
    required this.view,
    required this.baseColor,
    required this.pillColor,
  });

  final ChatMessageView view;
  final Color baseColor;
  final Color pillColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final siblings = view.branchSiblingIds;
    final total = siblings.length;
    final index = siblings.indexOf(view.id).clamp(0, total - 1);
    final label = '${index + 1}/$total';

    void switchBy(int direction) {
      final next = (index + direction + total) % total;
      ref
          .read(chatControllerProvider.notifier)
          .switchActiveBranch(siblings[next]);
    }

    return Tooltip(
      message: '切换分支',
      child: Material(
        color: pillColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: kPillShadowColor,
        elevation: 1,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArrowButton(
              icon: LucideIcons.chevronLeft,
              color: baseColor,
              enabled: true,
              onTap: () => switchBy(-1),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.gitBranch, size: 12, color: baseColor),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(color: baseColor),
                ),
              ],
            ),
            ArrowButton(
              icon: LucideIcons.chevronRight,
              color: baseColor,
              enabled: true,
              onTap: () => switchBy(1),
            ),
          ],
        ),
      ),
    );
  }
}

class ArrowButton extends StatelessWidget {
  const ArrowButton({
    super.key,
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
