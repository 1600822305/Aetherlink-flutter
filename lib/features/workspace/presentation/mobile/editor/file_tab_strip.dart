// IDE-style horizontal tab strip for the middle page. Shows one tab per open
// file, the active one highlighted, each with a dirty dot and a close button.
// Overflows by scrolling horizontally. Pure presentation — the parent owns the
// open-tabs state and the close-with-unsaved-guard behaviour.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

class FileTabStrip extends StatelessWidget {
  const FileTabStrip({
    super.key,
    required this.tabs,
    required this.activePath,
    required this.dirtyPaths,
    required this.onSelect,
    required this.onClose,
  });

  final List<WorkspaceEntry> tabs;
  final String? activePath;
  final Set<String> dirtyPaths;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: tabs.length,
        itemBuilder: (context, i) {
          final entry = tabs[i];
          return _Tab(
            name: entry.name,
            active: entry.path == activePath,
            dirty: dirtyPaths.contains(entry.path),
            onTap: () => onSelect(entry.path),
            onClose: () => onClose(entry.path),
            theme: theme,
          );
        },
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.name,
    required this.active,
    required this.dirty,
    required this.onTap,
    required this.onClose,
    required this.theme,
  });

  final String name;
  final bool active;
  final bool dirty;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final fg = active ? scheme.onSurface : scheme.onSurfaceVariant;
    final radius = BorderRadius.circular(8);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      child: Material(
        color: active
            ? scheme.surfaceContainerHighest
            : scheme.surfaceContainerLow,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 180),
            padding: const EdgeInsets.only(left: 10, right: 4),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: active ? scheme.primary : scheme.outlineVariant,
                width: active ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active)
                  Container(
                    width: 3,
                    height: 16,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: fg,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _CloseAffordance(dirty: dirty, color: fg, onClose: onClose),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a dirty dot that turns into a close (×) button on tap/hover. Tapping
/// it always closes the tab; the dot just signals unsaved edits at rest.
class _CloseAffordance extends StatelessWidget {
  const _CloseAffordance({
    required this.dirty,
    required this.color,
    required this.onClose,
  });

  final bool dirty;
  final Color color;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onClose,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 24,
        height: 24,
        child: dirty
            ? Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            : Icon(LucideIcons.x, size: 14, color: color),
      ),
    );
  }
}
