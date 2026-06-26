import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// A single selectable option for [AppSelectField] / [showAppSelectSheet].
class AppSelectOption<T> {
  const AppSelectOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.enabled = true,
  });

  final T value;
  final String label;

  /// Optional secondary line shown under [label] inside the sheet.
  final String? subtitle;

  /// Optional leading icon shown in the sheet row.
  final IconData? icon;

  final bool enabled;
}

/// A labelled, outlined select field that — instead of the native Material
/// dropdown popup — opens a compact, fixed-height scrollable bottom sheet
/// (mirroring the mini-map sheet style).
///
/// Generic over [T] so it works for `String`, nullable `String?`, enums and any
/// other value type used across the app's settings screens.
class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.label,
    this.sheetTitle,
    this.hint,
    this.placeholder,
    this.enabled = true,
    this.leading,
    this.borderRadius = 16,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 12,
    ),
    this.textStyle,
    this.dense = false,
  });

  /// Currently selected value. May not match any option (then [placeholder] or
  /// the raw value is shown).
  final T value;

  final List<AppSelectOption<T>> options;
  final ValueChanged<T> onChanged;

  /// Label rendered above the field. When null, no label row is shown.
  final String? label;

  /// Title shown at the top of the bottom sheet. Defaults to [label].
  final String? sheetTitle;

  /// Helper text rendered below the field.
  final String? hint;

  /// Text shown in the closed field when no option matches [value].
  final String? placeholder;

  final bool enabled;

  /// Optional leading widget shown inside the closed field.
  final Widget? leading;

  final double borderRadius;
  final EdgeInsetsGeometry contentPadding;
  final TextStyle? textStyle;

  /// Slightly tighter typography for embedded/inline contexts.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selectedOption();
    final displayText = selected?.label ?? placeholder ?? '';
    final hasValue = selected != null;

    final effectiveTextStyle =
        textStyle ??
        (dense
            ? theme.textTheme.bodyMedium?.copyWith(fontSize: 13)
            : theme.textTheme.bodyMedium);

    final field = InkWell(
      borderRadius: BorderRadius.circular(borderRadius),
      onTap: enabled ? () => _open(context) : null,
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          isDense: true,
          enabled: enabled,
          contentPadding: contentPadding,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Expanded(
              child: Text(
                displayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: effectiveTextStyle?.copyWith(
                  color: hasValue
                      ? (enabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ))
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronDown,
              size: dense ? 16 : 18,
              color: enabled
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );

    if (label == null && hint == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
        ],
        field,
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  AppSelectOption<T>? _selectedOption() {
    for (final o in options) {
      if (o.value == value) return o;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final result = await showAppSelectSheet<T>(
      context,
      title: sheetTitle ?? label,
      options: options,
      selected: value,
    );
    if (result != null && result.value != value) {
      onChanged(result.value);
    }
  }
}

/// Wraps the picked option so callers can distinguish "no choice" (null) from a
/// nullable selected value (e.g. `T == String?` with value `null`).
class AppSelectResult<T> {
  const AppSelectResult(this.value);
  final T value;
}

/// Shows a compact, fixed-height scrollable bottom sheet of [options] and
/// returns the chosen one (or null if dismissed). Styled after the mini-map
/// sheet: rounded top, drag handle, title row, internal scroll.
Future<AppSelectResult<T>?> showAppSelectSheet<T>(
  BuildContext context, {
  String? title,
  required List<AppSelectOption<T>> options,
  required T selected,
}) {
  return showModalBottomSheet<AppSelectResult<T>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) =>
        _AppSelectSheet<T>(title: title, options: options, selected: selected),
  );
}

class _AppSelectSheet<T> extends StatelessWidget {
  const _AppSelectSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String? title;
  final List<AppSelectOption<T>> options;
  final T selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = screenHeight * 0.6;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle (decorative).
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (title != null && title!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    title!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ] else
                const SizedBox(height: 8),
              Flexible(
                child: Scrollbar(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final o = options[index];
                      final isSelected = o.value == selected;
                      return ListTile(
                        dense: true,
                        enabled: o.enabled,
                        leading: o.icon != null
                            ? Icon(
                                o.icon,
                                size: 20,
                                color: isSelected
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              )
                            : null,
                        title: Text(
                          o.label,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 15,
                            color: isSelected ? cs.primary : cs.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        subtitle: o.subtitle != null
                            ? Text(
                                o.subtitle!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              )
                            : null,
                        trailing: isSelected
                            ? Icon(
                                LucideIcons.check,
                                size: 18,
                                color: cs.primary,
                              )
                            : null,
                        onTap: o.enabled
                            ? () => Navigator.of(
                                context,
                              ).pop(AppSelectResult<T>(o.value))
                            : null,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
