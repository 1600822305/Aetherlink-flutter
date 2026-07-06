import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/domain/selection_menu_settings.dart';

/// Display metadata for one 复制面板 action. The persisted configuration only
/// stores ids ([SelectionMenuSettings.enabledItemIds]); this registry maps them
/// to icon + label, and the execution logic lives with the selection area.
class SelectionMenuItemSpec {
  const SelectionMenuItemSpec({
    required this.id,
    required this.icon,
    required this.label,
  });

  final String id;
  final IconData icon;
  final String label;
}

/// Every supported 复制面板 action, in canonical order.
const List<SelectionMenuItemSpec> kSelectionMenuItemSpecs = [
  SelectionMenuItemSpec(id: kSelectionMenuCopy, icon: LucideIcons.copy, label: '复制'),
  SelectionMenuItemSpec(
    id: kSelectionMenuSelectAll,
    icon: LucideIcons.textSelect,
    label: '全选',
  ),
  SelectionMenuItemSpec(id: kSelectionMenuQuote, icon: LucideIcons.quote, label: '引用'),
  SelectionMenuItemSpec(id: kSelectionMenuShare, icon: LucideIcons.share2, label: '分享'),
];

/// Looks up an action's display spec, or null for an unknown persisted id
/// (e.g. one removed in a later version).
SelectionMenuItemSpec? selectionMenuSpec(String id) {
  for (final spec in kSelectionMenuItemSpecs) {
    if (spec.id == id) return spec;
  }
  return null;
}

/// The rounded card chrome of the custom 复制面板 — shared between the live
/// context menu (wrapping [TextSelectionToolbar]'s children) and the settings
/// page preview.
class SelectionMenuCard extends StatelessWidget {
  const SelectionMenuCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// One icon+label button inside the 复制面板.
class SelectionMenuButton extends StatelessWidget {
  const SelectionMenuButton({required this.spec, this.onPressed, super.key});

  final SelectionMenuItemSpec spec;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon, size: 18, color: theme.colorScheme.onSurface),
            const SizedBox(height: 3),
            Text(
              spec.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The assembled 复制面板 (card + button row) for contexts that don't need
/// [TextSelectionToolbar]'s anchoring — the settings page live preview.
class SelectionMenuPanel extends StatelessWidget {
  const SelectionMenuPanel({required this.itemIds, this.onAction, super.key});

  /// Enabled action ids, in display order. Unknown ids are skipped.
  final List<String> itemIds;

  final void Function(String id)? onAction;

  @override
  Widget build(BuildContext context) {
    final specs = [
      for (final id in itemIds)
        if (selectionMenuSpec(id) case final SelectionMenuItemSpec spec) spec,
    ];
    return SelectionMenuCard(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final spec in specs)
            SelectionMenuButton(
              spec: spec,
              onPressed: onAction == null ? null : () => onAction!(spec.id),
            ),
        ],
      ),
    );
  }
}
