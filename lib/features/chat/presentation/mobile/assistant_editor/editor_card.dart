import 'package:flutter/material.dart';

/// Rounded tinted card shared by the editor tabs (记忆 / 技能).
class EditorCard extends StatelessWidget {
  const EditorCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: child,
    );
  }
}
