import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/shared/domain/input_box_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/input_box_actions.dart';
import 'package:aetherlink_flutter/shared/widgets/input_box_button_catalog.dart';

/// The data-driven content for one aggregator menu (扩展 / 添加内容), rendered as a
/// bottom sheet — the parity port of the original anchored `ToolsMenu` /
/// `UploadMenu` popovers, which this codebase already renders as bottom sheets
/// on mobile (cf. the message 翻译/导出 sheets).
///
/// Both menus reuse this one widget: the item list comes from
/// [inputBoxMenuActions] (the menu-membership SSOT) and each row's glyph / color
/// / label / secondary text from [inputBoxMenuItemInfo], so adding or moving an
/// item is a single registry edit instead of the original's three hand-kept
/// copies. Tapping a row pops the sheet with the chosen [InputBoxAction]; the
/// host then dispatches it through its [InputBoxActions] (toggling a session
/// mode or surfacing 即将支持), exactly as a standalone toolbar tap would.
///
/// The active session modes (网络搜索 / 图像生成 / 视频生成) are read from [actions] at
/// open time, so an already-on mode shows its lit accent + tinted row.
class InputBoxMenuSheet extends StatelessWidget {
  const InputBoxMenuSheet({
    super.key,
    required this.menu,
    required this.actions,
  });

  final InputBoxMenu menu;
  final InputBoxActions actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = inputBoxMenuActions(menu);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                inputBoxMenuTitle(menu),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final action in items) ...[
                    // The 添加内容 menu sets off its optional feature section from
                    // the three core upload items with a divider (`UploadMenu`).
                    if (menu == InputBoxMenu.upload &&
                        action == InputBoxAction.note)
                      const Divider(height: 8),
                    _item(context, theme, action),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, ThemeData theme, InputBoxAction action) {
    final info = inputBoxMenuItemInfo(action);
    final base = info.color ?? theme.colorScheme.onSurface;
    final active = actions.isActive(action);
    final iconColor = info.dimWhenInactive && !active
        ? base.withValues(alpha: 0.6)
        : base;
    return ListTile(
      leading: inputBoxMenuIcon(action, color: iconColor, size: 20),
      title: Text(info.label),
      subtitle: info.subtitle == null ? null : Text(info.subtitle!),
      tileColor: active ? base.withValues(alpha: 0.12) : null,
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}
