// Shared group overflow menu (重命名/删除), reused by the assistant and topic tabs.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/dialogs/sidebar_dialogs.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/widgets/sidebar_menus.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';

enum _GroupMenu { rename, delete }

/// The 重命名/删除 overflow menu for a group row.
class SidebarGroupMenuButton extends ConsumerWidget {
  const SidebarGroupMenuButton({super.key, required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(groupsProvider.notifier);
    return SidebarOverflowMenuButton<_GroupMenu>(
      size: 16,
      box: 26,
      title: group.name,
      actions: const [
        SidebarSheetAction(_GroupMenu.rename, LucideIcons.edit3, '重命名分组'),
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
    );
  }
}
