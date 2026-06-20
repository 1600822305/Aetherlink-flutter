// Shared sidebar menus: group header, overflow menu and bottom action sheet.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/dialogs/sidebar_dialogs.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/sidebar_tokens.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/sidebar_buttons.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';

/// A folder header for an assistant/topic group: expand toggle + name + count
/// + a rename/delete overflow menu.
class SidebarGroupHeader extends ConsumerWidget {
  const SidebarGroupHeader({
    super.key,
    required this.group,
    required this.count,
    required this.textPrimary,
    required this.textSecondary,
  });

  final Group group;
  final int count;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(groupsProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => notifier.toggleExpanded(group.id),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(
                  group.expanded
                      ? LucideIcons.chevronDown
                      : LucideIcons.chevronRight,
                  size: 16,
                  color: textSecondary,
                ),
                const SizedBox(width: 6),
                Icon(LucideIcons.folder, size: 16, color: textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.43,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.66,
                    color: textSecondary,
                  ),
                ),
                SidebarOverflowMenuButton<_GroupMenu>(
                  size: 16,
                  box: 26,
                  title: group.name,
                  actions: const [
                    SidebarSheetAction(
                      _GroupMenu.rename,
                      LucideIcons.edit3,
                      '重命名分组',
                    ),
                    SidebarSheetAction(
                      _GroupMenu.delete,
                      LucideIcons.trash,
                      '删除分组',
                      danger: true,
                    ),
                  ],
                  onSelected: (m) async {
                    switch (m) {
                      case _GroupMenu.rename:
                        final name = await promptText(
                          context,
                          title: '重命名分组',
                          hint: '分组名称',
                          initial: group.name,
                        );
                        if (name != null) await notifier.rename(group.id, name);
                      case _GroupMenu.delete:
                        await notifier.deleteGroup(group.id);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _GroupMenu { rename, delete }

/// One row in the per-item action sheet opened by [SidebarOverflowMenuButton].
class SidebarSheetAction<T> {
  const SidebarSheetAction(
    this.value,
    this.icon,
    this.label, {
    this.danger = false,
  });

  final T value;
  final IconData icon;
  final String label;
  final bool danger;
}

/// The per-row 更多 (`moreVertical`) trigger. Tapping opens a bottom action
/// reach on a phone (large targets, never clipped at the screen edge) than the
/// cramped `PopupMenu` it replaces. Sized to match [SidebarMutedIconButton] so the
/// row height is unchanged.
class SidebarOverflowMenuButton<T> extends StatelessWidget {
  const SidebarOverflowMenuButton({
    super.key,
    required this.actions,
    required this.onSelected,
    required this.size,
    required this.box,
    this.title,
    this.opacity = 0.6,
  });

  final List<SidebarSheetAction<T>> actions;
  final ValueChanged<T> onSelected;
  final double size;
  final double box;
  final String? title;
  final double opacity;

  Future<void> _open(BuildContext context) async {
    final selected = await _showActionSheet<T>(
      context,
      title: title,
      actions: actions,
    );
    if (selected != null && context.mounted) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: InkResponse(
        onTap: () => _open(context),
        radius: box * 0.6,
        child: SizedBox(
          width: box,
          height: box,
          child: Icon(
            LucideIcons.moreVertical,
            size: size,
            color: kSidebarMutedIcon,
          ),
        ),
      ),
    );
  }
}

/// A bottom action sheet listing [actions], optionally headed by [title]. Pops
/// with the chosen action's value, or `null` when dismissed. Replaces the
/// per-row anchored dropdown menus throughout the sidebar.
Future<T?> _showActionSheet<T>(
  BuildContext context, {
  required List<SidebarSheetAction<T>> actions,
  String? title,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null && title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            for (final action in actions)
              ListTile(
                leading: Icon(
                  action.icon,
                  size: 20,
                  color: action.danger ? kSidebarDanger : null,
                ),
                title: Text(
                  action.label,
                  style: TextStyle(
                    fontSize: 15,
                    color: action.danger ? kSidebarDanger : null,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(action.value),
              ),
          ],
        ),
      );
    },
  );
}
