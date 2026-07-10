// The floating font-size pill (− / size / +) shared by the workspace editor
// and the code block fullscreen viewer. Tapping the number resets to the
// default size.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

const double kEditorMinFontSize = 8;
const double kEditorMaxFontSize = 32;
const double kEditorDefaultFontSize = 13;

class EditorZoomPill extends StatelessWidget {
  const EditorZoomPill({super.key, required this.fontSize, required this.onChange});

  final double fontSize;
  final ValueChanged<double> onChange;

  void _bump(double delta) => onChange(
    (fontSize + delta).clamp(kEditorMinFontSize, kEditorMaxFontSize),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
      elevation: 2,
      shape: StadiumBorder(side: BorderSide(color: theme.dividerColor)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillButton(
            icon: LucideIcons.minus,
            onTap: fontSize > kEditorMinFontSize ? () => _bump(-1) : null,
          ),
          InkWell(
            onTap: () => onChange(kEditorDefaultFontSize),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Text(
                '${fontSize.round()}',
                style: theme.textTheme.labelMedium,
              ),
            ),
          ),
          _PillButton(
            icon: LucideIcons.plus,
            onTap: fontSize < kEditorMaxFontSize ? () => _bump(1) : null,
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null
              ? theme.disabledColor
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
