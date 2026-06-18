import 'dart:async';

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
/// open time, so an already-on mode shows its lit accent + tinted row. The
/// 清空内容 row runs its own two-step confirm in place (`ToolsMenu`'s
/// `clearConfirmMode`): the first tap arms a red 确认清空 / AlertTriangle and the
/// sheet stays open, a second tap within 3 seconds pops [InputBoxAction.clearTopic]
/// (the confirmed clear) — independent of the standalone button's latch.
class InputBoxMenuSheet extends StatefulWidget {
  const InputBoxMenuSheet({
    super.key,
    required this.menu,
    required this.actions,
  });

  final InputBoxMenu menu;
  final InputBoxActions actions;

  @override
  State<InputBoxMenuSheet> createState() => _InputBoxMenuSheetState();
}

class _InputBoxMenuSheetState extends State<InputBoxMenuSheet> {
  bool _clearConfirm = false;
  Timer? _clearTimer;

  @override
  void dispose() {
    _clearTimer?.cancel();
    super.dispose();
  }

  /// The 清空内容 row's two-step confirm: arm on the first tap (and auto-disarm
  /// after 3s), pop the confirmed clear on the second.
  void _onClearTap() {
    if (_clearConfirm) {
      _clearTimer?.cancel();
      Navigator.of(context).pop(InputBoxAction.clearTopic);
      return;
    }
    setState(() => _clearConfirm = true);
    _clearTimer?.cancel();
    _clearTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _clearConfirm = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = inputBoxMenuActions(widget.menu);

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
                inputBoxMenuTitle(widget.menu),
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
                    if (widget.menu == InputBoxMenu.upload &&
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
    // 清空内容's confirm latch is sheet-local; every other row's active state is
    // the host's (a lit session mode).
    final isClear = action == InputBoxAction.clearTopic;
    final confirm = isClear && _clearConfirm;
    final active = isClear ? _clearConfirm : widget.actions.isActive(action);

    final label = confirm ? '确认清空' : info.label;
    final base = confirm
        ? kInputBoxClearConfirmColor
        : (info.color ?? theme.colorScheme.onSurface);
    final iconColor = info.dimWhenInactive && !active
        ? base.withValues(alpha: 0.6)
        : base;

    return ListTile(
      leading: inputBoxMenuIcon(
        action,
        color: iconColor,
        size: 20,
        active: confirm,
      ),
      title: Text(label),
      subtitle: info.subtitle == null ? null : Text(info.subtitle!),
      tileColor: active ? base.withValues(alpha: 0.12) : null,
      onTap: isClear ? _onClearTap : () => Navigator.of(context).pop(action),
    );
  }
}
