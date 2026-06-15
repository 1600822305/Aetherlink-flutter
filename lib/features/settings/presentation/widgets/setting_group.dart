import 'package:flutter/material.dart';

/// Corner radius of a settings group card, lifted from the original
/// `Group` style (`borderRadius: 12`). A layout constant, not a color — colors
/// stay theme tokens (ADR-0008/0009).
const double kSettingGroupRadius = 12;

/// A titled group of settings rows, rendered as a bordered card (the original
/// `SettingGroup` = `GroupTitle` + `Group` Paper).
///
/// Colors are theme tokens only: the card fills with `surface`, its border and
/// the muted title use the divider / `onSurfaceVariant` roles — no hard-coded
/// hex (ADR-0008).
class SettingGroup extends StatelessWidget {
  const SettingGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // GroupTitle: small, bold, muted, slightly indented and letter-spaced.
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(kSettingGroupRadius),
            border: Border.all(color: theme.dividerColor),
          ),
          // Clip + transparent Material so row ink ripples stay inside the card.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kSettingGroupRadius),
            child: Material(
              type: MaterialType.transparency,
              child: Column(children: children),
            ),
          ),
        ),
      ],
    );
  }
}
