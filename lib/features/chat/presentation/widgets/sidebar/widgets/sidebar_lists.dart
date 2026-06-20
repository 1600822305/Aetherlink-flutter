// Shared sidebar list scaffolding: headers, search field, frame, hints, footer.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Section header: `subtitle1` title (18.29px / 500) plus a right-aligned
/// cluster of action buttons.
class SidebarTabHeader extends StatelessWidget {
  const SidebarTabHeader({
    super.key,
    required this.title,
    required this.trailing,
  });

  final String title;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18.29,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

/// The per-tab search box, shown when the 搜索 toggle is on. Mirrors the
/// original `TextField size="small"` (40px tall, 8px radius, `搜索…` hint).
class SidebarSearchField extends StatelessWidget {
  const SidebarSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, height: 1.43),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          prefixIcon: const Icon(LucideIcons.search, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
        ),
      ),
    );
  }
}

/// A centered, ~52px tall empty hint (matches the original's empty-list slot).
class SidebarEmptyHint extends StatelessWidget {
  const SidebarEmptyHint({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 14, height: 1.43, color: color),
        ),
      ),
    );
  }
}

/// A "未分组助手 / 未分组话题" section label.
class SidebarSectionLabel extends StatelessWidget {
  const SidebarSectionLabel({
    super.key,
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, height: 1.43, color: color),
      ),
    );
  }
}

/// `scrollbar-width: none`.
class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

/// `VirtualizedList` / group `Accordion` container (border `divider`, radius 8,
/// `background.paper` background). When [scrollable] is true the box fills the
/// height handed to it by its parent (an `Expanded`) and scrolls internally with
/// + `overflow: auto`. Filling the parent keeps the ungrouped box a consistent
/// height across the assistant and topic tabs regardless of item count.
class SidebarListFrame extends StatelessWidget {
  const SidebarListFrame({
    super.key,
    required this.children,
    this.scrollable = false,
  });

  final List<Widget> children;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    if (scrollable) {
      content = ScrollConfiguration(
        behavior: const _NoScrollbarBehavior(),
        child: SingleChildScrollView(child: content),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      // Port of the web `background.paper` + `border: divider`: both follow the
      // theme so the box blends into the sidebar (light & dark) instead of
      // showing a hard-coded white block in dark mode.
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: content,
    );
  }
}

/// The centered "共 N 个…" footer.
class SidebarCountFooter extends StatelessWidget {
  const SidebarCountFooter({
    super.key,
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 12, height: 1.66, color: color),
        ),
      ),
    );
  }
}
